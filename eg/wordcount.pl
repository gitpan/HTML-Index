#!/usr/bin/perl -w

use strict;

use HTML::Index;
use TempDir;

my $tmp_dir = TempDir->new();
my $dbdir = "$tmp_dir/db";
my $indexer = HTML::Index->new( DB_DIR => $dbdir );
my %words;
while ( my( $wordid, $fileids ) = $indexer->each( 'wordid2fileid' ) )
{
    my $word = $indexer->value( 'wordid2word', $wordid );
    next unless defined $word;
    my @fileids = split( /,/, $fileids );
    my $file_count = scalar( @fileids ) / 2;
    print "$file_count $word\n";
}
