# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

use File::Copy;
use HTML::Index::Create;
use HTML::Index::Search;
use HTML::Index::Document;
use HTML::Index::Store::BerkeleyDB;

BEGIN { 
    do 't/tests.pl';
}

@test_files = map { "eg/test$_.html" } ( 5 .. 6 );
@tests = (
    { q => 'simple', paths => [ 'eg/test5.html', 'eg/test6.html' ] },
);

my $store = HTML::Index::Store::BerkeleyDB->new( 
    DB => 'db/reindex',
    COMPRESS => 1,
);
my $indexer = HTML::Index::Create->new( 
    STORE => $store,
    REFRESH => 1,
) or die "Failed to create HTML::Index::Create object\n";
for ( @test_files )
{
    my $doc = HTML::Index::Document->new( path => $_ );
    $indexer->index_document( $doc );
}
undef $indexer;
my $searcher = HTML::Index::Search->new( 
    STORE => $store,
) or die "Failed to create HTML::Index::Search object\n";
print "1..6\n";
for my $test ( @tests )
{
    do_search_test( $searcher, $test );
}

sub modify_file
{
    my $file = shift;
    my $new_word = shift;
    # print STDERR "Editing $file to match '$new_word'\n";
    my $fh = IO::File->new( $file, 'r+' )
        or die "Can't open $file for rewriting: $!\n"
    ;
    local $/;
    my $data = <$fh>;
    $data =~ s/extra/extra $new_word/;
    $fh->truncate( 0 );
    $fh->seek( 0, 0 );
    $fh->print( $data );
    $fh->close();
}

@random_words = qw( foo bar );

for $file ( @test_files )
{
    $word = shift @random_words;
    copy( $file, "$file.bak" ) or die "Can't backup $file\n";
    modify_file( $file, $word );
    push( @tests, { q => $word, paths => [ $file ] } );
    my $indexer = HTML::Index::Create->new( 
        STORE => $store,
    ) or die "Failed to create HTML::Index::Create object\n";
    my $doc = HTML::Index::Document->new( path => $file );
    $indexer->index_document( $doc );
    undef $indexer;
    my $searcher = HTML::Index::Search->new( 
        STORE => $store,
    ) or die "Failed to create HTML::Index::Search object\n";
    for my $test ( @tests )
    {
        do_search_test( $searcher, $test );
    }
    copy( "$file.bak", $file ) or die "Can't restore $file\n";
}

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):
