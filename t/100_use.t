#!/usr/bin/perl

use strict;
use warnings;

our $VERSION = 1.000;

use Test::More 'no_plan';

BEGIN {
    use_ok 'Test::Regexp';
}


ok defined &match;
ok defined &no_match;


__END__
