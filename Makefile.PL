use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'HTML::Index',
    'VERSION_FROM'	=> 'lib/HTML/Index.pm',
    'PREREQ_PM'		=> {
        BerkeleyDB              => undef,
        Fcntl                   => undef,
        Class::Struct           => undef,
        TempDir                 => undef,
        HTML::TreeBuilder       => undef,
        HTML::Entities          => undef,
        Time::HiRes             => undef,
        HTML::Template          => undef,
        Date::Format            => undef,
    }, # e.g., Module::Name => 1.1
);
