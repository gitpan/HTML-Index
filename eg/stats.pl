#!/usr/bin/perl -w

use strict;

use HTML::Index::Stats;
use HTML::Index::Store::BerkeleyDB;
use Getopt::Long;

use vars qw( $opt_db $opt_verbose );
die "Usage: $0 [-db <db dir> -verbose ]\n" unless GetOptions qw( db=s verbose );
my $store = HTML::Index::Store::BerkeleyDB->new( MODE => 'r', VERBOSE => $opt_verbose, DB => $opt_db );
print HTML::Index::Stats->new( VERBOSE => $opt_verbose, STORE => $store )->stats();
