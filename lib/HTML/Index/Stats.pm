package HTML::Index::Stats;

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

use Number::Format qw(:subs);
use HTML::Index;
use HTML::Index::Compress;
use Class::Struct;

#------------------------------------------------------------------------------
#
# Private package globals
#
#------------------------------------------------------------------------------

my @OPTIONS = qw(
    VERBOSE
    STORE 
);

use vars qw( @ISA );

struct 'HTML::Index::Stats::Struct' => { map { $_ => '$' } @OPTIONS };

@ISA = qw( HTML::Index::Stats::Struct );

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
    die "No STORE\n" unless defined $self->STORE;
    die $self->STORE , " is not an HTML::Index::Store\n" 
        unless $self->STORE->isa( 'HTML::Index::Store' )
    ;
    $self->STORE->init( TABLES => \%HTML::Index::TABLES );
    $self->{compress} = HTML::Index::Compress->new( 
        COMPRESS => $self->STORE->COMPRESS 
    );
    return $self;
}

#------------------------------------------------------------------------------
#
# Public methods
#
#------------------------------------------------------------------------------

sub stats
{
    my $self = shift;

    my $index_size = 0;
    my $stats = "";
    while ( my ( $word, $file_ids ) = $self->_each_file_ids() )
    {
        $index_size += length( $file_ids );
    }
    my $inflated_index_size = 0;
    if ( $self->STORE->COMPRESS )
    {
        while ( my ( $word, $file_ids ) = $self->_each_file_ids( 1 ) )
        {
            $inflated_index_size += length( $file_ids );
        }
    }
    my $nwords = $self->nwords;
    my $nfiles = $self->nfiles;
    $stats .= "size: " . format_bytes( $index_size );
    $stats .= ' (' . format_bytes( $inflated_index_size ) . ')'
        if $self->STORE->COMPRESS
    ;
    $stats .= "\n";
    $stats .= "words: " . format_number( $nwords ) . "\n";
    $stats .= "files: " . format_number( $nfiles ) . "\n";
    $stats .= "bytes / word: " . format_bytes( $index_size / $nwords, 2 );
    $stats .= " (" . format_bytes( $inflated_index_size / $nwords, 2 ) .')'
        if $self->STORE->COMPRESS
    ;
    $stats .= "\n";
    $stats .= "bytes / file: " . format_bytes( $index_size / $nfiles, 2 );
    $stats .= " (" . format_bytes( $inflated_index_size / $nfiles, 2 ) . ')'
        if $self->STORE->COMPRESS
    ;
    $stats .= "\n";
    $stats .= 
        "bits / word / file: " . 
        format_bytes( ( $index_size * 8 ) / ( $nwords * $nfiles ), 2 )
    ;
    $stats .= 
        " (" . 
        format_bytes( ( $inflated_index_size * 8 ) / ( $nwords * $nfiles ), 2 ) .
        ")"
        if $self->STORE->COMPRESS
    ;
    $stats .= "\n";
    return $stats;
}

sub _each_file_ids
{
    my $self = shift;
    my $inflate = shift;

    my ( $word, $file_ids ) = $self->STORE->each( 'word2fileid' );
    return () unless defined $word and defined $file_ids;
    $file_ids = $self->{compress}->inflate( $file_ids ) if $inflate;
    return ( $word, $file_ids );
}

sub print_words
{
    my $self = shift;
    my $include_values = shift;

    while ( my ( $word, $file_ids ) = $self->_each_file_ids )
    {
        print $word;
        print " ", unpack( "B*", $file_ids ), "\n" if $include_values;
        print "\n";
    }
}

sub words
{
    my $self = shift;
    my $include_values = shift;

    my @words;
    while ( my ( $word, $file_ids ) = $self->_each_file_ids )
    {
        push( @words, $word );
        push( @words, unpack( "B*", $file_ids ) ) if $include_values;
    }
    return @words;
}

sub files
{
    my $self = shift;

    my @files;
    while ( my ( $key, $val ) = $self->STORE->each( 'file2fileid' ) )
    {
        push( @files, $key );
    }
    return @files;
}

sub nwords
{
    my $self = shift;
    return $self->STORE->nkeys( 'word2fileid' );
}

sub nfiles
{
    my $self = shift;
    return $self->STORE->nkeys( 'file2fileid' );
}

#------------------------------------------------------------------------------
#
# True
#
#------------------------------------------------------------------------------

1;

__END__

=head1 NAME

HTML::Index::Stats - utility module for providing statistics on the inverted
index generated by L<HTML::Index::Create|HTML::Index::Create>.

=head1 SYNOPSIS

    my $store = HTML::Index::Store::BerkeleyDB->new( DB => $db );
    my $stats = HTML::Index::Stats->new( STORE => $store );
    print $stats->stats();
    my @words = $stats->words();
    my @files = $stats->files();
    my $nwords = $stats->nwords();
    my $nfiles = $stats->nfiles();

=head1 DESCRIPTION

This is a simple utility module to print statistics of a
L<HTML::Index::Store|HTML::Index::Store> object, and to access the list of /
number of words / files it contains. The stats reports stuff like the number of
bits / word used in storage, both compressed and uncompressed, etc.

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
