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

use Class::Struct;
use Carp;

#------------------------------------------------------------------------------
#
# Private package globals
#
#------------------------------------------------------------------------------

my @OPTIONS = qw(
    VERBOSE
    COMPRESS
    STOP_WORD_FILE
    DB
    MODE
);

struct 'HTML::Index::Store::Struct' => { map { $_ => '$' } @OPTIONS };

use vars qw( @ISA );
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
    return $self;
}

#------------------------------------------------------------------------------
#
# public methods
#
#------------------------------------------------------------------------------

sub init
{
    my $self = shift;
    my %options = @_;

    if ( defined $self->STOP_WORD_FILE )
    {
        # save options
        $self->put( 'options', 'STOP_WORD_FILE', $self->STOP_WORD_FILE );
    }
    else
    {
        # get options
        $self->STOP_WORD_FILE( $self->get( 'options', 'STOP_WORD_FILE' ) );
    }
    if ( defined $self->COMPRESS )
    {
        # save options
        $self->put( 'options', 'COMPRESS', $self->COMPRESS );
    }
    else
    {
        # get options
        $self->COMPRESS( $self->get( 'options', 'COMPRESS' ) );
    }
}

sub get
{
    my $self = shift;
    my $table = shift;
    my $key = shift;

    return $self->{$table}{$key};
}

sub put
{
    my $self = shift;
    my $table = shift;
    my $key = shift;
    my $val = shift;

    $self->{$table}{$key} = $val;
}

sub each
{
    my $self = shift;
    my $table = shift;
    my @each = each( %{$self->{$table}} );
    $self->{curr_table} = @each ? $table : undef;
    return @each;
}

sub cput
{
    my $self = shift;
    my $key = shift;
    my $val = shift;

    croak "Must call each before cput\n" unless defined $self->{curr_table};
    $self->{$self->{curr_table}}{$key}{$val};
}

sub nkeys
{
    my $self = shift;
    my $table = shift;

    return scalar keys %{$self->{$table}};
}

#------------------------------------------------------------------------------
#
# True
#
#------------------------------------------------------------------------------

1;

__END__

=head1 NAME

HTML::Index::Store - subclass'able module for storing inverted index files for
the L<HTML::Index|HTML::Index> modules.

=head1 SYNOPSIS

    my $store = HTML::Index::Store->new( 
        VERBOSE => 0,
        MODE => 'r',
        COMPRESS => 1,
        DB => $db,
        STOP_WORD_FILE => $swf,
    );
    $store->init(
        TABLES => \%HTML::Index::TABLES,
        REFRESH => 1,
    );

=head1 DESCRIPTION

The HTML::Index::Store module is generic interface to provide storage for the
inverted indexes used by the L<HTML::Index|HTML::Index> modules. The reference
implementation uses in memory storage, so is not suitable for persistent
applications (where the search / index functionality is seperated). Subclasses
of this module should override the methods described below, and then be passed
as a constructor argument to the L<HTML::Index::Create|HTML::Index::Create> and
L<HTML::Index::Search|HTML::Index::Search> modules.

There are two subclasses of this module provided with this distribution;
L<HTML::Index::Store::BerkeleyDB|HTML::Index::Store::BerkeleyDB> and
L<HTML::Index::Store::DataDumper|HTML::Index::Store::DataDumper>

=head1 CONSTRUCTOR OPTIONS

Constructor options allow the HTML::Index::Store to provide a token to identify
the database that is being used (this might be a directory path of a Berkeley
DB implementation, or a database descriptor for a DBI implementation). It also
allows options (STOP_WORD_FILE and COMPRESS) to be set. These options are then
stored in an options table in the database, and are therefore "sticky" - so
that the search interface can automatically use the same options setting used
at creating time.

=over 4

=item DB

Database identifier. Available to subclassed modules using the DB method call.

=item MODE

Either 'r' or 'rw' depending on whether the HTML::Index::Store module is
created in read only or read/write mode.

=item VERBOSE

If true, print stuff to STDERR.

=item STOP_WORD_FILE

This option is the path to a stopword file (see
L<HTML::Index::Stopwords|HTML::Index::Stopwords>). If set, the same stopword
file is available for both creation and searching of the index.

=item COMPRESS

If true, use L<HTML::Index::Compress|HTML::Index::Compress> compression on the
inverted index file. This option is also "sticky" for searching (obviously!).

=back

=head1 METHODS

=over 4

=item init( %options )

The %options hash contains two keys:

=over 4

=item TABLES

The TABLES option is an hashref of table names that the
L<HTML::Index::Store|HTML::Index::Store> module is required to create and
maintain. The keys of this hash are the names of the tables, and the values are
one of 'HASH' or 'RECNO', which give a clue as to what type of data is required
to be stored in that table (basically, keyed on an integer or a string). The
current list of tables used is:

    %HTML::Index::TABLES = (
        options => 'HASH',
        file2fileid => 'HASH',
        fileid2file => 'RECNO',
        word2fileid => 'HASH',
        wordid2word => 'RECNO',
        soundex2wordid => 'HASH',
        fileid2modtime => 'RECNO',
    );

but a subclass of L<HTML::Index::Store|HTML::Index::Store> should be prepare
to store any list of tables provided to its init method using this option.

=item REFRESH

If the value of this option is true, the module should flush the data from its
tables at initialization.

=back

=item get( $table, $key )

Get the $key entry in the $table table.

=item put( $table, $key, $val )

Set the $key entry in the $table table to the value $val.

=item each( $table )

First call to each sets a cursor for the table $table, and returns a ( $key,
$value ) pair. Subsequent calls advance the cursor and return subsequest (
$key, $value ) pairs. Returns ( undef, undef ) after the last entry has been
returned.

=item cput( $key, $val )

Iserts the key and value in the current table at the current cursor position
(as determined by the most recent call to each).

=item nkeys( $table )

Returns the number of keys in the $table table.

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
