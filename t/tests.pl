@test_files = qw( eg/test1.html eg/test2.html eg/test3.html );
@tests = (
    { q => 'some', paths => [ 'eg/test1.html', 'eg/test2.html' ] },
    { q => 'some OR stuff', paths => [ 'eg/test1.html', 'eg/test2.html' ] },
    { q => 'some stuff', paths => [ 'eg/test1.html', 'eg/test2.html' ] },
    { q => 'some AND stuff', paths => [ 'eg/test1.html', 'eg/test2.html' ] },
    { q => 'some OR more', paths => [ 'eg/test1.html', 'eg/test2.html' ] },
    { q => 'some AND stuff AND NOT more', paths => [ 'eg/test1.html' ] },
    { q => 'some AND stuff AND NOT sample', paths => [ 'eg/test2.html' ] },
    { q => '( more AND stuff ) OR ( sample AND stuff )', paths => [ 'eg/test1.html', 'eg/test2.html' ] },
    { q => 'some AND more', paths => [ 'eg/test2.html' ] },
    { q => 'some AND NOT stuff', paths => [ ] },
    { q => 'different', paths => [ 'eg/test3.html' ] },
);

sub compare_arrays
{
    my $a1 = shift;
    my $a2 = shift;
    warn "(@$a1) and (@$a2) are different sizes\n" and return 0 
        unless @$a1 == @$a2
    ;
    my %h1 = map { $_ => 1 } @$a1;
    for ( @$a2 )
    {
        warn "$_ not in @$a1\n" and return 0 unless $h1{$_};
    }
    my %h2 = map { $_ => 1 } @$a2;
    for ( @$a1 )
    {
        warn "$_ not in @$a2\n" and return 0 unless $h2{$_};
    }
    return 1;
}

my $i = 0;

sub do_search_test( $$ )
{
    my $searcher = shift;
    my $test = shift;

    $i++;
    eval {
        my @r = $searcher->search( $test->{q} );
        unless ( compare_arrays( \@r, $test->{paths} ) )
        {
            die "$test->{q}\n";
        }
    };
    if ( $@ )
    {
        warn "test no. $i failed: $@\n";
        print "not ok $i\n";
    }
    else
    {
        print "ok $i\n";
    }
}

1;
