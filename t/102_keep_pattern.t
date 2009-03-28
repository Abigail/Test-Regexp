#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use 5.010;

our $VERSION = 1.000;

my $failures = 0;

#
# This end block should preceed the use of Test::Regexp.
#
END {
    Test::Builder::_my_exit ($failures > 254 ? 254 : $failures)
};

use Test::Regexp 'no_plan';

sub init_data;

my $result = "";
my $count  = 0;
my @data   = init_data;

END {say "1..$count"}

BEGIN {
    no strict 'refs';
    no warnings 'redefine';
    #
    # Intercept the 'ok' and 'not ok' prints, and remember the results.
    #
    *{"Test::Builder::_print"} = sub {
        my ($self, @msgs) = @_;
        my $mesg = join "" => @msgs;
        print "## $mesg";
        given ($mesg) {
            when (/^ok/)     {$result .= "P"}
            when (/^not ok/) {$result .= "F"}
        }
    };
    #
    # Mark diagnostics.
    #
    *{"Test::Builder::_print_diag"} = sub {
        my ($self, @msgs) = @_;
        my $mesg = join "" => @msgs;
        $mesg =~ s/^/   /mg;
        $mesg =~ s/^  /##/;
        print $mesg;
        1;
    }
}

my ($subject, $pattern, $match_val);
sub check {
    my $expected = shift;
    my $tag      = "ok ";
    my $exp_pat  = $expected;
       $exp_pat  =~ s/S/P/g;
    if ($result !~ /^$exp_pat$/) {
        say "# Got '$result'";
        say "# Expected '$expected'";
        $tag = "not $tag";
        $failures ++;
    }
    my $op = $match_val ? "=~" : "!~";
    say $tag, ++ $count, qq { "$subject" $op /$pattern/};
    $result = "";
    return;
}

foreach my $data (@data) {
    ($subject, $pattern, my ($match, $result, $captures)) = @$data;

    $match_val = $match =~ /[ym1]/i;
    match subject       =>  $subject,
          keep_pattern  =>  $pattern,
          match         =>  $match_val,
          captures      =>  $captures;
    check $result;
}

#
# Data taken from 'meta state_flowers'
#

sub init_data {(
    # Match without captures.
    ['Rose',              qr {\w+},                    'y', 'PPPP', []],

    # Match with just numbered captures.
    ['Black Eyed Susan',  qr {(\w+)\s+(\w+)\s+(\w+)},  'y', 'PPPPPPP',
      [qw [Black Eyed Susan]]],

    # Match with just named captures.
    ['Sego Lily',         qr {(?<a>\w+)\s+(?<b>\w+)},  'y', 'PPPPPPPPPP',
      [[a => 'Sego'], [b => 'Lily']]],

    # Mix named and numbered captures.
    ['California Poppy',  qr {(?<state>\w+)\s+(\w+)},  'y', 'PPPPPPPP',
      [[state => 'California'], 'Poppy']],

    # Repeat named capture.
    ['Indian Paintbrush', qr {(?<s>\w+)\s+(?<s>\w+)},  'y', 'PPPPPPPPP',
      [[s => 'Indian'], [s => 'Paintbrush']]],

    #
    # Failures.
    #

    # No captures, but a result.
    ['Violet',            qr {\w+},                    'y', 'PPPFF',
      ['Violet']],

    # Capture, no result.
    ['Mayflower',         qr {(\w+)},                  'y', 'PPPF', []],

    # Capture, wrong result.
    ['Magnolia',          qr {(\w+)},                  'y', 'PPPFP',
      ['Violet']],

    # Named capture, numbered results.
    ['Hawaiian Hibiscus', qr {(?<a>\w+)\s+(?<b>\w+)},  'y', 'PPFPPP',
      [qw [Hawaiian Hibiscus]]],

    # Numbered capture, named results.
    ['Cherokee Rose',     qr {(\w+)\s+(\w+)},          'y', 'PPFFFFPPPP',
      [[a => 'Cherokee'], [b => 'Rose']]],

    # Wrong capture names.
    ['American Dogwood',  qr {(?<a>\w+)\s+(?<b>\w+)},  'y', 'PPFPFPPPPP',
      [[b => 'American'], [a => 'Dogwood']]],

    # Wrong order of captures.
    ['Mountain Laurel',   qr {(?<a>\w+)\s+(?<b>\w+)},  'y', 'PPPPPPPFFP',
      [[b => 'Laurel'], [a => 'Mountain']]],

    # Wrong order of captures - same name
    ['Yucca Flower',      qr {(?<a>\w+)\s+(?<a>\w+)},  'y', 'PPFFPPFFP',
      [[a => 'Flower'], [a => 'Yucca']]],

    # Too many numbered captures.
    ['Sagebrush',         qr {(\w+)},                  'y', 'PPPPFF',
      [qw [Sagebrush Violet]]],

    # Too many named captures.
    ['Apple Blossom',     qr {(?<a>\w+)\s+(?<a>\w+)},  'y', 'PPPPFFPPPFF',
      [[a => 'Apple'], [a => 'Blossom'], [a => 'Violet']]],

    # Not enough named captures.
    ['Wood Violet',       qr {(?<a>\w+)\s+(?<a>\w+)},  'y', 'PPPFPPF',
      [[a => 'Wood']]],
)}


__END__
