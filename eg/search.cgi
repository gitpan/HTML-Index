#!/usr/bin/perl -w

use strict;

use CGI::Lite;
use HTML::Index::Search;
use HTML::Index::Search::CGI;

my $dbdir = "/path/to/your/db";


my $cgi = HTML::Index::Search::CGI->new(
    SEARCH              => HTML::Index::Search->new( DB_DIR => $dbdir ),
    TEMPLATE_FILE       => '/path/to/your/templates/dw.tmpl',
    DOCROOT             => '/path/to/your/htdocs',
    CGI::Lite->new->parse_form_data(),
);

print "Content-Type: text/html\n\n", $cgi->search_results_page();
