#!/usr/bin/perl -w

use strict;

use Time::HiRes qw(gettimeofday);
use HTML::Index;
use Getopt::Long;
use TempDir;

our ( $opt_verbose, $opt_and );

my $tmp_dir = TempDir->new();
my $dbdir = "$tmp_dir/db";

my $indexer = HTML::Index->new( 
    VERBOSE => $opt_verbose,
    DB_DIR => $dbdir,
);

my @words = @ARGV;
GetOptions( qw( verbose and ) ) and @words or
    die "Usage: $0 [-and] <word1> [ <word2> ... ]\n"
;
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
