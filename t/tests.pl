@test_files = map { "eg/test$_.html" } ( 1 .. 4 );
@tests = (
    { q => 'some', paths => [ 'eg/test1.html', 'eg/test2.html' ] },
    { q => 'some OR stuff', paths => [ 'eg/test1.html', 'eg/test2.html', 'eg/test4.html' ] },
    { q => 'some stuff', paths => [ 'eg/test1.html', 'eg/test2.html' ] },
    { q => 'some AND stuff', paths => [ 'eg/test1.html', 'eg/test2.html' ] },
    { q => 'some and stuff', paths => [ 'eg/test1.html', 'eg/test2.html' ] },
    { q => 'some OR more', paths => [ 'eg/test1.html', 'eg/test2.html' ] },
    { q => 'some AND stuff AND NOT more', paths => [ 'eg/test1.html' ] },
    { q => 'some AND stuff AND NOT sample', paths => [ 'eg/test2.html' ] },
    { q => '( more AND stuff ) OR ( sample AND stuff )', paths => [ 'eg/test1.html', 'eg/test2.html', 'eg/test4.html' ] },
    { q => 'some AND more', paths => [ 'eg/test2.html' ] },
    { q => 'some AND sample AND stuff', paths => [ 'eg/test1.html' ] },
    { q => 'some AND NOT stuff', paths => [ ] },
    { q => 'hyphenated-word', paths => [ 'eg/test1.html' ] },
    { q => 'hyphenated AND word', paths => [ 'eg/test1.html' ] },
    { q => 'different', paths => [ 'eg/test3.html' ] },
    { q => 'invisible', paths => [ ] },
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

sub do_search_test
{
    my $searcher = shift;
    my $test = shift;
    my $use_soundex = shift;

    $i++;
    eval {
        my @r = $searcher->search( $test->{q}, SOUNDEX => $use_soundex );
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
