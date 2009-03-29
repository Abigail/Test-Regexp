#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use t::Common qw [$count $line $failures];

use 5.010;

our $VERSION = "2009033101";

use Test::Regexp tests => 'no_plan';

sub ok {
    my ($success, $name) = @_;
    unless ($success) {
        print "not ";
        $failures ++;
    }
    say "ok ", ++ $count, " - $name";
}

sub do_tests {
    foreach my $show (0, 1) {
        undef $line;
#line 999 160_show_line
        match subject   =>  "Foo",
              pattern   =>  qr {Foo},
              show_line =>  $show;
        if ($show) {
            ok !!(defined $line && $line eq '160_show_line:999'),
               "show_line => 1";
        }
        else {
            ok !defined $line, "show_line => 0";
        }
    }
}


do_tests;

__END__
