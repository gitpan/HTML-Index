# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

use HTML::Index::Create;
use HTML::Index::Search;
use HTML::Index::Document;

BEGIN { 
    do 't/tests.pl';
}

my $indexer = HTML::Index::Create->new( 
    REFRESH => 1,
) or die "Failed to create HTML::Index::Create object\n";
for ( @test_files )
{
    my $doc = HTML::Index::Document->new( path => $_ );
    $indexer->index_file( $doc );
}
undef $indexer;
my $searcher = HTML::Index::Search->new( 
) or die "Failed to create HTML::Index::Search object\n";
my $ntests = scalar( @tests );
my $ntest_files = scalar( @test_files );
print "1..", ( $ntests * ( $ntest_files + 1 ) ), "\n";
for my $test ( @tests )
{
    do_search_test( $searcher, $test );
}
for ( @test_files )
{
    utime( time, time, $_ );
    my $indexer = HTML::Index::Create->new( 
    ) or die "Failed to create HTML::Index::Create object\n";
    my $doc = HTML::Index::Document->new( path => $_ );
    $indexer->index_file( $doc );
    undef $indexer;
    my $searcher = HTML::Index::Search->new( 
    ) or die "Failed to create HTML::Index::Search object\n";
    for my $test ( @tests )
    {
        do_search_test( $searcher, $test );
    }
}

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):
