#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use t::Common qw [$count $test $failures];

use 5.010;

use Test::Regexp tests => 'no_plan';

sub is {
    my ($got, $expected, $name) = @_;
    if ((defined ($got) xor defined ($expected)) ||
        (defined ($got) && defined ($expected) && $got ne $expected)) {
        say "#      got: ", $got      // 'undef';
        say "# expected: ", $expected // 'undef';
        print "not ";
        $failures ++;
    }
    say "ok ", ++ $count, " - $name";
}

sub test_tests {
    my $Test = shift;
    undef $test;

    my @c_args;
       @c_args = (test => $Test) if defined $Test;

    undef $test;
    match subject  =>  "Foo",
          pattern  =>  qr {Foo},
          @c_args;
    is $test, $Test, " test with matching pattern";

    undef $test;
    match subject  =>  "Foo",
          pattern  =>  qr {Bar},
          @c_args;
    is $test, $Test, " test with non-matching pattern";
    
    undef $test;
    match subject       =>  "Foo",
          keep_pattern  =>  qr {(Foo)},
          captures      =>  ["Foo"],
          @c_args;
    is $test, $Test, " test with matching numbered pattern";
    
    undef $test;
    match subject       =>  "Foo",
          keep_pattern  =>  qr {(?<bar>Foo)},
          captures      =>  [[bar => "Foo"]],
          @c_args;
    is $test, $Test, " test with matching named pattern";
    
    undef $test;
    match subject       =>  "Foo",
          keep_pattern  =>  qr {(Bar)},
          captures      =>  ["Bar"],
          @c_args;
    is $test, $Test, " test with non-matching numbered pattern";
    
    undef $test;
    match subject       =>  "Foo",
          keep_pattern  =>  qr {(?<bar>Bar)},
          captures      =>  [[bar => "Bar"]],
          @c_args;
    is $test, $Test, " test with non-matching named pattern";

}


test_tests undef;
test_tests "";
test_tests "Baz";

__END__
