#!/usr/bin/perl

use strict;
use warnings;

our $VERSION = "2009033101";

use Test::More 'no_plan';

BEGIN {
    use_ok 'Test::Regexp', import => [];
}


ok !defined &match;
ok !defined &no_match;


__END__
