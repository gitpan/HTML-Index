package HTML::Index::Document;

use strict;
use warnings;

use Class::Struct;

struct 'HTML::Index::Document::Struct' => {
    name        => '$',
    path        => '$',
    contents    => '$',
    modtime     => '$'
};

use vars qw( @ISA );

@ISA = qw( HTML::Index::Document::Struct );

#------------------------------------------------------------------------------
#
# Constructor
#
#------------------------------------------------------------------------------

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    $self->_init();
    return $self;
}

sub _init
{
    my $self = shift;
    if ( my $path = $self->path() )
    {
        die "Can't read $path\n" unless -r $path;
        unless ( $self->modtime() )
        {
            $self->modtime( ( stat $path )[9] );
        }
        unless ( $self->contents() )
        {
            open( FH, $path );
            $self->contents( join( '', <FH> ) );
            close( FH );
        }
        $self->name( $self->path() ) unless $self->name();
    }
    die "No name attribute\n" unless $self->name();
    return $self;
}

#------------------------------------------------------------------------------
#
# Start of POD
#
#------------------------------------------------------------------------------

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

#------------------------------------------------------------------------------
#
# End of POD
#
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
#
# True ...
#
#------------------------------------------------------------------------------

1;
