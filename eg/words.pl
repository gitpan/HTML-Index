#!/usr/bin/perl -w

use strict;

use lib 'lib';

use HTML::Index::Store;
use Getopt::Long;

use vars qw( $opt_dbdir );

die "Usage: $0 [ -dbdir <db_file_dir> ]" unless GetOptions( qw( dbdir=s ) );
my $store = HTML::Index::Store->new( DB_DIR => $opt_dbdir );
$store->print_words();
