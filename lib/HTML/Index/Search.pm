package HTML::Index::Search;

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

use HTML::Index::Store;
use HTML::Index::Stopwords;

#------------------------------------------------------------------------------
#
# Private package globals
#
#------------------------------------------------------------------------------

my %OPTIONS = (
    STOP_WORD_FILE      => undef,
    VERBOSE             => undef,
    DB_DIR              => undef,
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
        REFRESH                 => $args{REFRESH},
        DB_DIR                  => $args{DB_DIR},
        MODE                    => 'r',
    );
    $self->{sw} = HTML::Index::Stopwords->new( $args{STOP_WORD_FILE} );
    $self->{words} = [];
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

my %bitwise = (
    AND => '&',
    OR  => '|',
    NOT => '~',
    '('   => '(',
    ')'   => ')',
);

my $bitwise_regex = '(' . join( '|', keys %bitwise ) . ')';

sub search
{
    my $self = shift;
    my $q = shift;

    return () unless defined $q and length $q;
    print LOG "Search for $q\n";
    my @results = ();
    $#results = $self->{store}->nfiles / 8;
    my $last_symbol = 'none';
    for my $w ( split /\b/, $q )
    {
        next unless $w =~ /\S/;
        $w =~ s/\s//g;
        print LOG "w = $w, last_symbol = $last_symbol, results[0] = $results[0]\n";
        if ( $bitwise{uc($w)} )
        {
            for my $results ( @results )
            {
                $results .= $bitwise{uc($w)};
            }
            $last_symbol = 'logic';
            next;
        }
        if ( $last_symbol eq 'word' )
        {
            for my $results ( @results )
            {
                $results .= '|';
            }
        }
        $last_symbol = 'word';
        push( @{$self->{words}}, $w );
        unless ( $self->{sw}->filter( $w ) )
        {
            print LOG "$w is a stopword\n";
            for my $results ( @results )
            {
                $results .= ' 0 ';
            }
            next;
        }
        print LOG "Search for $w\n";
        my $file_ids = $self->{store}->word2fileid( $w );
        my @c = $file_ids ? unpack( "C*", $file_ids ) : ();
        for ( my $i = 0; $i < @results;$i++ )
        {
            $results[$i] .= $c[$i] ? " $c[$i] " : " 0 ";
        }
    };
    my @files;
    for ( my $block = 0; $block < @results; $block++ )
    {
        next unless $results[$block];
        my $result = eval $results[$block];
        print LOG "block $block: $results[$block] = $result\n";
        next unless $result;
        for my $i ( 0 .. 7 )
        {
            my $mask = 1 << $i;
            if ( $result & $mask )
            {
                my $file_id = ( 8 * $block ) + $i;
                my $file = $self->{store}->fileid2file( $file_id );
                push @files, $file;
            }
        }
    }
    return @files;
}

sub get_words
{
    my $self = shift;
    return @{$self->{words}};
}

#------------------------------------------------------------------------------
#
# True
#
#------------------------------------------------------------------------------

1;

__END__

=head1 NAME

HTML::Index - Perl extension for indexing HTML files

=head1 SYNOPSIS

  use HTML::Index;
  
  $indexer = HTML::Indexer->new( %options );

  $indexer->create_index;

  @results = $indexer->search( 
    words => [ 'search', keywords' ],
  );

  for my $result ( @results )
  {
    print "words found: ", $result->words, "\n";
    print "path found on: ", $result->path, "\n";
  }

=head1 DESCRIPTION

HTML::Index is a simple module for indexing HTML files so that they can be
subsequently searched by keywords. It is looselly based on the indexer.pl
script in the O'Reilly "CGI Programming with Perl, 2nd Edition" book
(http://www.oreilly.com/catalog/cgi2/author.html).

Indexing is based on a list of directories passed to the constructor as one of
its options (HTML_DIRS). All files in these directories whose extensions match
the EXTENSIONS_REGEX are parsed using HTML::TreeBuilder and the word in those
pages added to the index. Words are stored lowercase, anything at least 2
characters long, and consist of alphanumerics ([a-z\d]{2,}).

Indexing is also possible in "remote" mode; here a list of URLs is provided,
and indexed files are grabbed via HTTP from these URLs, and all pages linked
from them. Only pages on the same site are indexed.

Indexes are stored in various database files. The default is to use Berkeley
DB, but the filesystem can be use if Berkeley DB is not installed using
Tie::TextDir.

The modification times of files in the index are stored, and they are
"re-inexed" if their modification time changes. Searches return results in no
particular order - it is up to the caller to re-order them appropriately!
Indexes can be run incrementally - only new or updated files will be indexed or
re-indexed.

=head1 OPTIONS

=over 4

=item VERBOSE

Print various bumpf to STDERR.

=item STOP_WORD_FILE

Specify a file containing "stop words" to ignore when indexling. A sample
stopwords.txt file is included in this distribution. MAke sure you use the same
STOP_WORD_FILE for indexing and searching. Otherwise, if you submit a search
for a word that was in the stop word list when indexing (especially in a
combination search) you may not get the result you expect!

=item REFRESH

Boolean to regenerate the index from scratch.

=item DB_DIR

Specify a directory to store the Berkeley DB files. Defaults to '.'.

=back

=head1 METHODS

=over 4

=item create_index

Does exactly what it says on the can.

=item search

Search the index, returning an array of L<HTML::Index::SearchResults> objects.
Takes two arguments:

=back

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
