package HTML::Index::Store;

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
use Class::Struct;
use TempDir;

#------------------------------------------------------------------------------
#
# Private package globals
#
#------------------------------------------------------------------------------

my @OPTIONS = qw(
    VERBOSE
    REFRESH
    DB_DIR
    MODE
);

use vars qw( %DB_FILES @ISA );

%DB_FILES = (
    file2fileid => 'HASH',
    fileid2file => 'RECNO',
    word2fileid => 'HASH',
    fileid2modtime => 'RECNO',
);

struct 'HTML::Index::Store::Struct' => { map { $_ => '$' } @OPTIONS };

@ISA = qw( HTML::Index::Store::Struct );

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

#------------------------------------------------------------------------------
#
# Initialization private method
#
#------------------------------------------------------------------------------

sub _init
{
    my $self = shift;

    if ( $self->VERBOSE )
    {
        open( LOG, ">&STDERR" );
    }
    else
    {
        open( LOG, ">/dev/null" );
    }
    unless ( defined $self->DB_DIR )
    {
        my $dir = join( '/', TempDir->new, ref( $self ) );
        print LOG "Creating DB_DIR $dir\n";
        $self->DB_DIR( $dir );
    }
    unless ( -d $self->DB_DIR )
    {
        print LOG "mkdir ", $self->DB_DIR, "\n";
        mkdir( $self->DB_DIR ) or die "can't mkdir ", $self->DB_DIR, ": $!\n";
    }
    # $self->{db_env} = new BerkeleyDB::Env(
        # '-Flags'        => DB_INIT_LOCK,
    # );
    # die "Failed to create BerkeleyDB::Env: $!\n" unless $self->{db_env};
    # my $status = $self->{db_env}->setmutexlocks();
    # die "setmutexlocks failed: $status\n" if $status != 0;

    $self->MODE( 'r' ) unless $self->MODE;

    while ( my ( $db_file, $type ) = each %DB_FILES )
    {
        my $db_path = $self->DB_DIR . "/$db_file.db";
        if ( -e $db_path and $self->REFRESH )
        {
            print LOG "Refreshing $db_file db\n";
            unlink( $db_path ) or die "Can't remove $db_path\n";
        }
        my $tied;
        my $flags = $self->MODE eq 'r' ? DB_RDONLY : DB_CREATE;
        if ( $type eq 'RECNO' )
        {
            $tied = new BerkeleyDB::Recno(
                Filename        => $db_path, 
                Flags           => $flags,
                Env             => $self->{db_env},
            ) or die "Cannot tie to $db_path ($flags): $!\n";
        }
        elsif ( $type eq 'HASH' )
        {
            $tied = new BerkeleyDB::Hash(
                Filename        => $db_path, 
                Flags           => $flags,
                Pagesize        => 512,
                Env             => $self->{db_env},
            ) or die "Cannot tie to $db_path ($flags): $!\n";
        }
        $self->{$db_file} = $tied;
        print LOG "db $db_file ($self->{$db_file}) tied - $tied\n";
    }
    return $self;
}

#------------------------------------------------------------------------------
#
# AUTOLOAD
#
#------------------------------------------------------------------------------

sub AUTOLOAD
{
    use vars qw( $AUTOLOAD );
    my $db = $AUTOLOAD;
    $db =~ s/.*:://;
    return if $db eq 'DESTROY';
    my $type = $DB_FILES{$db};
    unless ( $type )
    {
        die 
            "Unknown method $db (not one of ", 
            join( ',', values %DB_FILES) , 
            ")\n"
        ;
    }
    my $self = shift;
    my $key = shift;
    return $self->{$db} unless defined $key;
    my $val = shift;
    if ( defined $val )
    {
        my $status = $self->{$db}->db_put( $key, $val );
        die "Can't db_put $val into the $key field of $db: $status\n" if $status;
    }
    else
    {
        my $status = $self->{$db}->db_get( $key, $val );
    }
    return $val;
}

#------------------------------------------------------------------------------
#
# Destructor
#
#------------------------------------------------------------------------------

sub untie
{
    my $self = shift;

    print LOG "destroying $self\n";
    while ( my ( $db_file, $type ) = each %DB_FILES )
    {
        print LOG "Untie $db_file ...\n";
        next unless $self->{$db_file};
        undef( $self->{$db_file} );
    }
}

#------------------------------------------------------------------------------
#
# Public methods
#
#------------------------------------------------------------------------------

sub deindex
{
    my $self = shift;
    my $file_id = shift;

    print LOG "$file_id has changed - deindexing ...\n";

    my ( $word, $file_ids, $file ) = ( 0,0,0 );
    my $cursor = $self->{word2fileid}->db_cursor();
    while ( $cursor->c_get( $word, $file_ids, DB_NEXT ) == 0 )
    {
        my $file_ids = $self->remove_file_id( $file_ids, $file_id );
        my $status = $cursor->c_put( $word, $file_ids, DB_CURRENT );
        die "Can't c_put $file_ids in $word key of word2fileid: $status\n"
            if $status
        ;
    }
}

sub remove_file_id
{
    my $self = shift;
    my $file_ids = shift;
    my $file_id = shift;

    my @block = ();
    if ( defined $file_ids )
    {
        @block = unpack( "C*", $file_ids );
    }
    my $blockn = int( $file_id / 8 );
    my $block = $block[$blockn];
    my $bitn = $file_id % 8;
    my $mask = ~ ( 1 << $bitn );
    $block[$blockn] = $block ? ( $block & $mask ) : 0;
    $file_ids = pack( "C*", map { $_ ? $_ : 0 } @block );
}

sub add_file_id
{
    my $self = shift;
    my $file_ids = shift;
    my $file_id = shift;

    my @block = ();
    if ( defined $file_ids )
    {
        @block = unpack( "C*", $file_ids );
    }
    my $blockn = int( $file_id / 8 );
    my $block = $block[$blockn];
    my $bitn = $file_id % 8;
    my $mask = ( 1 << $bitn );
    $block[$blockn] = $block ? ( $block | $mask ) : $mask;
    $file_ids = pack( "C*", map { $_ ? $_ : 0 } @block );
}

sub add_words
{
    my $self = shift;
    my $file_id = shift;
    my $words = shift;

    for my $w ( @$words )
    {
        my $file_ids = $self->word2fileid( $w );
        $file_ids = $self->add_file_id( $file_ids, $file_id );
        $self->word2fileid( $w, $file_ids );
    }
}

sub get_new
{
    my $self = shift;
    my $db = shift;
    my $type = $DB_FILES{$db};
    unless ( $type )
    {
        die 
            "Unknown method $db (not one of ", 
            join( ',', keys %DB_FILES) , 
            ")\n"
        ;
    }
    die "get_new only works for RECNO\n" unless $type eq 'RECNO';
    return $self->{$db}->length();
}

sub dump_fileid2fileid
{
    my $self = shift;
    my $mask = shift;

    my @file_ids;
    my $file_id = 0;
    my $bit = 1;
    while ( $bit <= $mask )
    {
        push( @file_ids, $file_id ) if $mask & $bit;
        $bit = $bit << 1;
        $file_id++;
    }
    return map { $self->fileid2file( $_ ) } @file_ids;
}

sub sync
{
    my $self = shift;
    my $db = shift;
    if ( my $status = $self->{$db}->db_sync )
    {
        die "Can't sync db $db ($self->{$db}): $status\n";
    }
}

sub print_stats
{
    my $self = shift;

    $self->sync( 'word2fileid' );
    my $index_size = ( stat( $self->DB_DIR . "/word2fileid.db" ) )[7];
    my $nwords = $self->{word2fileid}->db_stat()->{hash_nkeys};
    my $nfiles = $self->{file2fileid}->db_stat()->{hash_nkeys};
    print "size: $index_size ";
    print "words: $nwords ";
    print "files: $nfiles ";
    my $bpw = 8 * ( $index_size / $nwords );
    printf "bits/word: %.2f ", $bpw;
    my $bpwpf = $bpw / $nfiles;
    printf "bits/word/file: %.2f\n", $bpwpf;
}

sub print_words
{
    my $self = shift;
    my ( $key, $val ) = ( 0,0 );
    my $cursor = $self->{word2fileid}->db_cursor();
    while ( $cursor->c_get( $key, $val, DB_NEXT ) == 0 )
    {
        $val = join( ',', unpack( "C*", $val ) );
        print "$key ($val)\n";
    }
    print "TOTAL: ", $self->nwords, " words\n";
}

sub nwords
{
    my $self = shift;
    return $self->{word2fileid}->db_stat()->{hash_nkeys};
}

sub print_files
{
    my $self = shift;
    my ( $key, $val ) = ( 0,0 );
    my $cursor = $self->{file2fileid}->db_cursor();
    while ( $cursor->c_get( $key, $val, DB_NEXT ) == 0 )
    {
        print "$key ($val)\n";
    }
    print "TOTAL: ", $self->nfiles, " files\n";
}

sub nfiles
{
    my $self = shift;
    return $self->{file2fileid}->db_stat()->{hash_nkeys};
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

=head1 CONSTRUCTOR OPTIONS

=head1 METHODS

=head1 SEE ALSO

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
