#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use t::Common qw [$count $comment $failures];

use 5.010;

our $VERSION = 1.000;

use Test::Regexp tests => 'no_plan';

sub is {
    my ($got, $expected, $name) = @_;
    if ((defined ($got) xor defined ($expected)) ||
        ($got ne $expected)) {
        say "#      got: ", $got      // 'undef';
        say "# expected: ", $expected // 'undef';
        print "not ";
        $failures ++;
    }
    say "ok ", ++ $count, " - $name";
}

sub comment_tests {
    my $Comment = shift;
    undef $comment;

    my @c_args;
       @c_args = (comment => $Comment) if defined $Comment;

    undef $comment;
    match subject  =>  "Foo",
          pattern  =>  qr {Foo},
          @c_args;
    is $comment, $Comment // "", " comment with matching pattern";
    
    undef $comment;
    match subject  =>  "Foo",
          pattern  =>  qr {Bar},
          @c_args;
    is $comment, $Comment // "", " comment with non-matching pattern";
    
    undef $comment;
    match subject       =>  "Foo",
          keep_pattern  =>  qr {(Foo)},
          captures      =>  ["Foo"],
          @c_args;
    is $comment, $Comment // "", " comment with matching numbered pattern";
    
    undef $comment;
    match subject       =>  "Foo",
          keep_pattern  =>  qr {(?<bar>Foo)},
          captures      =>  [[bar => "Foo"]],
          @c_args;
    is $comment, $Comment // "", " comment with matching named pattern";
    
    undef $comment;
    match subject       =>  "Foo",
          keep_pattern  =>  qr {(Bar)},
          captures      =>  ["Bar"],
          @c_args;
    is $comment, $Comment // "", " comment with non-matching numbered pattern";
    
    undef $comment;
    match subject       =>  "Foo",
          keep_pattern  =>  qr {(?<bar>Bar)},
          captures      =>  [[bar => "Bar"]],
          @c_args;
    is $comment, $Comment // "", " comment with non-matching named pattern";
}


comment_tests undef;
comment_tests "";
comment_tests "Baz";

__END__
