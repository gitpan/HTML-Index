package HTML::Index;

$VERSION = '0.09';

#------------------------------------------------------------------------------
#
# Pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

use vars qw( %TABLES );

%TABLES = (
    options => 'HASH',
    file2fileid => 'HASH',
    fileid2file => 'RECNO',
    word2fileid => 'HASH',
    wordid2word => 'RECNO',
    soundex2wordid => 'HASH',
    fileid2modtime => 'RECNO',
);

sub new
{
    die <<EOF;
The HTML::Index interface is deprecated. 

Please see documentation (perldoc HTML::Index)
EOF
}

1;

__END__

=head1 NAME

HTML::Index - Perl modules for creating and searching an index of HTML files

=head1 SYNOPSIS

    use HTML::Index::Create;
  
    $indexer = HTML::Indexer->new(
        VERBOSE             => 1,
        STOP_WORD_FILE      => '/path/to/stopword/file',
        DB_DIR              => '/path/to/db/directory',
        COMPRESS            => 1,
        REFRESH             => 0,
        PARSER              => 'HTML',
    );

    for ( ... )
    {
        my $doc = HTML::Index::Document->new( 
            name        => $name,
            contents    => $contents,
            mod_time    => $mod_time,
        );
        $indexer->index_document( $doc );
    }

    for ( ... )
    {
        my $doc = HTML::Index::Document->new( path => $path );
        # name, contents, and mod_time are the path, contents and modification
        # time of $path
        $indexer->index_document( $doc );
    }

    use HTML::Index::Search;

    my $search = HTML::Index::Search->new( DB_DIR => $db_dir );
    my @results = $search->search( $q );

=head1 DESCRIPTION

HTML::Index is a set of modules for creating an index of HTML
documents so that they can be subsequently searched by keywords, or by
Boolean combinations of keywords. It was originally inspired by indexer.pl
script in the O'Reilly "CGI Programming with Perl, 2nd Edition" book
(http://www.oreilly.com/catalog/cgi2/author.html).

All storage operations are contained in the HTML::Index::Store module that
can be subclassed to support other storage options (such as BerkeleyDB
files, or SQL databases). One such subclass (HTML::Index::Store::BerkeleyBD)
is included in the distribution.

The modules can be used to index any HTML documents - whether stored as
files, or in a database. They support the use of stopword lists, soundex
searches, compression of the inverted indexes using Compress::Zlib, and
re-indexing of documents that have changed. A CGI search interface, which
can be customized using on HTML::Template templates, is also provided.
Search queries can be expressed as compound Boolean expressions, composed of
keywords, parentheses, and logical operators (OR, AND, NOT).

=head1 SEE ALSO

=over 4

=item L<HTML::Index::Compress|HTML::Index::Compress>

=item L<HTML::Index::Create|HTML::Index::Create>

=item L<HTML::Index::Document|HTML::Index::Document>

=item L<HTML::Index::Filter|HTML::Index::Filter>

=item L<HTML::Index::Search|HTML::Index::Search>

=item L<HTML::Index::Search::CGI|HTML::Index::Search::CGI>

=item L<HTML::Index::Stats|HTML::Index::Stats>

=item L<HTML::Index::Stopwords|HTML::Index::Stopwords>

=item L<HTML::Index::Store|HTML::Index::Store>

=item L<HTML::Index::Store::BerkeleyDB|HTML::Index::Store::BerkeleyDB>

=back

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
