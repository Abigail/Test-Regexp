#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use t::Common qw [$count $reason $failures];

use 5.010;

our $VERSION = "2009033101";

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

sub reason_tests {
    my $Reason = shift;
    undef $reason;

    my @c_args;
       @c_args = (reason => $Reason) if defined $Reason;

    undef $reason;
    match subject  =>  "Foo",
          pattern  =>  qr {Foo},
          match    =>   0,
          @c_args;
    is $reason, $Reason, " reason with non-matching pattern";

    undef $reason;
    match subject  =>  "Foo",
          pattern  =>  qr {Bar},
          match    =>   0,
          @c_args;
    is $reason, $Reason, " reason with non-matching pattern";
    
    undef $reason;
    match subject       =>  "Foo",
          keep_pattern  =>  qr {(Foo)},
          captures      =>  ["Foo"],
          match         =>   0,
          @c_args;
    is $reason, $Reason, " reason with matching numbered pattern";
    
    undef $reason;
    match subject       =>  "Foo",
          keep_pattern  =>  qr {(?<bar>Foo)},
          captures      =>  [[bar => "Foo"]],
          match         =>   0,
          @c_args;
    is $reason, $Reason, " reason with matching named pattern";
    
    undef $reason;
    match subject       =>  "Foo",
          keep_pattern  =>  qr {(Bar)},
          captures      =>  ["Bar"],
          match         =>   0,
          @c_args;
    is $reason, $Reason, " reason with non-matching numbered pattern";
    
    undef $reason;
    match subject       =>  "Foo",
          keep_pattern  =>  qr {(?<bar>Bar)},
          captures      =>  [[bar => "Bar"]],
          match         =>   0,
          @c_args;
    is $reason, $Reason, " reason with non-matching named pattern";

}


reason_tests undef;
reason_tests "";
reason_tests "Baz";

__END__
