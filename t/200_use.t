#!/usr/bin/perl

use strict;
use warnings;

our $VERSION = "2009033101";

use Test::More 'no_plan';

BEGIN {
    use_ok 'Test::Regexp';
}


my $obj1 = Test::Regexp         -> new;
my $obj2 = Test::Regexp         -> new -> init;
my $obj3 = Test::Regexp::Object -> new;
my $obj4 = Test::Regexp::Object -> new -> init;

isa_ok $obj1, 'Test::Regexp::Object';
isa_ok $obj2, 'Test::Regexp::Object';
isa_ok $obj3, 'Test::Regexp::Object';
isa_ok $obj4, 'Test::Regexp::Object';


__END__
