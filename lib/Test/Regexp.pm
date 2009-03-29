package Test::Regexp;

use 5.010;

use strict;
use warnings;
no  warnings 'syntax';

use Exporter ();
use Test::Builder;

our @EXPORT = qw [match no_match];
our @ISA    = qw [Exporter Test::More];

our $VERSION = '0.01';

BEGIN {
    binmode STDOUT, ":utf8";
}

my $Test = Test::Builder -> new;

sub import {
    my $self = shift;
    my $pkg  = caller;

    my %arg  = @_;

    $Test -> exported_to ($pkg);

    $arg {import} //= [qw [match no_match]];

    while (my ($key, $value) = each %arg) {
        given ($key) {
            when ("tests") {
                $Test -> plan ($value);
            }
            when ("import") {
                $self -> export_to_level (1, $self, $_) for @{$value || []};
            }
            default {
                die "Unknown option '$key'\n";
            }
        }
    }
}


my $__ = "    ";

sub escape {
    my $str = shift;
    $str =~ s/\n/\\n/g;
    $str =~ s/\t/\\t/g;
    $str =~ s/\r/\\r/g;
    $str =~ s/([^\x20-\x7E])/sprintf "\\x{%02X}" => ord $1/eg;
    $str;
}

sub pretty {
    my $str = shift;
    my %arg = @_;
    substr ($str, 50, -5, "...") if length $str > 55 && !$arg {full_text};
    $str = escape $str;
    $str;
}


sub mess {
    my $val = shift;
    defined $val ? 'eq "' . pretty ($val) . '"' : 'undefined';
}


sub todo {
    my %arg       =  @_;
    my $subject   =  $arg {subject};
    my $comment   =  $arg {comment};
    my $upgrade   =  $arg {upgrade};
    my $downgrade =  $arg {downgrade};
    my $neg       =  $arg {match} ? "" : "not ";

    my $line      = "";

    if ($arg {show_line}) {
        no warnings 'once';
        my ($file, $l_nr)  = (caller ($Test::Builder::deepness // 1)) [1, 2];
        $line = " [$file:$l_nr]";
    }

    my $subject_pretty = pretty $subject;
    my $Comment        = qq {qq {$subject_pretty}};
       $Comment       .= qq { ${neg}matched by "$comment"$line};

    my @todo = [$subject, $Comment];

    #
    # If the subject isn't already UTF-8, and there are characters in
    # the range "\x{80}" .. "\x{FF}", we do the test a second time,
    # with the subject upgraded to UTF-8.
    #
    # Otherwise, if the subject is in UTF-8 format, and there are *no*
    # characters with code point > 0xFF, but with characters in the 
    # range 0x80 .. 0xFF, we downgrade and test again.
    #
    if ($upgrade && ($upgrade == 2 ||    !utf8::is_utf8 ($subject) 
                                      && $subject =~ /[\x80-\xFF]/)) {
        my $subject_utf8 = $subject;
        if (utf8::upgrade ($subject_utf8)) {
            my $Comment_utf8   = qq {qq {$subject_pretty}};
               $Comment_utf8  .= qq { [UTF-8]};
               $Comment_utf8  .= qq { ${neg}matched by "$comment"$line};

            push @todo => [$subject_utf8, $Comment_utf8];
        }
    }
    elsif ($downgrade && ($downgrade == 2 ||     utf8::is_utf8 ($subject)
                                             && $subject =~ /[\x80-\xFF]/
                                             && $subject !~ /[^\x00-\xFF]/)) {
        my $subject_non_utf8 = $subject;
        if (utf8::downgrade ($subject_non_utf8)) {
            my $Comment_non_utf8  = qq {qq {$subject_pretty}};
               $Comment_non_utf8 .= qq { [non-UTF-8]};
               $Comment_non_utf8 .= qq { ${neg}matched by "$comment"$line};

            push @todo => [$subject_non_utf8, $Comment_non_utf8];
        }
    }

    @todo;
}
    


#
# Arguments:
#   name:         'Name' of the pattern.
#   pattern:       Pattern to be tested, without captures.
#   keep_pattern:  Pattern to be tested, with captures.
#   subject:       String to match.
#   captures:      Array of captures; elements are either strings
#                  (match for the corresponding numbered capture),
#                  or an array, where the first element is the name
#                  of the capture and the second its value.
#   comment:       Comment to use, default to name or "".
#   utf8_upgrade:  If set, upgrade the string if applicable. Defaults to 1.
#   utf8_downgrade If set, downgrade the string if applicable. Defaults to 1.
#   match          If true, pattern(s) should match, otherwise, should fail
#                  to match. Defaults to 1.
#   reason         The reason a match should fail.
#   show_line      Show file name/line number of call to 'match'.
#
#   style          If set, do some additional mangling, depending on
#                  the value. Currently only recognized value is Regexp::Common
#

sub match {
    my %arg            = @_;

    my $name           = $arg {name};
    my $pattern        = $arg {pattern};
    my $keep_pattern   = $arg {keep_pattern};
    my $subject        = $arg {subject};
    my $captures       = $arg {captures}       // [];
    my $comment        = escape $arg {comment} // $name // "";
    my $upgrade        = $arg {utf8_upgrade}   // 1;
    my $downgrade      = $arg {utf8_downgrade} // 1;
    my $match          = $arg {match}          // 1;
    my $reason         = defined $arg {reason}
                                       ? " [Reason: " . $arg {reason} . "]"
                                       : "";
    my $show_line      = $arg {show_line};
    my $style          = $arg {style} // "";

    $show_line       //= 1 if $style eq 'Regexp::Common';

    my $aa_captures;
    my $hh_captures;

    #
    # First split the captures into a hash and an array so we can
    # check both $1 and friends, and %-.
    #
    foreach my $capture (@$captures) {
        if (ref $capture eq 'ARRAY') {
            my ($name, $match) = @$capture;
            push @$aa_captures => $match;
            if ($name =~ /^[a-zA-Z0-9_]+$/) {
                push @{$$hh_captures {$name}} => $match;
            }
        }
        else {
            push @$aa_captures => $capture;
        }
    }
    
    my @aa_captures = @{$aa_captures || []};
    my %hh_captures = %{$hh_captures || {}};

    given ($arg {style}) {
        when ("Regexp::Common") {
            my $Name            =  $name;
               $Name            =~ s/[^a-zA-Z0-9_]+/_/g;
            my %hh;
            $hh {"${Name}"}     =  [$subject];
            $hh {"${Name}__$_"} =  $hh_captures {$_}
                                    for keys %hh_captures;
            %hh_captures = %hh;

            my @aa = ($subject,
                      map {ref $_ ? ["${Name}__" . $$_ [0], $$_ [1]]
                                  : $_}
                      @aa_captures);
            @aa_captures = @aa;
        }
    }

    my @todo = todo subject   => $subject,
                    comment   => $comment,
                    upgrade   => $upgrade,
                    downgrade => $downgrade,
                    match     => $match,
                    show_line => $show_line;

    #
    # Now we will do the tests.
    #
    foreach my $todo (@todo) {
        my $subject = $$todo [0];
        my $comment = $$todo [1];

        if ($match && defined $pattern) {
            #
            # Test match; match should also be complete, and not
            # have any captures.
            #
            SKIP: {
                my $result = $subject =~ /^$pattern/;
                unless ($Test -> ok ($result, $comment)) {
                    $Test -> skip ("Match failed") for 1 .. 2;
                    last SKIP;
                }
                $Test -> is_eq ($&, $subject, "${__}match is complete");
                $Test -> ok (@- == 1 && keys %- == 0, "${__}no captures");
            }
        }
        if ($match && defined $keep_pattern) {
            #
            # Test keep. Should match, and the parts as well.
            #
            # Total number of tests:
            #   - 1 for match.
            #   - 1 for match complete.
            #   - 1 for each named capture.
            #   - 1 for each capture name.
            #   - 1 for number of different capture names.
            #   - 1 for each capture.
            #   - 1 for number of captures.
            # So, if you only have named captures, and all the names
            # are different, you have 4 + 3 * N tests.
            # If you only have numbered captures, you have 4 + N tests.
            #
            SKIP: {
                my $skips  = 1 + @aa_captures;
                   $skips += @{$_} for values %hh_captures;

                my ($amp, @numbered_matches, %minus);

                my $result = $subject =~ /^$keep_pattern/;
                unless ($Test -> ok ($result, "$comment (with -Keep)")) {
                    $Test -> skip ("Match failed") for 1 .. $skips;
                    last SKIP;
                }
                #
                # Copy $&, $N and %- before doing anything that
                # migh override them.
                #

                $amp = $&;

                #
                # Grab numbered captures.
                #
                for (my $i = 1; $i < @-; $i ++) {
                    no strict 'refs';
                    push @numbered_matches => $$i;
                }

                #
                # Copy %-;
                #
                while (my ($key, $value) = each %-) {
                    $minus {$key} = [@$value];
                }

                #
                # Test to see if match is complete.
                #
                $Test -> is_eq ($amp, $subject, "${__}match is complete");

                #
                # Test named captures.
                #
                while (my ($key, $value) = each %hh_captures) {
                    for (my $i = 0; $i < @$value; $i ++) {
                        $Test -> is_eq ($minus {$key} [$i], $$value [$i],
                           "${__}\$- {$key} [$i] " . mess $$value [$i]);
                    }
                    $Test -> is_num (scalar @{$minus {$key}}, scalar @$value, 
                           "${__} capture '$key' has " . @$value .
                           " matches");
                }
                #
                # Test for the right number of captures.
                #
                $Test -> is_num (scalar keys %minus, scalar keys %hh_captures,
                   $__ . scalar (keys %hh_captures)
                       . " named capture groups");


                #
                # Test numbered captures.
                #
                for (my $i = 0; $i < @aa_captures; $i ++) {
                    $Test -> is_eq ($numbered_matches [$i], $aa_captures [$i],
                       "${__}\$" . ($i + 1) . " " . mess $aa_captures [$i]);
                }
                $Test -> is_num (scalar @numbered_matches, scalar @aa_captures,
                   $__ . @aa_captures . " numbered captured groups");
            }
        }

        if (!$match && defined $pattern) {
            my $r = $subject =~ /^$pattern/;
            $Test -> ok (!$r || $subject ne $&, "$comment$reason");
        }
        if (!$match && defined $keep_pattern) {
            my $r = $subject =~ /^$keep_pattern/;
            $Test -> ok (!$r || $subject ne $&, "$comment (with -Keep)$reason");
        }
    }
}

sub no_match {
    push @_ => match => 0;
    goto &match;
}


1;

__END__

=pod

=head1 NAME 

Test::Regexp - Test your regular expressions

=head1 SYNOPSIS

 use Test::Regexp 'no_plan';

 match    subject      => "Foo",
          pattern      => qr /\w+/;

 match    subject      => "Foo bar",
          keep_pattern => qr /(?<first_word>\w+)\s+(\w+)/,
          captures     => [[first_word => 'Foo'], ['bar']];

 no_match subject      => "Baz",
          pattern      => qr /Quux/;

=head1 DESCRIPTION

This module is intended to test your regular expressions. Given a subject
string and a regular expression (aka pattern), the module not only tests
whether the regular expression complete matches the subject string, it
performs a C<< utf8::upgrade >> or C<< utf8::downgrade >> on the subject
string and performs the tests again, if necessary. Furthermore, given a
pattern with capturing parenthesis, it checks whether all captures are
present, and in the right order. Both named and unnamed captures are checked.

By default, the module exports two subroutines, C<< match >> and
C<< no_match >>. The latter is actually a thin wrapper around C<< match >>,
calling it with C<< match => 0 >>.

=head2 "Complete matching"

A match is only considered to succesfully match if the entire string
is matched - that is, if C<< $& >> matches the subject string. So:

  Subject    Pattern

  "aaabb"    qr /a+b+/     # Considered ok
  "aaabb"    qr /a+/       # Not considered ok

For efficiency reasons, when the matching is performed the pattern
is actually anchored at the start. It's not anchored at the end as
that would potentially influence the matching.

=head2 UTF8 matching

Certain regular expression constructs match differently depending on 
whether UTF8 matching is in effect or not. This is only relevant 
if the subject string has characters with code points between 128 and
255, and no characters above 255 -- in such a case, matching may be
different depending on whether the subject string has the UTF8 flag
on or not. C<< Test::Regexp >> detects such a case, and will then 
run the tests twice; once with the subject string C<< utf8::downgraded >>,
and once with the subject string C<< utf8::upgraded >>.

=head2 Number of tests

There's no fixed number of tests that is run. The number of tests
depends on the number of captures, the number of different names of
captures, and whether there is the need to up- or downgrade the 
subject string.

It is therefore recommended to use C<< use Text::Regexp 'no_plan'; >>.
In a later version, C<< Test::Regexp >> will use a version of 
C<< Test::Builder >> that allows for nested tests.


