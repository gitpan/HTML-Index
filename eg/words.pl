#!/usr/bin/perl -w

use strict;

use HTML::Index::Store::BerkeleyDB;
use HTML::Index::Stats;
use Getopt::Long;

use vars qw( $opt_dbdir $opt_values );

die "Usage: $0 [ -dbdir <db_file_dir> ] [ -values ]" 
    unless GetOptions( qw( values dbdir=s ) );
print join "\n", HTML::Index::Stats->new( 
    STORE => HTML::Index::Store::BerkeleyDB->new( DB => $opt_dbdir )
)->words( $opt_values );
