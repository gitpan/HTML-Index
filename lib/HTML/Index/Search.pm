package HTML::Index::Search;

require 5.005_62;
use strict;
use warnings;

use Time::HiRes qw(gettimeofday);
use HTML::Index;
use HTML::Template;
use CGI_Lite;
use Date::Format;

sub get_content
{
    my $path = shift;

    return '' unless open( FILE, $path );
    my $html = join( '', <FILE> );
    close( FILE );
    return $html;
}

sub get_title
{
    shift =~ m{<TITLE.*?>([^>]+)</TITLE>}is;
    return $1;
}

sub get_url
{
    my $self = shift;
    my $from = shift;
    my $to = shift;

    return undef if $from <= 0;
    return undef if $to - @{$self->{results}} >= $self->{results_per_page};
    my $keyword = url_encode( $self->{keyword} );
    return "$self->{script_url}?q=$keyword&l=$self->{logic}&from=$from&to=$to";
}

sub get_text
{
    my $self = shift;
    my $text = shift;
    my @words = @_;

    $text = $1 if $text =~ m{<BODY.*?>(.*?)</BODY>}six; # get body ...
    $text =~ s{<(SCRIPT|STYLE).*?>.*?</\1>}{}sixg; # remove style / script ...
    $text =~ s{<!--.*?-->}{}sixg; # remove comments
    $text =~ s/<.*?>//gs; # crudely strip HTML tags ...
    $text =~ s/&nbsp;/ /g;
    $text =~ s/\s+/ /g;

    my @match;
    my $max_text_length = 
        int( $self->{max_text_length} / scalar( @words ) / 2 )
    ;
    my $tot_length = 0;
    for my $word ( @words )
    {
        my ( $match ) = 
            $text =~
                m{
                    \b                          # word boundary
                    (
                        .{0,$max_text_length}   # up to max_text_length
                                                # characters (greedy)
                        $word                   # target word
                        .{0,$max_text_length}   # up to max_text_length
                                                # characters (greedy)
                    )
                    \b                          # word boundary
                }six
        ;
        next unless $match;
        $match =~ s{($word)}{<B>$1</B>}gsi;
        $tot_length += length( $match );
        push( @match, $match );
    }
    return join ( ' ... ', @match );
}

my %OPTIONS = (
    results_per_page    => 10,
    max_results         => 100,
    max_search_words    => 3,
    max_text_length     => 200,
    db_dir              => undef,
    stopword_file       => undef,
    template_file       => undef,
    urlroot             => undef,
    docroot             => undef,
    logfile             => undef,
    remote              => undef,
);

sub new
{
    my $class = shift;
    my %args = ( %OPTIONS, @_ );

    for ( keys %args )
    {
        die "Unknown option $_\n" unless exists( $OPTIONS{$_} );
    }

    my $self = bless \%args, $class;

    my %form_data = CGI_Lite->new->parse_form_data;

    $self->{script_url} = 
        "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}$ENV{SCRIPT_NAME}"
    ;
    $self->{results_per_page} = $form_data{rpp} || $self->{results_per_page};
    $self->{rounding_up_correction} = 1 - ( 1 / $self->{results_per_page} );
    $self->{max_results} = $form_data{m} || $self->{max_results};
    $self->{to} = $form_data{to} || $self->{results_per_page};
    $self->{from} = $form_data{from} || 1;
    $self->{first} = defined( $form_data{from} ) ? 0 : 1;
    $self->{keyword} = $form_data{q};
    my $q = lc( $self->{keyword} );
    $q =~ s/[^a-zA-Z0-9\s]//g;
    my @words = grep /\S/, split /\s/, $q;
    $#words = $self->{max_search_words}  - 1 
        if $#words > $self->{max_search_words} - 1
    ;
    $self->{words} = [ keys %{ { map { $_ => 1 } @words } } ]; # make unique
    $self->{logic} = $form_data{l} || 'and';

    die "logic must be OR or AND\n" unless $self->{logic} =~ /^(or|and)$/;
    die "no db_dir specified\n" unless defined $self->{db_dir};
    die "no template_file specified\n" unless defined $self->{template_file};
    die "no urlroot specified\n" unless defined $self->{urlroot};
    die "no docroot specified\n" unless defined $self->{docroot};

    if ( $self->{logfile} )
    {
        $self->{log_fh} = IO::File->new( ">>$self->{logfile}" )
            or die "can't open logfile $self->{logfile}"
        ;
    }
    return $self;
}

sub get_results
{
    my $self = shift;

    $self->{results} = [];
    return unless @{$self->{words}};

    my $indexer = HTML::Index->new( 
        DB_DIR          => $self->{db_dir},
        STOP_WORD_FILE  => $self->{stopword_file},
    );
    my @results = $indexer->search( 
        words => $self->{words},
        logic => uc( $self->{logic} ) 
    );
    @results = sort { -M $a->path <=> -M $b->path } @results;
    if ( @results > $self->{max_results} )
    {
        $#results = $self->{max_results} - 1;
        $self->{cropped} = 1;
    }
    if ( $self->{remote} )
    {
        for ( @results )
        {
            my $url = $_->path;
            $url =~ s/$self->{urlroot}/$self->{docroot}/;
            $_->path( $url );
        }
    }
    $self->{results} = [ @results ];
}

sub get_stats
{
    my $self = shift;

    my @words = @{$self->{words}};
    return '' unless @words;

    my $query = join( " $self->{logic} ", map { "\"$_\"" } @words ); 

    if ( @{$self->{results}} )
    {
        my $more_than = $self->{cropped} ? 'more than ' : '';
        my $stats = 
            "Your search for $query returned $more_than " .
            sprintf(
                # "%d results in %0.3f seconds",
                "%d results",
                scalar( @{$self->{results}} ), 
                $self->{dt} 
            )
        ;
        $stats .= '<BR>Enter more keywords to narrow your search' 
            if $self->{cropped}
        ;
        return $stats;
    }
    return "No pages matched your search for $query<br>Please try again";
}

sub log_search
{
    my $self = shift;

    return unless $self->{log_fh};
    return unless $self->{keyword};

    my $to = $self->{to};
    my $from = $self->{from};

    my $remote_addr = $ENV{REMOTE_ADDR};
    my $localtime = scalar(localtime);
    print { $self->{log_fh} } <<EOF;
$remote_addr "$localtime" "$self->{keyword}" $from-$to $self->{dt}
EOF
}

sub generate_template_params
{
    my $self = shift;

    my ( $continue, $results ) = ( [], [] );

    my @results = @{$self->{results}};
    my @words = @{$self->{words}};

    if ( @results )
    {
        my @page = @results[$self->{from}-1 .. $self->{to}-1];
        my $i = $self->{from};
        for my $result ( @page )
        {
            next unless defined $result;
            my $content = get_content( $result->path );
            my $title = get_title( $content );
            my $text = $self->get_text( $content, $result->words );
            ( my $url = $result->path ) =~ 
                s{$self->{docroot}}{$self->{urlroot}}
            ;
            push( @$results, {
                NO => $i++,
                TITLE => $title,
                URL => $url,
                TEXT => $text,
                DATE_STRING => time2str( 
                    "%R%p, %A %o %B %Y",
                    ( stat( $result->path ) )[9]
                ),
                KEYWORD => $words[0],
            } );
        }

        my $results_per_page = $self->{results_per_page};
        my $pages = 
            ( $#results / $results_per_page ) +
            $self->{rounding_up_correction}
        ;
        if ( $self->{max_results} > 0 and $#results > $results_per_page )
        {
            my $to = $self->{to};
            my $from = $self->{from};

            my $prev_url = $self->get_url( 
                $from-$results_per_page,
                $to-$results_per_page 
            );
            my $next_url = $self->get_url(
                $from+$results_per_page,
                $to+$results_per_page 
            );
            for ( my $p = 1; $p <= $pages;$p++ )
            {
                my $f = ( $p - 1 ) * $results_per_page + 1;
                my $t = $p * $results_per_page;
                $t = @results if $t >= @results;
                push( 
                    @{$continue}, 
                    { 
                        PREV_URL => $prev_url,
                        NEXT_URL => $next_url,
                        PAGE => $p, 
                        URL => $from eq $f ? '' : $self->get_url( $f, $t )
                    }
                );
            }
        }
    }
    return (
        FROM        => $self->{from},
        TO          => $self->{to},
        FIRST       => $self->{first},
        Q           => $self->{keyword},
        OR          => $self->{logic} eq 'or',
        AND         => $self->{logic} eq 'and',
        STATS       => $self->get_stats,
        CONTINUE    => $continue,
        RESULTS     => $results,
        ANY_RESULTS => @{$self->{results}} ? 1 : 0,
    );
}

sub search_results_page
{
    my $self = shift;

    my $t0 = gettimeofday;
    $self->get_results;
    $self->{dt} = gettimeofday - $t0;

    $self->log_search;

    my $template = HTML::Template->new( 
        filename => "$self->{template_file}",
        die_on_bad_params => 0,
        loop_context_vars => 1,
    );

    $template->param( $self->generate_template_params );
    return $template->output();
}

1;
__END__

=head1 NAME

HTML::Index::Search - perl module for generating a CGI search results page.

=head1 SYNOPSIS

    use HTML::Index;
    use HTML::Index::Search;

    my $indexer = HTML::Index->new(
        STOP_WORD_FILE      => $stopfile,
        HTML_DIRS           => [ '/path/to/htdocs' ],
        DB_DIR              => $db_dir,
    );

    $indexer->create_index();

    my $search = HTML::Index::Search->new(
            db_dir                  => $db_dir,
            stopword_file           => $stopword_file,
            template_file           => $template_file,
            results_per_page        => 10,
            max_results             => 100,
            docroot                 => '/path/to/htdocs',
            urlroot                 => 'http://my.site.com/',
            max_search_words        => 3,
            max_text_length         => 200,
            remote                  => 0,
            logfile                 => $logfile,
    );

    print $search->search_results_page();

=head1 DESCRIPTION

HTML::Indexer::Search is a module for generating a search results page for a
web searhch CGI. It is used in conjunction with an index created by
L<HTML::Index>. It uses an L<HTML::Template> template file to generate the
results page. A sample template file is included with this distribution.

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
