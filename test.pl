# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use HTML::Index;
use File::Path;
use TempDir;

$loaded = 1;
print "ok 1\n";
eval {
    my $tmp_dir = TempDir->new();
    my $db_dir = "$tmp_dir/db";
    print STDERR "Creating temporary DB directory $db_dir ...\n";
    mkpath( $db_dir ) or die "Can't create $db_dir\n" unless -d $db_dir;
    my $indexer = HTML::Index->new( 
        VERBOSE => 1,
        HTML_DIRS => [ 'html' ],
        DB_DIR => $db_dir,
    ) or die "Failed to create HTML::Index object\n";
    print STDERR "Creating index ...\n";
    $indexer->create_index();
    print STDERR "Searching index ...\n";
    my @result = $indexer->search( words => [ 'some', 'sample', 'text' ] );
    print STDERR "Result: @result\n";
    print STDERR "Cleaning up temporary database files ...\n";
    rmtree( $db_dir ) or die "Can't delete $db_dir\n" if -d $db_dir;
    if ( @result == 1 and $result[0] eq 'html/test.html' )
    {
        print "ok 2\n";
    }
    else
    {
        print "not ok 2\n";
    }
};
if ( $@ )
{
    print STDERR "2 failed : $@\n";
    print "not ok 2\n";
}
else
{
    print "ok 2\n";
}

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

