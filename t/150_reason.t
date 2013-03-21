#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use 5.010;

use Test::Tester;
use Test::Regexp;
use t::Common;

my $match_res;

foreach my $reason (undef, "", 0, "Bla bla bla") {
    foreach my $name ("", "Baz", "Qux Quux") {
        my ($premature, @results) = run_tests sub {
            $match_res = match subject => "Foo",
                               pattern => qr {Bar},
                               match   => 0,
                               reason  => $reason,
                               name    => $name,
        };

        check results   => \@results,
              premature => $premature,
              expected  => 'P',
              match     => 0,
              match_res => $match_res,
              pattern   => 'Bar',
              subject   => "Foo",
              comment   => $name,
              keep      => 0,
              reason    => $reason,
        ;
    }
}


__END__
