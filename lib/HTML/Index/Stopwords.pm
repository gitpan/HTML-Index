package HTML::Index::Stopwords;

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

#------------------------------------------------------------------------------
#
# Private methods
#
#------------------------------------------------------------------------------

sub _create_stopword_list
{
    my $self = shift;
    my $stop_word_file = shift;

    return unless defined $stop_word_file;
    die "stopfile $stop_word_file doesn't exist\n"
        unless -e $stop_word_file
    ;
    die "can't read stopfile $stop_word_file\n"
        unless -r $stop_word_file
    ;
    open( STOPWORDS, $stop_word_file );
    $self->{STOPWORD_HASH} = { map { $_ => 1 } _normalize( <STOPWORDS> ) };
    close( STOPWORDS );
}

#------------------------------------------------------------------------------
#
# Constructor
#
#------------------------------------------------------------------------------

sub new
{
    my $class = shift;
    my $stopword_file = shift;
    my $self = bless {}, $class;

    $self->{STOPWORD_HASH} = { };
    $self->_create_stopword_list( $stopword_file );

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

    return map { $self->{STOPWORD_HASH}{$_} ? () : $_ } $self->_normalize( @_ );
}

#------------------------------------------------------------------------------
#
# Private methods
#
#------------------------------------------------------------------------------

sub _normalize
{
    my $self = shift;
    my @n;
    for ( @_ )
    {
        chomp;
        tr/A-Z/a-z/;
        s/[^a-z0-9]//g;
        next unless $_;
        next unless /[a-z]/;
        next unless /^.{2,}$/;
        push( @n, $_ );
    }
    return @n;
}

#------------------------------------------------------------------------------
#
# True
#
#------------------------------------------------------------------------------

1;

__END__

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
