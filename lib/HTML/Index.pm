package HTML::Index;

$VERSION = '0.05';

#------------------------------------------------------------------------------
#
# Pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

#------------------------------------------------------------------------------
#
# Private package globals
#
#------------------------------------------------------------------------------

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

HTML::Index - Perl extension for indexing HTML files

=head1 SYNOPSIS

  use HTML::Index;
  
  $indexer = HTML::Indexer->new( %options );

  $indexer->create_index;

  @results = $indexer->search( 
    words => [ 'search', keywords' ],
    logic => 'OR',
  );

  for my $result ( @results )
  {
    print "words found: ", $result->words, "\n";
    print "path found on: ", $result->path, "\n";
  }

=head1 DESCRIPTION

HTML::Index is a simple module for indexing HTML files so that they can be
subsequently searched by keywords. It is looselly based on the indexer.pl
script in the O'Reilly "CGI Programming with Perl, 2nd Edition" book
(http://www.oreilly.com/catalog/cgi2/author.html).

Indexing is based on a list of directories passed to the constructor as one of
its options (HTML_DIRS). All files in these directories whose extensions match
the EXTENSIONS_REGEX are parsed using HTML::TreeBuilder and the word in those
pages added to the index. Words are stored lowercase, anything at least 2
characters long, and consist of alphanumerics ([a-z\d]{2,}).

Indexing is also possible in "remote" mode; here a list of URLs is provided,
and indexed files are grabbed via HTTP from these URLs, and all pages linked
from them. Only pages on the same site are indexed.

Indexes are stored in various database files. The default is to use Berkeley
DB, but the filesystem can be use if Berkeley DB is not installed using
Tie::TextDir.

The modification times of files in the index are stored, and they are
"re-inexed" if their modification time changes. Searches return results in no
particular order - it is up to the caller to re-order them appropriately!
Indexes can be run incrementally - only new or updated files will be indexed or
re-indexed.

=head1 OPTIONS

=over 4

=item DB_TYPE

This should be either 'DB_File' or 'Tie::TextDir' depending on what type of
database you want to use for the index (Berkeley DB or filesystem). Default is
'DB_File'.

=item VERBOSE

Print various bumpf to STDERR.

=item SLEEP

Specify a period in seconds to sleep between files when indexing. Helps to
prevent thrashing the server for large indexes.

=item STOP_WORD_FILE

Specify a file containing "stop words" to ignore when indexling. A sample
stopwords.txt file is included in this distribution. MAke sure you use the same
STOP_WORD_FILE for indexing and searching. Otherwise, if you submit a search
for a word that was in the stop word list when indexing (especially in a
combination search) you may not get the result you expect!

=item DB_HASH_CACHESIZE

Set the cachesize for the DB_File hashes. Default is 0.

=item REMOTE

Operate in "remote" mode; expects URLS rather than HTML_DIRS filesystem
paths, and index pages by grabbing them via HTTP. Links off the URLs listed are
followed so that these pages can also be indexed. Only "internal" links are
followed.

=item REFRESH

Boolean to regenerate the index from scratch.

=item HTML_DIRS

Specify a list of directories to index as an array ref. Defaults to [ '.' ].

=item URLS

Specify a list of URLs to index as an array ref. Defaults to [ ].

=item IGNORE

Specify a regex of HTML_DIRS to ignore.

=item DB_DIR

Specify a directory to store the Berkeley DB files. Defaults to '.'.

=item EXTENSIONS_REGEX

Specify a regex of file extension to match for HTML files to be indexed.
Defaults to 's?html?'.

=back

=head1 METHODS

=over 4

=item create_index

Does exactly what it says on the can.

=item search

Search the index, returning an array of L<HTML::Index::SearchResults> objects.
Takes two arguments:

=over 4

=item words

An array ref to the keywords to search on. Keywords are "normalized" in the
same way as words in the index (i.e. lowercase, only alphanumerics, at least 2
character).

=item logic

Either OR or AND. Determines how the search words are combined logically.
Default is AND.

=back

=back

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
