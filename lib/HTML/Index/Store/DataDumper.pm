package HTML::Index::Store::DataDumper;

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

use Data::Dumper;
use HTML::Index::Store;
use File::Path;
use Carp;

use vars qw( @ISA );
@ISA = qw( HTML::Index::Store );

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    return $self;
}

#------------------------------------------------------------------------------
#
# Initialization public method
#
#------------------------------------------------------------------------------

sub init
{
    my $self = shift;
    my %options = @_;

    if ( $self->VERBOSE )
    {
        open( LOG, ">&STDERR" );
    }
    else
    {
        open( LOG, ">/dev/null" );
    }
    print LOG "Initialize $self\n";
    croak "No DB\n" unless defined $self->DB;
    unless ( -d $self->DB )
    {
        print LOG "mkpath ", $self->DB, "\n";
        mkpath( $self->DB ) or croak "can't mkpath ", $self->DB, ": $!\n";
    }
    $self->MODE( 'rw' ) unless $self->MODE;
    my $table_hash = $options{TABLES};
    croak "no table hash passed to init\n" unless defined $table_hash;
    croak "$table_hash is not a hashref\n" unless ref( $table_hash ) eq 'HASH';
    for my $table ( keys %{$table_hash} )
    {
        my $path = $self->DB . "/$table.pl";
        print LOG "Create $table ($path)\n";
        if ( -e $path and not $options{REFRESH} )
        {
            $self->{$table} = do $path;
        }
        $self->{PATH}{$table} = $path;
    }
    $self->SUPER::init( %options );
    return $self;
}

#------------------------------------------------------------------------------
#
# Destructor
#
#------------------------------------------------------------------------------

sub DESTROY
{
    my $self = shift;

    print LOG "destroying $self\n";
    if ( $self->MODE eq 'r' )
    {
        print LOG "Not saving table - read only mode\n";
        return;
    }
    for my $table ( keys %{$self->{PATH}} )
    {
        my $hash = $self->{$table};
        my $path = $self->{PATH}{$table};
        print LOG "Dump $table to $path...\n";
        open( FH, ">$path" ) or die "Can't write to $path\n";
        print FH Dumper( $hash );
    }
}

#------------------------------------------------------------------------------
#
# True
#
#------------------------------------------------------------------------------

1;

__END__

=head1 NAME

HTML::Index::Store::DataDumper - subclass of
L<HTML::Index::Store|HTML::Index::Store> using Data::Dumper.

=head1 SYNOPSIS

    my $store = HTML::Index::Store::DataDumper->new( 
        COMPRESS => 1,
        DB => $path_to_data_dumper_file_directory,
        STOP_WORD_FILE => $swf,
    );
    $store->init(
        TABLES => \%HTML::Index::TABLES,
        REFRESH => 1,
    );

=head1 DESCRIPTION

This module is a subclass of the L<HTML::Index::Store|HTML::Index::Store>
module, that uses Data::Dumper files to store the inverted index.

=head1 SEE ALSO

=over 4

=item L<HTML::Index|HTML::Index>

=item L<HTML::Index::Store|HTML::Index::Store>

=back

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
