use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'HTML::Index',
    'VERSION'     	=> '0.04',
    'PREREQ_PM'		=> {
        HTML::Index::SearchResults => undef,
        File::Find => undef,
        File::Path => undef,
        HTML::TreeBuilder => undef,
        DB_File => undef,
        Tie::TextDir => undef,
        Fcntl => undef,
        Date::Format => undef,
        CGI_Lite => undef,
        Time::HiRes => undef,
    }, # e.g., Module::Name => 1.1
);
