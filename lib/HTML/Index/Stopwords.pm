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
# Constructor
#
#------------------------------------------------------------------------------

sub new
{
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;
    return $self->_init();
}

#------------------------------------------------------------------------------
#
# Initialization private method
#
#------------------------------------------------------------------------------

sub _init
{
    my $self = shift;
    my @w = ();
    my $stop_word_file = $self->{STOP_WORD_FILE};
    if ( defined $stop_word_file )
    {
        die "stopfile $stop_word_file doesn't exist\n"
            unless -e $stop_word_file
        ;
        die "can't read stopfile $stop_word_file\n"
            unless -r $stop_word_file
        ;
        open( STOPWORDS, $stop_word_file );
        @w = <STOPWORDS>;
        close( STOPWORDS );
        chomp( @w );
    }
    $self->{words} = { map { lc($_) => 1 } @w };
    return $self;
}

#------------------------------------------------------------------------------
#
# Public methods
#
#------------------------------------------------------------------------------

sub is_stopword
{
    my $self = shift;
    my $word = shift;
    return exists $self->{words}{lc($word)};
}

#------------------------------------------------------------------------------
#
# True
#
#------------------------------------------------------------------------------

1;

__END__

=head1 NAME

HTML::Index::Stopwords - utility module for generating stopword lists words for
indexing / searching using the L<HTML::Index|HTML::Index> modules.

=head1 SYNOPSIS

    my $stopwords = HTML::Index::Stopwords->new( STOP_WORD_FILE => $swf );
    if ( ! $stopwords->is_stopword( $word ) )
    {
        ''''
    }

=head1 DESCRIPTION

This is a simple utility module to manage stopword files for indexing / 
searching with the L<HTML::Index|HTML::Index> modules. The constructor takes a
stopword file as an argument, which, if defined, should contain the path of a
file with a newline seperated list of stopwords. The is_stopword method then
acts as a filter, returning true / false depending on whether it's argument
appears in the list. This operation is case insensitive. The interface supports
calling the constructor without the STOP_WORD_FILE argument, in which case the
is_stopword method is a noop (always returns false).

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
