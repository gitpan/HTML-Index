package HTML::Index::SearchResults;

require 5.005_62;
use strict;
use warnings;

my %KEYS = (
    path => undef,
    words => [],
);

sub new
{
    my $class = shift;
    my %args = ( %KEYS, @_ );
    for ( keys ( %args ) )
    {
        die "Unknown key: $_\n" unless exists $KEYS{$_};
    }
    my $self = bless \%args, $class;
    return $self;
}

sub DESTROY
{
}

sub AUTOLOAD
{
    our $AUTOLOAD;
    my $method = $AUTOLOAD;

    $method =~ s/.*:://;
    die "Unknown method: $method\n" unless exists $KEYS{$method};
    my $self = shift;
    my $value = shift;

    $self->{$method} = $value if defined $value;
    return 
        ref( $self->{$method} ) eq 'ARRAY' ? 
            @{$self->{$method}} : 
            $self->{$method}
    ;
}

1;

__END__

=head1 NAME

HTML::Index::SearchResults - utility class for HTML::Index.

=head1 SYNOPSIS

  use HTML::Index::SearchResults;

=head1 DESCRIPTION

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>
Patrick Browne <patrick@centricview.com>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
