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
use HTML::Entities;
use HTML::Index;
use HTML::Index::Store;
use HTML::Index::Document;
use HTML::Index::Filter;
use HTML::Index::Compress;
use HTML::Index::Stopwords;
use Text::Soundex;
use Class::Struct;

#------------------------------------------------------------------------------
#
# Private package globals
#
#------------------------------------------------------------------------------

my @OPTIONS = qw(
    VERBOSE
    STORE
    PARSER
    REFRESH
);

my @NON_VISIBLE_HTML_TAGS = qw(
    style
    script
    head
);

my $NON_VISIBLE_HTML_TAGS = '(' . join( '|', @NON_VISIBLE_HTML_TAGS ) . ')';

use vars qw( @ISA );

struct 'HTML::Index::Create::Struct' => { map { $_ => '$' } @OPTIONS };
@ISA = qw( HTML::Index::Create::Struct );

#------------------------------------------------------------------------------
#
# Constructor
#
#------------------------------------------------------------------------------

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    return $self->_init();
}

#------------------------------------------------------------------------------
#
# Initialization private method
#
#------------------------------------------------------------------------------

sub _init
{
    my $self = shift;
    if ( $self->VERBOSE )
    {
        open( LOG, ">&STDERR" );
    }
    else
    {
        open( LOG, ">/dev/null" );
    }
    die "No STORE\n" unless defined $self->STORE;
    die $self->STORE , " is not an HTML::Index::Store\n" 
        unless $self->STORE->isa( 'HTML::Index::Store' )
    ;
    $self->STORE->init( 
        TABLES => \%HTML::Index::TABLES, 
        REFRESH => $self->REFRESH 
    );
    $self->PARSER( 'html' ) unless $self->PARSER;
    $self->{compress} = HTML::Index::Compress->new( 
        COMPRESS => $self->STORE->COMPRESS 
    ) or die "Failed to create HTML::Index::Compress object\n";
    $self->{filter} = HTML::Index::Filter->new()
        or die "Failed to create HTML::Index::Filter object\n"
    ;
    $self->{stopwords} = HTML::Index::Stopwords->new( 
        STOP_WORD_FILE => $self->STORE->STOP_WORD_FILE 
    ) or die "Failed to create HTML::Index::Stopwords object\n";
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
}

#------------------------------------------------------------------------------
#
# Public methods
#
#------------------------------------------------------------------------------

sub index_document
{
    my $self = shift;
    my $document = shift;

    die "$document isn't an HTML::Index::Document object\n"
        unless ref( $document ) eq 'HTML::Index::Document'
    ;
    my $file_id = $self->_get_file_id( $document );
    return unless defined $file_id;
    print LOG "indexing ", $document->name, " ($file_id)\n";
    $self->_store_file_details( $file_id, $document );
    my $text = $self->_parse_file( $document->contents() );
    $self->_add_words( $file_id, $text );
}

#------------------------------------------------------------------------------
#
# Private methods
#
#------------------------------------------------------------------------------

sub _store_file_details
{
    my $self = shift;
    my $file_id = shift;
    my $document = shift;

    $self->STORE->put( 'file2fileid', $document->name, $file_id );
    $self->STORE->put( 'fileid2file', $file_id, $document->name );
    $self->STORE->put( 'fileid2modtime', $file_id, $document->modtime );
    my $fileid = $self->STORE->nkeys( 'fileid2file' );
}

sub _get_words
{
    my $self = shift;
    my $text = shift;

    my %seen = ();
    my @w = grep { ! $seen{$_}++ } grep /\w/, split( /\b/, $text );
    @w = $self->{filter}->filter( @w );
    @w = grep { ! $self->{stopwords}->is_stopword( $_ ) } @w;
    print LOG scalar( @w ), " words\n";
    return @w;
}

sub _get_new_word_id
{
    my $self = shift;

    my $wordid = $self->STORE->nkeys( 'wordid2word' ) || 0;
    return $wordid;
}

sub _get_mask
{
    my $self = shift;
    my $bit = shift;

    my $bits = ( "0" x ($bit) ) . "1";
    my $str = pack( "B*", $bits );
    return $str;
}

sub _remove_file_id
{
    my $self = shift;
    my $file_ids = shift;
    my $file_id = shift;

    my $mask = $self->_get_mask( $file_id );
    my $block = $file_ids;
    $file_ids = $block & ~ $mask;
    return $file_ids;
}

sub _add_file_id
{
    my $self = shift;
    my $file_ids = shift;
    my $file_id = shift;

    my $mask = $self->_get_mask( $file_id );
    my $block = $file_ids;
    $file_ids = $block ? ( $block | $mask ) : $mask;
    return $file_ids;
}

sub _get_file_ids
{
    my $self = shift;
    my $word = shift;

    my $file_ids =  $self->STORE->get( 'word2fileid', $word );
    $file_ids = $self->{compress}->inflate( $file_ids );
    return $file_ids;
}

sub _set_file_ids
{
    my $self = shift;
    my $word = shift;
    my $file_ids = shift;

    $file_ids = $self->{compress}->deflate( $file_ids );
    $self->STORE->put( 'word2fileid', $word, $file_ids );
    return $file_ids;
}

sub _dump_bitstring
{
    my $bitstring = shift;
    return join( '', unpack( "B*", $bitstring ) );
}

sub _add_words
{
    my $self = shift;
    my $file_id = shift;
    my $text = shift;

    for my $w ( $self->_get_words( $text ) )
    {
        my $file_ids = $self->_get_file_ids( $w );
        unless ( defined( $file_ids ) )
        {
            my $wordid = $self->_get_new_word_id();
            $self->STORE->put( 'wordid2word', $wordid, $w );
            my $soundex = soundex( $w );
            my $soundex2wordid = 
                $self->STORE->get( 'soundex2wordid', $soundex )
            ;
            $soundex2wordid = 
                $soundex2wordid ? "$soundex2wordid,$wordid" : $wordid
            ;
            $self->STORE->put( 'soundex2wordid', $soundex, $soundex2wordid );
        }
        $file_ids = $self->_add_file_id( $file_ids, $file_id );
        # warn "$w:", _dump_bitstring( $file_ids ), "\n";
        $self->_set_file_ids( $w, $file_ids );
    }
}

sub _parse_file
{
    my $self = shift;
    my $contents = shift;

    if ( lc( $self->PARSER ) eq 'html' )
    {
        my $tree = HTML::TreeBuilder->new();
        $tree->parse( $contents );
        my $text = join( ' ', _get_text_array( $tree ) );
        $tree->delete();
        return $text;
    }
    elsif ( lc( $self->PARSER eq 'regex' ) )
    {
        my $text = $contents;
        # get rid of non-visible (script / style / head) text
        $text =~ s{
            <$NON_VISIBLE_HTML_TAGS.*?> # a head, script, or style start tag
            .*?                         # non-greedy match of anything
            </\1>                       # matching end tag
        }
        {}gxis; 
        # get rid of tags
        $text =~ s/<.*?>//gs;
        $text = decode_entities( $text );
        $text =~ s/[\s\240]+/ /g;
        return $text;
    }
    else
    {
        die "Unrecognized value for PARSER - should be one of (html|regex)\n";
    }
}

sub _each_file_ids
{
    my $self = shift;

    my ( $word, $file_ids ) = $self->STORE->each( 'word2fileid' );
    return () unless defined $word and defined $file_ids;
    $file_ids = $self->{compress}->inflate( $file_ids );
    return ( $word, $file_ids );
}

sub _deindex
{
    my $self = shift;
    my $file_id = shift;

    print LOG "$file_id has changed - deindexing ...\n";

    while ( my ( $word, $file_ids ) = $self->_each_file_ids )
    {
        $file_ids = $self->_remove_file_id( $file_ids, $file_id );
        $self->STORE->cput( $word, $file_ids ) or
            die "Can't cput $file_ids in $word key of word2fileid\n"
        ;
    }
}

sub _get_new_file_id
{
    my $self = shift;

    my $fileid = $self->STORE->nkeys( 'fileid2file' ) || 0;
    return $fileid;
}

sub _get_file_id
{
    my $self = shift;
    my $document = shift;

    my $modtime = $document->modtime();
    my $name = $document->name();

    my $file_id = $self->STORE->get( 'file2fileid', $name );
    if( defined $file_id )
    {
        my $prev_modtime = $self->STORE->get( 'fileid2modtime', $file_id );
        if ( $prev_modtime == $modtime )
        {
            print LOG "$name hasn't changed .. skipping\n";
            return;
        }
        print LOG "deindex $name\n";
        $self->_deindex( $file_id );
    }
    else
    {
        $file_id = $self->_get_new_file_id();
    }
    return $file_id;
}

#------------------------------------------------------------------------------
#
# Private functions
#
#------------------------------------------------------------------------------

sub _get_text_array
{
    my $element = shift;
    my @text;

    for my $child ( $element->content_list )
    {
        if ( ref( $child ) )
        {
            next if $child->tag =~  /^$NON_VISIBLE_HTML_TAGS$/;
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

HTML::Index::Create - Perl module for creating a searchable HTML files index

=head1 SYNOPSIS

  use HTML::Index::Create;
  
    $store = HTML::Index::Store->new;
    $indexer = HTML::Indexer->new(
        VERBOSE             => 1,
        STORE               => $store,
        PARSER              => 'HTML',
    );

    for ( ... )
    {
        my $doc = HTML::Index::Document->new( 
            name        => $name,
            contents    => $contents,
            mod_time    => $mod_time,
        );
        $indexer->index_document( $doc );
    }

    for ( ... )
    {
        my $doc = HTML::Index::Document->new( path => $path );
        # name, contents, and mod_time are the path, contents and modification
        # time of $path
        $indexer->index_document( $doc );
    }

=head1 DESCRIPTION

All files in are parsed using either the HTML::TreeBuilder module, or a "quick
and dirty" regex - it's your choice. Words are stored lowercase, anything at
least 2 characters long, and consisting of alphanumerics ([a-z\d]{2,}).

Indexes are stored as Berkeley DB files, but all storage operations are
contained in the L<HTML::Index::Store|HTML::Index::Store> module, which could
be subclassed to support other storage options (such as SQL databases).

The inverted index (which stores the list of documents for each word)
can be compressed. This adds a small overhead to the indexing, but is probably
faster for search (since decompression is fast, and it is more likely that the
index can be processed in memory).

=head1 CONSTRUCTOR OPTIONS

=over 4

=item VERBOSE

Prints stuff to STDERR.

=item STORE

A an object which ISA HTML::Index::Store.

=item PARSER

Should be one of html or regex. If html, documents are parsed using
HTML::TreeBuilder to extract visible text. If regex, the
same job is done by a "quick and dirty" regex.

=item REFRESH

If true, the index will be refreshed (all existing data will be lost).

=back

=head1 METHODS

=over 4

=item index_document

Takes an L<HTML::Index::Document|HTML::Index::Document> as an argument. Indexes
the document, based either on its content attribute, or the content of its path
attribute. A search will return either its name attribute, or its path
attribute. If an entry for that name already exists, then it will be
re-indexed, iff the modification time of the document has changed. The mod_time
attribute can be set explicitly, else it defaults to the modification time of
the path attribute.

The idea of using the L<HTML::Index::Document|HTML::Index::Document>
abstraction in this way is to allow in the simple case to index file paths, but
also to index any other data source (such as entries in a database, for
example).

=back

=head1 SEE ALSO

=over 4

=item L<HTML::Index|HTML::Index>

=back

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
