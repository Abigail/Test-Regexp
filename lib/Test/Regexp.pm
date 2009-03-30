package Test::Regexp;

use 5.010;

use strict;
use warnings;
no  warnings 'syntax';

use Exporter ();
use Test::Builder;

our @EXPORT  = qw [match no_match];
our @ISA     = qw [Exporter Test::More];

our $VERSION = '2009033101';

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
#   comment:       Comment to use, defaults to name or "".
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

    my $pass           = 1;

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
    
    $aa_captures ||= [];
    $hh_captures ||= {};

    given ($arg {style}) {
        when ("Regexp::Common") {
            my $Name            =  $name;
               $Name            =~ s/[^a-zA-Z0-9_]+/_/g;
            my %hh;
            $hh {"${Name}"}     =  [$subject];
            $hh {"${Name}__$_"} =  $$hh_captures {$_}
                                     for keys %$hh_captures;
            $hh_captures = \%hh;

            my @aa = ($subject,
                      map {ref $_ ? ["${Name}__" . $$_ [0], $$_ [1]]
                                  : $_}
                      @$aa_captures);
            $aa_captures = \@aa;
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
                    $pass = 0;
                    last SKIP;
                }
                $pass = 0 unless
                    $Test -> is_eq ($&, $subject, "${__}match is complete");
                $pass = 0 unless
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
                my $skips  = 1 + @$aa_captures;
                   $skips += @{$_} for values %$hh_captures;

                my ($amp, @numbered_matches, %minus);

                my $result = $subject =~ /^$keep_pattern/;
                unless ($Test -> ok ($result, "$comment (with -Keep)")) {
                    $Test -> skip ("Match failed") for 1 .. $skips;
                    $pass = 0;
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
                $pass = 0 unless
                    $Test -> is_eq ($amp, $subject, "${__}match is complete");

                #
                # Test named captures.
                #
                while (my ($key, $value) = each %$hh_captures) {
                    for (my $i = 0; $i < @$value; $i ++) {
                        $pass = 0 unless
                            $Test -> is_eq ($minus {$key} [$i], $$value [$i],
                               "${__}\$- {$key} [$i] " . mess $$value [$i]);
                    }
                    $pass = 0 unless
                        $Test -> is_num (scalar @{$minus {$key}},
                                 scalar @$value, "${__} capture '$key' has " .
                                 @$value . " matches");
                }
                #
                # Test for the right number of captures.
                #
                $pass = 0 unless
                    $Test -> is_num (scalar keys %minus,
                                     scalar keys %$hh_captures,
                              $__ . scalar (keys %$hh_captures)
                                  . " named capture groups");


                #
                # Test numbered captures.
                #
                for (my $i = 0; $i < @$aa_captures; $i ++) {
                    $pass = 0 unless
                        $Test -> is_eq ($numbered_matches [$i],
                                        $$aa_captures [$i],
                                       "${__}\$" . ($i + 1) . " " .
                                        mess $$aa_captures [$i]);
                }
                $pass = 0 unless
                    $Test -> is_num (scalar @numbered_matches,
                                     scalar @$aa_captures,
                                     $__ . @$aa_captures .
                                     " numbered captured groups");
            }
        }

        if (!$match && defined $pattern) {
            my $r = $subject =~ /^$pattern/;
            $pass = 0 unless
                $Test -> ok (!$r || $subject ne $&, "$comment$reason");
        }
        if (!$match && defined $keep_pattern) {
            my $r = $subject =~ /^$keep_pattern/;
            $pass = 0 unless
                $Test -> ok (!$r || $subject ne $&,
                             "$comment (with -Keep)$reason");
        }
    }
    $pass;
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

It is therefore recommended to use
C<< use Text::Regexp tests => 'no_plan'; >>.
In a later version, C<< Test::Regexp >> will use a version of 
C<< Test::Builder >> that allows for nested tests.

=head3 Details

The number of tests is as follows: 

If no match is expected (C<< no_match => 0 >>, or C<< no_match >> is used),
only one test is performed.

Otherwise (we are expecting a match), if C<< pattern >> is used, there
will be three tests. 

For C<< keep_pattern >>, there will be four tests, plus one tests for
each capture, an additional test for each named capture, and a test
for each name used in the set of named captures. So, if there are
C<< N >> captures, there will be at least C<< 4 + N >> tests, and
at most C<< 4 + 3 * N >> tests.

If both C<< pattern >> and C<< keep_pattern >> are used, the number of
tests add up. 

If C<< Test::Regexp >> decides to upgrade or downgrade, the number of 
tests double.

=head2 C<< use >> options

When using C<< Test::Regexp >>, there are a few options you can
give it.

=over 4

=item C<< tests => 'no_plan' >>, C<< tests => 123 >>

The number of tests you are going to run. Since takes some work to
figure out how many tests will be run, for now the recommendation
is to use C<< tests => 'no_plan' >>.

=item C<< import => [methods] >>

By default, the subroutines C<< match >> and C<< no_match >> are 
exported. If you want to import a subset, use the C<< import >>
tag, and give it an arrayref with the names of the subroutines to
import.

=back

=head2 C<< match >>

The subroutine C<< match >> is the workhorse of the module. It takes
a number of named arguments, most of them optional, and runs one or
more tests. It returns 1 if all tests were run succesfully, and 0
if one or more tests failed. The following options are available:

=over 4

=item C<< subject => STRING >>

The string against which the pattern is tested is passed to C<< match >>
using the C<< subject >> option. It's an error to not pass in a subject.

=item C<< pattern => PATTERN >>, C<< keep_pattern => PATTERN >>

A pattern (aka regular expression) to test can be passed with one of
C<< pattern >> or C<< keep_pattern >>. The former should be used if the
pattern does not have any matching parenthesis; the latter if the pattern
does have capturing parenthesis. If both C<< pattern >> and C<< keep_pattern >>
are provided, the subject is tested against both. It's an error to not give
either C<< pattern >> or C<< keep_pattern >>.

=item C<< captures => [LIST] >>

If a regular expression is passed with C<< keep_pattern >> you should 
pass in a list of captures using the C<< captures >> option.

This list should contain all the captures, in order. For unnamed captures,
this should just be the string matched by the capture; for a named capture,
this should be a two element array, the first element being the name of
the capture, the second element the capture. Named and unnamed captures
may be mixed, and the same name for a capture may be repeated.

Example:

 match  subject      =>  "Eland Wapiti Caribou",
        keep_pattern =>  qr /(\w+)\s+(?<a>\w+)\s+(\w+)/,
        captures     =>  ["Eland", [a => "Wapiti"], "Caribou"];

=item C<< name => NAME >>

The "name" of the test. It's being used in the test comment.

=item C<< comment => NAME >>

An alternative for C<< name >>. If both are present, C<< comment >> is used.

=item C<< utf8_upgrade => 0 >>, C<< utf8_downgrade => 0 >>

As explained in L<< /UTF8 matching >>, C<< Test::Regexp >> detects whether
a subject may provoke different matching depending on its UTF8 flag, and
then it C<< utf8::upgrades >> or C<< utf8::downgrades >> the subject
string and runs the test again. Setting C<< utf8_upgrade >> to 0 prevents
C<< Test::Regexp >> from downgrading the subject string, while 
setting C<< utf8_upgrade >> to 0 prevents C<< Test::Regexp >> from 
upgrading the subject string.

=item C<< match => BOOLEAN >>

By default, C<< match >> assumes the pattern should match. But it also 
important to test which strings do not match a regular expression. This
can be done by calling C<< match >> with C<< match => 0 >> as parameter.
(Or by calling C<< no_match >> instead of C<< match >>). In this case,
the test is a failure if the pattern completely matches the subject 
string. A C<< captures >> argument is ignored. 

=item C<< reason => STRING >>

If the match is expected to fail (so, when C<< match => 0 >> is passed,
or if C<< no_match >> is called), a reason may be provided with the
C<< reason >> option. The reason is then printed in the comment of the
test.

=item C<< style => STRING >>

A for now undocumentated feature, and subject to change.

=back

=head2 C<< no_match >>

Similar to C<< match >>, except that it tests whether a pattern does
B<< not >> match a string. Accepts the same arguments as C<< match >>,
except for C<< match >>.

=head1 RATIONALE

The reason C<< Test::Regexp >> was created is to aid testing for
the rewrite of C<< Regexp::Common >>.

=head1 DEVELOPMENT

The current sources of this module are found on github,
L<< git://github.com/Abigail/test--regexp.git >>.

=head1 AUTHOR

Abigail L<< <test-regexp@abigail.be> >>.

=head1 COPYRIGHT and LICENSE

Copyright (C) 2009, Abigail

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
      
The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.
      
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
