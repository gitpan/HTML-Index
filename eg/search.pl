#!/usr/bin/perl -w

use strict;

use lib 'lib';
use Time::HiRes qw(gettimeofday);
use HTML::Index::Search;
use Getopt::Long;

use vars qw( $opt_db $opt_verbose $opt_and @words );

GetOptions( qw( verbose and db=s ) ) and @words = @ARGV or
    die "Usage: $0 [-and] [-db <db dir>] <word1> [ <word2> ... ]\n"
;
my $indexer = HTML::Index::Search->new(
    VERBOSE => $opt_verbose,
    DB_DIR => $opt_db
);
my $logic = $opt_and ? 'AND' : 'OR';
my $t0 = gettimeofday;
my @results = $indexer->search( words => \@words, logic => $logic );
my $time = gettimeofday - $t0;
print 
    map( { "$_\n" } @results ),
    sprintf( 
        "%d results for %s returned in %0.3f secs\n",
        scalar( @results ), 
        join( " $logic ", @words ), 
        $time 
    )
;
