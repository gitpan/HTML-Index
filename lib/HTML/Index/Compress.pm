package HTML::Index::Compress;

#------------------------------------------------------------------------------
#
# Pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

#------------------------------------------------------------------------------
#
# Modules
#
#------------------------------------------------------------------------------

use Compress::Zlib;
use Class::Struct;

#------------------------------------------------------------------------------
#
# Private package globals
#
#------------------------------------------------------------------------------

my @OPTIONS = qw(
    COMPRESS
);

use vars qw( @ISA );

struct 'HTML::Index::Compress::Struct' => { map { $_ => '$' } @OPTIONS };
@ISA = qw( HTML::Index::Compress::Struct );

#------------------------------------------------------------------------------
#
# Constructor
#
#------------------------------------------------------------------------------

sub new
{
    my $class = shift;
    return $class->SUPER::new( @_ );
}

#------------------------------------------------------------------------------
#
# Public methods
#
#------------------------------------------------------------------------------

sub deflate
{
    my $self = shift;
    my $data = shift;
    return $data unless $self->COMPRESS;
    my ( $deflate, $out, $status );
    ( $deflate, $status ) = deflateInit( -Level => Z_BEST_COMPRESSION )
        or die "deflateInit failed: $status\n"
    ;
    ( $out, $status ) = $deflate->deflate( \$data );
    die "deflate failed: $status\n" unless $status == Z_OK;
    $data = $out;
    ( $out, $status ) = $deflate->flush();
    die "flush failed: $status\n" unless $status == Z_OK;
    $data .= $out;
    return $data;
}

sub inflate
{
    my $self = shift;
    my $data = shift;

    return $data unless $self->COMPRESS;
    my ( $inflate, $status );
    ( $inflate, $status ) = inflateInit()
        or die "inflateInit failed: $status\n"
    ;
    ( $data, $status ) = $inflate->inflate( \$data )
        or die "inflate failed: $status\n"
    ;
    return $data;
}

#------------------------------------------------------------------------------
#
# True
#
#------------------------------------------------------------------------------

1;

__END__

=head1 NAME

HTML::Index::Compress - utility module for compressing HTML::Index inverted
indices

=head1 SYNOPSIS

    my $compressor = HTML::Index::Compress->new( COMPRESS => 1);
    $compressed = $compressor->deflate( $data );
    $data = $compressor->inflate( $compressed );

=head1 DESCRIPTION

This is a simple utility module that provides a compressor object to inflate /
deflate data, using the Zlib::Compress module. The constructor takes a COMPRESS
option, which, if false, turns the inflate / deflate methods into noops.

=head1 METHODS

=over 4

=item inflate

does exactly what it says on the can ...

=item deflate

does exactly what it says on the can ...

=back

=head1 SEE ALSO

=over 4

=item L<HTML::Index|HTML::Index>

=back

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
