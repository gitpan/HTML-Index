package HTML::Index::Filter;

#------------------------------------------------------------------------------
#
# Pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

#------------------------------------------------------------------------------
#
# Constructor
#
#------------------------------------------------------------------------------

sub new
{
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}

#------------------------------------------------------------------------------
#
# Public methods
#
#------------------------------------------------------------------------------

sub filter
{
    my $self = shift;
    my @n;
    for ( @_ )
    {
        tr/A-Z/a-z/;                    # convert to lc
        tr/a-z0-9//c;                   # delete all non-alphanumeric 
        next unless length( $_ );       # ... and delete empty strings that
                                        # result ...
        next unless /^.{2,}$/;          # at least two characters long
        next unless /[a-z]/;            # at least one letter
        push( @n, $_ );
    }
    return wantarray ? @n : $n[0];
}

#------------------------------------------------------------------------------
#
# True
#
#------------------------------------------------------------------------------

1;

__END__

=head1 NAME

HTML::Index::Filter - utility module for filtering words for indexing /
searching using the L<HTML::Index|HTML::Index> modules.

=head1 SYNOPSIS

    my $filter = HTML::Index::Filter->new();
    my @w = $filter->filter( @w );
    my $w = $filter->filter( $w );

=head1 DESCRIPTION

Very simple utility module to provide a symetric filter for indexing and
searching words using the L<HTML::Index|HTML::Index> modules. Basically:

=over 4

=item converts to lc

=item deletes all non-alphanumeric 

=item deletes empty strings

=item checks that the work is at least two characters long

=item and that there is at least one letter

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
