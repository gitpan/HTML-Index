use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'HTML::Index',
    'VERSION_FROM'	=> 'lib/HTML/Index.pm',
    'PREREQ_PM'		=> {
        Carp                    => undef,
        POSIX                   => undef,
        BerkeleyDB              => undef,
        Fcntl                   => undef,
        Class::Struct           => undef,
        TempDir                 => undef,
        HTML::TreeBuilder       => undef,
        HTML::Entities          => undef,
        Time::HiRes             => undef,
        HTML::Template          => undef,
        Data::Dumper            => undef,
        Date::Format            => undef,
        Unicode::String         => undef,
        Getopt::Long            => undef,
        File::Find              => undef,
        File::Path              => undef,
        Compress::Zlib          => undef,
        Text::Soundex           => undef,
        Number::Format          => undef,

    }, # e.g., Module::Name => 1.1
);
