#!/usr/bin/perl -w

use strict;

use HTML::Index;
use Getopt::Long;
use TempDir;

our ( $opt_sleep, $opt_refresh, $opt_verbose, $opt_logfile, $opt_stopfile, $opt_dbdir );

my $tmp_dir = TempDir->new();
$opt_dbdir = "$tmp_dir/db";

GetOptions( qw( dbdir=s sleep=i refresh verbose logfile=s stopfile=s ) ) 
    or die <<EOF;
Usage: $0 
    [ -refresh ] 
    [ -verbose ] 
    [ -logfile <logfile> ] 
    [ -sleep <secs> ]
    [ -stopfile <stop_words_file> ]
    [ -dbdir <db_file_dir> ]
    <html_dir> [ <html_dir> ... ]
EOF

my @l = localtime;
# my $datestr = sprintf( "%04d%02d%02d", $l[5]+1900, $l[4]+1, $l[3] );
my $datestr = sprintf( "%04d%02d", $l[5]+1900, $l[4]+1 );
my @DEFAULT_HTML_DIRS = (
    grep { -d } </www/sites/itn.co.uk/home/htdocs/news/$datestr*>,
    "/www/sites/itn.co.uk/home/htdocs/news/$datestr",
    # "/www/sites/itn.co.uk/home/htdocs/news",
    "/www/sites/itn.co.uk/home/htdocs/specials"
);

my @html_dirs = @ARGV ?  @ARGV : @DEFAULT_HTML_DIRS;

if ( $opt_logfile )
{
    print STDERR "Opening logfile $opt_logfile ...\n";
    open( STDERR, ">$opt_logfile" ) or die "Can't open logfile $opt_logfile\n";
}
my $indexer = HTML::Index->new(
    SLEEP               => $opt_sleep,
    STOP_WORD_FILE      => $opt_stopfile,
    REFRESH             => $opt_refresh,
    VERBOSE             => $opt_verbose || $opt_logfile,
    HTML_DIRS           => \@html_dirs,
    DB_DIR              => $opt_dbdir,
    EXTENSIONS_REGEX    => 'shtml',
);

$indexer->create_index();
