package HTML::Index::Search::CGI;

use strict;
use warnings;

use Time::HiRes qw(gettimeofday);
use HTML::Template;
use Date::Format;
use HTML::Index::Search;
use HTML::Entities;

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
    return undef if $to - @{$self->{RESULTS}} >= $self->{RESULTS_PER_PAGE};
    my $q = $self->{q};
    $q =~ s/(.)/'%' . sprintf('%lx',ord($1))/eg;
    return "?q=$q&FROM=$from&TO=$to";
}

sub get_text
{
    my $self = shift;
    my $text = shift;

    my @words = $self->{SEARCH}->get_words;
    return '' unless @words;

    $text = $1 if $text =~ m{<BODY.*?>(.*?)</BODY>}six; # get body ...
    $text =~ s{<(SCRIPT|STYLE).*?>.*?</\1>}{}sixg; # remove style / script ...
    $text =~ s{<!--.*?-->}{}sixg; # remove comments
    $text =~ s/<.*?>//gs; # crudely strip HTML tags ...
    $text =~ s/&nbsp;/ /g;
    $text =~ s/\s+/ /g;

    my @match;
    my $max_text_length = 
        int( $self->{MAX_TEXT_LENGTH} / scalar( @words ) / 2 )
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
                        \b
                        $word                   # target word
                        \b
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
    TO                  => undef,
    FROM                => undef,
    q                   => undef,
    RESULTS_PER_PAGE    => 10,
    MAX_RESULTS         => 100,
    MAX_TEXT_LENGTH     => 200,
    SEARCH              => undef,
    TEMPLATE_FILE       => undef,
    URLROOT             => '',
    DOCROOT             => '',
    LOGFILE             => undef,
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

    $self->{RESULTS_PER_PAGE} = $self->{RESULTS_PER_PAGE};
    $self->{ROUNDING_UP_CORRECTION} = 1 - ( 1 / $self->{RESULTS_PER_PAGE} );
    $self->{MAX_RESULTS} = $self->{MAX_RESULTS};
    $self->{TO} ||= $self->{RESULTS_PER_PAGE};
    $self->{FIRST} = $self->{FROM} ? 0 : 1;
    $self->{FROM} ||= 1;

    die "no template_file specified\n" unless defined $self->{TEMPLATE_FILE};
    die "no index search object\n" unless defined $self->{SEARCH};

    if ( $self->{LOGFILE} )
    {
        $self->{LOG_FH} = IO::FIle->new( ">>$self->{LOGFILE}" )
            or die "can't open logfile $self->{LOGFILE}"
        ;
    }
    return $self;
}

sub get_results
{
    my $self = shift;

    $self->{RESULTS} = [];
    my @results = ();
    if ( defined( $self->{q} ) and length( $self->{q} ) )
    {
        @results = 
            sort { -M $a <=> -M $b } $self->{SEARCH}->search( $self->{q} )
        ;
    }
    if ( @results > $self->{MAX_RESULTS} )
    {
        $#results = $self->{MAX_RESULTS} - 1;
        $self->{CROPPED} = 1;
    }
    $self->{RESULTS} = [ @results ];
}

sub get_stats
{
    my $self = shift;

    if ( @{$self->{RESULTS}} )
    {
        my $more_than = $self->{CROPPED} ? 'more than ' : '';
        my $stats = 
            "Your search for $self->{q} returned $more_than " .
            sprintf(
                # "%d results in %0.3f seconds",
                "%d results",
                scalar( @{$self->{RESULTS}} ), 
                $self->{DT} 
            )
        ;
        $stats .= '<BR>Enter more keywords to narrow your search' 
            if $self->{CROPPED}
        ;
        return $stats;
    }
    return "No pages matched your search for $self->{q}<br>Please try again";
}

sub log_search
{
    my $self = shift;

    return unless $self->{LOG_FH};
    return unless $self->{q};

    my $to = $self->{TO};
    my $from = $self->{FROM};

    my $remote_addr = $ENV{REMOTE_ADDR};
    my $localtime = scalar(localtime);
    print { $self->{LOG_FH} } <<EOF;
$remote_addr "$localtime" "$self->{q}" $from-$to $self->{DT}
EOF
}

sub generate_template_params
{
    my $self = shift;

    my ( $continue, $results ) = ( [], [] );

    my @results = @{$self->{RESULTS}};

    if ( @results )
    {
        my @page = @results[$self->{FROM}-1 .. $self->{TO}-1];
        my $i = $self->{FROM};
        for my $result ( @page )
        {
            next unless defined $result;
            my $content = get_content( $result );
            my $title = get_title( $content );
            my $text = $self->get_text( $content );
            ( my $url = $result ) =~ 
                s{$self->{DOCROOT}}{$self->{URLROOT}}
            ;
            push( @$results, {
                NO => $i++,
                TITLE => $title,
                URL => $url,
                TEXT => $text,
                DATE_STRING => time2str( 
                    "%R%p, %A %o %B %Y",
                    ( stat( $result ) )[9]
                ),
                Q => $self->{q}
            } );
        }

        my $results_per_page = $self->{RESULTS_PER_PAGE};
        my $pages = 
            ( $#results / $results_per_page ) +
            $self->{ROUNDING_UP_CORRECTION}
        ;
        if ( $self->{MAX_RESULTS} > 0 and $#results > $results_per_page )
        {
            my $to = $self->{TO};
            my $from = $self->{FROM};

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
        FROM        => $self->{FROM},
        TO          => $self->{TO},
        FIRST       => $self->{FIRST},
        Q           => encode_entities( $self->{q} ),
        STATS       => $self->get_stats,
        CONTINUE    => $continue,
        RESULTS     => $results,
        ANY_RESULTS => @{$self->{RESULTS}} ? 1 : 0,
    );
}

sub search_results_page
{
    my $self = shift;

    my $t0 = gettimeofday;
    $self->get_results;
    $self->{DT} = gettimeofday - $t0;

    $self->log_search;

    my $template = HTML::Template->new( 
        filename => "$self->{TEMPLATE_FILE}",
        die_on_bad_params => 0,
        loop_context_vars => 1,
    );

    $template->param( $self->generate_template_params );
    return $template->output();
}

1;
__END__

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
