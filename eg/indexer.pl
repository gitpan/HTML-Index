#!/usr/bin/perl -w

use strict;

use lib 'lib';
use HTML::Index::Create;
use Getopt::Long;
use File::Basename;

use vars qw( 
    $opt_refresh
    $opt_verbose
    $opt_stopfile
    $opt_dbdir 
    $opt_parser
);

$opt_parser = 'html';

my @files;

unless ( 
    GetOptions( 
        qw( 
            dbdir=s 
            refresh 
            verbose 
            stopfile=s 
            parser=s
        ) 
    )  and @files = @ARGV
)
{
        die <<EOF;
Usage: $0 
    [ -refresh ] 
    [ -verbose ] 
    [ -stopfile <stop_words_file> ]
    [ -dbdir <db_file_dir> ]
    [ -parser <html|regex> ]
    <files to index>
EOF
}

my $indexer = HTML::Index::Create->new(
    STOP_WORD_FILE      => $opt_stopfile,
    REFRESH             => $opt_refresh,
    VERBOSE             => $opt_verbose,
    DB_DIR              => $opt_dbdir,
    PARSER              => $opt_parser,
);

my $i = 0;
my $t0 = time;
for my $file ( @files )
{
    my $doc = HTML::Index::Document->new( path => $file );
    $indexer->index_file( $doc );
    $i++;
}

my $dt = time - $t0;
my $fps = $i / $dt;
print "$i files indexed in $dt seconds ($fps files per second)\n";
