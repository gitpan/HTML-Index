use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'HTML::Index',
    'VERSION_FROM'	=> 'Index.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        File::Find => undef,
        File::Path => undef,
        HTML::TreeBuilder => undef,
        DB_File => undef,
        Tie::TextDir => undef,
        Fcntl => undef,
    }, # e.g., Module::Name => 1.1
);
