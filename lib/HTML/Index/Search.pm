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

use Class::Struct;
use Text::Soundex;
use HTML::Index;
use HTML::Index::Filter;
use HTML::Index::Store;
use HTML::Index::Compress;
use HTML::Index::Stopwords;

#------------------------------------------------------------------------------
#
# Private package globals
#
#------------------------------------------------------------------------------

my @OPTIONS = qw(
    VERBOSE
    STORE 
);

my %BITWISE = (
    and => '&',
    or  => '|',
    not => '~',
);

my $BITWISE_REGEX = '(' . join( '|', keys %BITWISE ) . ')';

use vars qw( @ISA );

struct 'HTML::Index::Search::Struct' => { map { $_ => '$' } @OPTIONS };
@ISA = qw( HTML::Index::Search::Struct );

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
    $self->STORE->init( TABLES => \%HTML::Index::TABLES );
    $self->{compress} = HTML::Index::Compress->new( 
        COMPRESS => $self->STORE->COMPRESS 
    ) or die "Failed to create HTML::Index::Compress object\n";
    $self->{filter} = HTML::Index::Filter->new()
        or die "Failed to create HTML::Index::Filter object\n"
    ;
    $self->{stopwords} = HTML::Index::Stopwords->new( 
        STOP_WORD_FILE => $self->STORE->STOP_WORD_FILE 
    ) or die "Failed to create HTML::Index::Stopwords object\n";
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
}

#------------------------------------------------------------------------------
#
# Private methods
#
#------------------------------------------------------------------------------

sub _get_file_ids
{
    my $self = shift;
    my $word = shift;

    my $file_ids = $self->STORE->get( 'word2fileid', $word );
    $file_ids = $self->{compress}->inflate( $file_ids );
    return $file_ids;
}

sub _get_soundex_results
{
    my $self = shift;
    my $w = shift;
    # try soundex ...
    my $soundex = soundex( $$w );
    my $soundex2wordid = $self->STORE->get( 'soundex2wordid', $soundex );
    return () unless $soundex2wordid;
    my @wordid = split( ',', $soundex2wordid );
    for my $wordid ( @wordid )
    {
        $$w = $self->STORE->get( 'wordid2word', $wordid );
        my $file_ids = $self->_get_file_ids( $$w );
        return $file_ids if $file_ids;
    }
    return undef;
}

sub _get_bitstring
{
    my $self = shift;
    my $w = shift;
    my $use_soundex = shift;

    $w = $self->{filter}->filter( $w );
    if ( not $w )
    {
        print LOG "$w filtered\n";
        return "\0";
    }
    if ( $self->{stopwords}->is_stopword( $w ) )
    {
        print LOG "$w stopworded\n";
        return "\0";
    }
    my $file_ids = $self->_get_file_ids( $w );
    if ( not defined $file_ids and $use_soundex )
    {
        $file_ids = $self->_get_soundex_results( \$w );
    }
    return "\0" unless $file_ids;
    push( @{$self->{words}}, $w );
    $file_ids =~ s/\\/\\\\/g;
    $file_ids =~ s/'/\\'/g;
    return $file_ids;
}

sub _create_bitstring
{
    my $self = shift;
    my $q = lc( shift );
    my $use_soundex = shift;

    $q =~ s/-/ /g;              # split hyphenated words
    $q =~ s/[^\w\s()]//g;       # get rid of all non-(words|spaces|brackets)
    $q =~ s/\b$BITWISE_REGEX\b/$BITWISE{$1}/gi;  
                                # convert logical words to bitwise operators
    1 while $q =~ s/\b(\w+)\s+(\w+)\b/$1 & $2/g;
                                # assume any consecutive words are AND'ed
    $q =~ s/\b(\w+)\b/"'" . $self->_get_bitstring( $1, $use_soundex ) . "'"/ge;
                                # convert words to bitwise string
    my $result = eval $q;       # eval bitwise strings / operators
    if ( $@ )
    {
        print LOG "eval error: $@\n";
    }
    return $result;
}

sub _get_file
{
    my $self = shift;
    my $file_id = shift;

    return $self->STORE->get( 'fileid2file', $file_id );
}

#------------------------------------------------------------------------------
#
# Public methods
#
#------------------------------------------------------------------------------

sub search
{
    my $self = shift;
    my $q = shift;
    my %options = @_;

    return () unless defined $q and length $q;
    print LOG "Search for $q\n";
    my $bitstring = $self->_create_bitstring( $q, $options{SOUNDEX} );
    return () unless $bitstring;
    my @bits = split //, unpack( "B*", $bitstring );
    my @results =
        map { $self->_get_file( $_ ) }
        map { $bits[$_] == 1 ? $_ : () } 0 .. $#bits
    ;
    print LOG "Results: @results\n";
    return @results;
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

HTML::Index::Search - Perl module for searching a searchable HTML files index

=head1 SYNOPSIS

    use HTML::Index::Search;

    my $store = HTML::Index::Store->new();
    my $search = HTML::Index::Search->new( STORE => $store );
    my @results = $search->search( $q, [ SOUNDEX => 1 ] );
    my @words = $search->get_words( $q );

=head1 DESCRIPTION

This module is the complement to the L<HTML::Index::Create|HTML::Index::Create>
module. It allows the inverted index created by it to be searched, based on a
query string containing words and boolean logic. The search returns a set of
results consisting of the tokens corresponding to the name attributes of the
L<HTML::Index::Document|HTML::Index::Document> objects that were indexed by the
L<HTML::Index::Create|HTML::Index::Create> object. The words extracted from the
query string can be accessed after the search using the get_words method.

=head1 OPTIONS

=over 4

=item VERBOSE

Print various bumpf to STDERR.

=item STORE

Something which ISA L<HTML::Index::Store|HTML::Index::Store>.

=back

=head1 METHODS

=over 4

=item search

This method takes a query string as its first argument. This query string is a
whitespace separated list of words, optionally connected by Boolean terms (or,
and, not - case insensitive), and also optionally grouped using parentheses.
Any terms that are not connected by Booleans are assumed to be AND'ed. Here are
some examples:

    some stuff
    some AND stuff
    some and stuff
    some OR stuff
    some AND stuff AND NOT more
    ( more AND stuff ) OR ( sample AND stuff )

For those that are interested ... the inverted index is actually stored as a
bitvector, where the entry for each word is a scalar, the n'th bit of which is
set 1 or 0 depending on whether that word appears in the n'th file. This is not
the most compact stoage method, but it makes the processing of Boolean queries
very simple, using bitwise arithmetic. Also, since the bitvectors are generally
sparce, they compress well with standard compression (in this case
Compress::Gzip - see L<HTML::Index::Compress|HTML::Index::Compress>.

The second argument to search is an options hashref. Currently the only option
available is a SOUNDEX option (value true or false). If true, the search is
done via a soundex algorithm, so the result set contains all docments that
contain words that sound alike to the query string by this measure.

=item get_words

This method simply returns the list of words (not including Booleans) extracted
from the most recently searched query string. It is used by
L<HTML::Index::Search::CGI|HTML::Index::Search::CGI> to generate a summary with
the keywords highlighted.

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
