#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use t::Common;

use 5.010;

our $VERSION = "2009033101";

use Test::Regexp tests => 'no_plan';

sub init_data;

my @data   = init_data;


foreach my $data (@data) {
    my ($subject, $pattern, $match, $expected_l, $captures) = @$data;

    for my $updown (qw [up down]) {
        my $subject2 = $subject;
        if ($updown eq "up") {
            utf8::upgrade   ($subject2);
        }
        else {
            utf8::downgrade ($subject2);
        }

        foreach my $args ([], [utf8_upgrade => 0], [utf8_downgrade => 0]) {
            my $match_val = $match =~ /[ym1]/i;
            match subject       =>  $subject2,
                  keep_pattern  =>  $pattern,
                  match         =>  $match_val,
                  show_line     =>   1,
                  captures      =>  $captures,
                  @$args,
            ;
    
            my $expected = shift @$expected_l;
            check ($expected, $subject, $match_val, $pattern);
        }
    }
}


sub init_data {(
    # Match without captures.
    ["F\x{f8}o",  qr /[\x20-\xFF]+/, 'y',
      ['PPPPPPPP', 'PPPPPPPP', 'PPPP', 'PPPPPPPP', 'PPPP', 'PPPPPPPP'],
      []],

    # Match without captures.
    ["F\x{f8}o",  qr /\w+/, 'y',
      ['PPPPPFPP', 'PPPPPFPP', 'PPPP', 'PFPPPPPP', 'PFPP', 'PFPPPPPP'],
      []],
)}

__END__
