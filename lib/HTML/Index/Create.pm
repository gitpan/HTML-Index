package HTML::Index::Create;

#------------------------------------------------------------------------------
#
# Pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

#------------------------------------------------------------------------------
#
# Modules
#
#------------------------------------------------------------------------------

use HTML::TreeBuilder;
use HTML::Index::Document;
use HTML::Index::Store;
use HTML::Index::Stopwords;
use HTML::Entities;

#------------------------------------------------------------------------------
#
# Private package globals
#
#------------------------------------------------------------------------------

my %OPTIONS = (
    VERBOSE             => undef,
    STOP_WORD_FILE      => undef,
    DB_DIR              => undef,
    REFRESH             => 0,
    PARSER              => 'HTML',
);

#------------------------------------------------------------------------------
#
# Constructor
#
#------------------------------------------------------------------------------

sub new
{
    my $class = shift;
    my %args = ( %OPTIONS, @_ );
    for ( keys %args )
    {
        die "Unknown option $_\n" unless exists $OPTIONS{$_};
    }

    my $self = bless \%args, $class;

    if ( $self->{VERBOSE} )
    {
        open( LOG, ">&STDERR" );
    }
    else
    {
        open( LOG, ">/dev/null" );
    }
    $self->{store} = HTML::Index::Store->new(
        VERBOSE                 => $args{VERBOSE},
        DB_HASH_CACHESIZE       => $args{DB_HASH_CACHESIZE},
        REFRESH                 => $args{REFRESH},
        DB_DIR                  => $args{DB_DIR},
        MODE                    => 'rw',
    );

    $self->{sw} = HTML::Index::Stopwords->new( $args{STOP_WORD_FILE} );

    return $self;
}

#------------------------------------------------------------------------------
#
# Destructor
#
#------------------------------------------------------------------------------

sub DESTROY
{
    my $self = shift;

    print LOG "destroying $self\n";
    $self->{store}->untie() if $self->{store};
}

#------------------------------------------------------------------------------
#
# Public methods
#
#------------------------------------------------------------------------------

sub parse_file
{
    my $self = shift;
    my $contents = shift;

    if ( lc( $self->{PARSER} ) eq 'html' )
    {
        my $tree = HTML::TreeBuilder->new();
        $tree->parse( $contents );
        my $text = join( ' ', _get_text_array( $tree ) );
        $tree->delete();
        return $text;
    }
    elsif ( lc( $self->{PARSER} eq 'regex' ) )
    {
        my $text = $contents;
        $text =~ s!<(head|script|style).*?>.*?</\1>!!g; 
        # get rid of non-visible (script / style / head) text
        $text =~ s/<.*?>//g;
        $text = decode_entities( $text );
        $text =~ s/[\s\240]+/ /g;
        return $text;
    }
    else
    {
        die "Unrecognized value for PARSER - should be one of (html|regex)\n";
    }
}

sub remove_fileid
{
    my $self = shift;
    my $file_id = shift;
    my $word = shift;
}

sub get_file_id
{
    my $self = shift;
    my $document = shift;

    my $modtime = $document->modtime();
    my $name = $document->name();

    my $file_id = $self->{store}->file2fileid( $name );
    if( defined $file_id )
    {
        my $prev_modtime = $self->{store}->fileid2modtime( $file_id );
        if ( $prev_modtime == $modtime )
        {
            print LOG "$name hasn't changed .. skipping\n";
            return $file_id;
        }
        print LOG "deindex $name\n";
        $self->{store}->deindex( $file_id );
    }
    else
    {
        $file_id = $self->_get_new_file_id();
    }
    print LOG "indexing $name\n";
    return $file_id;
}

sub store_file_details
{
    my $self = shift;
    my $file_id = shift;
    my $document = shift;

    $self->{store}->file2fileid( $document->name, $file_id );
    $self->{store}->fileid2file( $file_id, $document->name );
    $self->{store}->fileid2modtime( $file_id, $document->modtime );
}

sub index_file
{
    my $self = shift;
    my $document = shift;

    die "$document isn't an HTML::Index::Document object\n"
        unless ref( $document ) eq 'HTML::Index::Document'
    ;
    my $file_id = $self->get_file_id( $document );
    $self->store_file_details( $file_id, $document );
    my $text = $self->parse_file( $document->contents() );
    my %words = map { $_ => 1 } $self->{sw}->filter( split( /\s+/, $text ) );
    my @words = keys %words;
    print LOG "$#words words\n";
    $self->{store}->add_words( $file_id, \@words );
}

#------------------------------------------------------------------------------
#
# Private functions
#
#------------------------------------------------------------------------------

sub _get_new_file_id
{
    my $self = shift;

    return $self->{store}->get_new( 'fileid2file' );
}

sub _get_text_array
{
    my $element = shift;
    my @text;

    for my $child ( $element->content_list )
    {
        if ( ref( $child ) )
        {
            next if $child->tag =~  /^(script|style)$/;
            push( @text, _get_text_array( $child ) );
        }
        else
        {
            push( @text, $child );
        }
    }

    return @text;
}

#------------------------------------------------------------------------------
#
# True
#
#------------------------------------------------------------------------------

1;

__END__

=head1 NAME

HTML::Index::Create - Perl extension for creating a searchable HTML files

=head1 SYNOPSIS

  use HTML::Index::Create;
  
  $indexer = HTML::Indexer->new( %options );

  $indexer->create_index;

=head1 DESCRIPTION

HTML::Index::Create is a simple module for creating a searchable index for HTML
files so that they can be subsequently searched by keywords. It is looselly
based on the indexer.pl script in the O'Reilly "CGI Programming with Perl, 2nd
Edition" book (http://www.oreilly.com/catalog/cgi2/author.html).

All files in are parsed using HTML::TreeBuilder and the word in those pages
added to the index. Words are stored lowercase, anything at least 2 characters
long, and consist of alphanumerics ([a-z\d]{2,}).

Indexes are stored to use Berkeley DB files.

The modification times of files in the index are stored, and they are
"re-inexed" if their modification time changes. Searches return results in no
particular order - it is up to the caller to re-order them appropriately!
Indexes can be run incrementally - only new or updated files will be indexed or
re-indexed.

=head1 CONSTRUCTOR OPTIONS

=over 4

=item VERBOSE

Print various bumpf to STDERR.

=item STOP_WORD_FILE

Specify a file containing "stop words" to ignore when indexling. A sample
stopwords.txt file is included in this distribution. MAke sure you use the same
STOP_WORD_FILE for indexing and searching. Otherwise, if you submit a search
for a word that was in the stop word list when indexing (especially in a
combination search) you may not get the result you expect!

=item DB_HASH_CACHESIZE

Set the cachesize for the DB_File hashes. Default is 0.

=item REFRESH

Boolean to regenerate the index from scratch.

=item DB_DIR

Specify a directory to store the Berkeley DB files. Defaults to '.'.

=back

=head1 METHODS

=over 4

=item create_index

Does exactly what it says on the can.

=back

=head1 SEE ALSO

L<HTML::Index::Document>, L<HTML::Index::Search>

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
