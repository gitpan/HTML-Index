#!/usr/bin/perl -w

use strict;

use CGI::Lite;
use HTML::Index::Search;
use HTML::Index::Search::CGI;

my $searcher = HTML::Index::Search->new( DB_DIR => "/path/to/your/db" );
my %form_data = CGI::Lite->new->parse_form_data();
my $cgi = HTML::Index::Search::CGI->new(
    SEARCH              => $searcher,
    TEMPLATE_FILE       => '/path/to/your/template/file.tmpl',
    DOCROOT             => '/path/to/your/html/document/root',
    %form_data
);

print 
    "Content-Type: text/html\n\n", 
    $cgi->search_results_page()
;
