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
    die "No name attribute\n" unless defined $self->name();
    die "No contents attribute\n" unless defined $self->contents();
    die "No modtime attribute\n" unless defined $self->modtime();
    return $self;
}

#------------------------------------------------------------------------------
#
# Start of POD
#
#------------------------------------------------------------------------------

=head1 NAME

HTML::Index::Document - Perl object used by
L<HTML::Index::Create|HTML::Index::Create> to create an index of HTML documents
for searching

=head1 SYNOPSIS

    $doc = HTML::Index::Document->new( path => $path );

    $doc = HTML::Index::Document->new( 
        name        => $name,
        contents    => $contents,
        mod_time    => $mod_time,
    );

=head1 DESCRIPTION

This module allows you to create objects to represent HTML documents to be
indexed for searching using the L<HTML::Index|HTML::Index> modules. These might
be HTML files in a webserver document root, or HTML pages stored in a database,
etc.

HTML::Index::Document is a subclass of Class::Struct, with 4 attributes:

=over 4

=item path

The path to the document. This is an optional attribute, but if used should
correspond to an existing, readable file.

=item name

The name of the document. This attribute is what is returned as a result of a
search, and is the primary identifier for the document. It should be unique. If
the path attribute is set, then the name attribute defaults to path. Otherwise,
it must be provided to the constructor.

=item modtime

The modification time of the document. This attribute is used to decide whether
the document (if it already has been index) needs to be re-indexed (if the
modtime has changed and is greater than the stored value). It can also be used
to order search results. If the path attribute is set, the modtime attribute is
the file modification time that corresponds to path (determined by stat).
Otherwise, it must be provided to the constructor.

=item contents

The (HTML) contents of the document. This attribute provides the text which is
indexed by L<HTML::Search::Index|HTML::Search::Index>. If the path attribute is
set, the contents attribute defaults to the contents of path. Otherwise, it
must be provided to the constructor.

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
