package HTML::Index::Store::BerkeleyDB;

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

use BerkeleyDB;
use Fcntl;
use File::Path;
use HTML::Index::Store;
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

    $self->{table_hash} = $table_hash;

    my $flags = $self->MODE eq 'r' ? DB_RDONLY : DB_CREATE;
    while ( my ( $table, $type ) = CORE::each %{$self->{table_hash}} )
    {
        my $db_path = $self->DB . "/$table.db";
        if ( -e $db_path and $options{REFRESH} )
        {
            print LOG "Refreshing $table table\n";
            unlink( $db_path ) or croak "Can't remove $db_path\n";
        }
        my $tied;
        if ( $type eq 'RECNO' )
        {
            $tied = new BerkeleyDB::Recno(
                '-Filename'        => $db_path, 
                '-Flags'           => $flags,
            ) or croak "Cannot tie to $db_path ($flags): $!\n";
        }
        elsif ( $type eq 'HASH' )
        {
            $tied = new BerkeleyDB::Hash(
                '-Filename'        => $db_path, 
                '-Flags'           => $flags,
                '-Pagesize'        => 512,
            ) or croak "Cannot tie to $db_path ($flags): $!\n";
        }
        $self->{$table} = $tied;
        print LOG "table $table ($self->{$table}) tied - $tied\n";
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
    return unless defined $self->{table_hash};
    while ( my ( $table, $type ) = CORE::each %{$self->{table_hash}} )
    {
        print LOG "Untie $table ...\n";
        next unless $self->{$table};
        undef( $self->{$table} );
    }
}

#------------------------------------------------------------------------------
#
# Public methods
#
#------------------------------------------------------------------------------

sub put
{
    my $self = shift;
    my $table = shift;
    croak "put called before init\n" unless defined $self->{table_hash};
    my $type = $self->{table_hash}{$table};
    unless ( $type )
    {
        croak 
            "Can't put $table (not one of ", 
            join( ',', keys %{$self->{table_hash}}) , 
            ")\n"
        ;
    }
    my $key = shift;
    my $val = shift;
    croak "Putting undef into $table $key\n" unless defined $val;
    print LOG 
        "put $table $key ", 
        ( $table eq 'word2fileid' ? unpack( "B*", $val ) : $val ),
        "\n"
    ;
    my $status = $self->{$table}->db_put( $key, $val );
    croak "Can't db_put $val into the $key field of $table: $status\n" if $status;
}

sub get
{
    my $self = shift;
    my $table = shift;
    croak "get called before init\n" unless defined $self->{table_hash};
    my $type = $self->{table_hash}{$table};
    unless ( $type )
    {
        croak 
            "Can't get $table (not one of ", 
            join( ',', keys %{$self->{table_hash}}) , 
            ")\n"
        ;
    }
    my $key = shift;
    my $val;

    my $status = $self->{$table}->db_get( $key, $val );
    croak "Can't get $key key of $table: $status\n" 
        unless 
            $status == 0 ||
            $status == DB_NOTFOUND
    ;
    print LOG "get $table $key";
    print LOG " " . ( $table eq 'word2fileid' ? unpack( "B*", $val ) : $val ) 
        if defined $val
    ;
    print LOG "\n";
    return $val;
}

sub each
{
    my $self = shift;
    my $table = shift;

    croak "each called before init\n" unless defined $self->{table_hash};
    my $flag;

    if ( defined( $self->{cursor} ) )
    {
        $flag = DB_NEXT;
    }
    else
    {
        $self->{cursor} = $self->{$table}->db_cursor();
        $flag = DB_FIRST;
    }
    my ( $key, $val ) = ( '', 0 );
    my $status = $self->{cursor}->c_get( $key, $val, $flag );
    if ( $status != 0 )
    {
        $self->{cursor} = undef;
        return ();
    }
    else
    {
        return ( $key, $val );
    }
}

sub cput
{
    my $self = shift;
    my $key = shift;
    my $val = shift;

    croak "cput called before init\n" unless defined $self->{table_hash};
    croak "Must call each before cput\n" unless defined $self->{cursor};
    my $status = $self->{cursor}->c_put( $key, $val, DB_CURRENT );
    croak "$self->{cursor} c_put failed: $status\n" unless $status == 0;
    return $status == 0;
}

sub nkeys
{
    my $self = shift;
    my $table = shift;

    croak "nkeys called before init\n" unless defined $self->{table_hash};
    my $db_stat = $self->{$table}->db_stat();
    return $db_stat->{bt_nkeys} if defined $db_stat->{bt_nkeys};
    return $db_stat->{hash_nkeys} if defined $db_stat->{hash_nkeys};
    return $db_stat->{qs_nkeys} if defined $db_stat->{hash_nkeys};
    return undef;
}

#------------------------------------------------------------------------------
#
# True
#
#------------------------------------------------------------------------------

1;

__END__

=head1 NAME

HTML::Index::Store::BerkeleyDB - subclass of
L<HTML::Index::Store|HTML::Index::Store> using BerkeleyDB.

=head1 SYNOPSIS

    my $store = HTML::Index::Store::BerkeleyDB->new( 
        COMPRESS => 1,
        DB => $path_to_dbfile_directory,
        STOP_WORD_FILE => $swf,
    );
    $store->init(
        TABLES => \%HTML::Index::TABLES,
        REFRESH => 1,
    );

=head1 DESCRIPTION

This module is a subclass of the L<HTML::Index::Store|HTML::Index::Store>
module, that uses Berkeley DB files to store the inverted index.

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
