package Test::Regexp;

use 5.010;

use strict;
use warnings;
no  warnings 'syntax';

use Exporter ();

use vars qw [$TESTS_FAIL $TESTS_PASS $TESTS_SKIP];

our @EXPORT    = qw [match no_match r_string lorem];
our @EXPORT_OK = qw [$TESTS_FAIL $TESTS_PASS $TESTS_SKIP];
our @ISA       = qw [Exporter Test::More];

sub substitute;
sub lorem;
sub r_string;

our $VERSION = '0.01';

BEGIN {
    binmode STDOUT, ":utf8";
}

use Test::More import => [qw [!ok !is !todo !skip]];

# 
# Intercept the call to Test::Builder::caller; this allows us to
# have the error reported in the file/line it occurs, not in Test/Regexp.pm.
#
BEGIN {
    no strict 'refs';
    my $orig = *{"Test::Builder::caller"} {CODE};
    no warnings 'redefine';
    no warnings 'once';
    *{"Test::Builder::caller"} = sub {
        $_ [1] //= $Test::Builder::deepness // 1;
        goto &$orig;
    };
}

my $__ = "    ";

sub escape {
    my $str = shift;
    $str =~ s/\n/\\n/g;
    $str =~ s/\t/\\t/g;
    $str =~ s/\r/\\r/g;
    $str =~ s/(\p{C})/sprintf "\\x{%02X}" => ord $1/eg;
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
    my %arg            =  @_;
    my $subject        =  $arg {subject};
    my $comment        =  $arg {comment};
    my $upgrade        =  $arg {upgrade};
    my $downgrade      =  $arg {downgrade};
    my $neg            =  $arg {match} ? "" : "not ";

    my $line           = "";

    if ($arg {show_line}) {
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
    

sub ok {
    my $c = &Test::More::ok (@_);   # Bypass ok's prototype.
   ($c ? $TESTS_PASS : $TESTS_FAIL) ++;
    $c;
}
sub is {
    my $c = &Test::More::is (@_);   # Bypass is's prototype.
   ($c ? $TESTS_PASS : $TESTS_FAIL) ++;
    $c;
}
sub skip {
    $TESTS_SKIP += $_ [1];
    goto &Test::More::skip;
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
#   utf_downgrade  If set, downgrade the string if applicable. Defaults to 1.
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
    my $reason         = $arg {reason} ? " [Reason: " . $arg {reason} . "]"
                                       : "";
    my $show_line      = $arg {show_line};
    my $style          = $arg {style} // "";

    $TESTS_FAIL        = 0;
    $TESTS_PASS        = 0;
    $TESTS_SKIP        = 0;

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
            push @$aa_captures => $match;
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

    my @todo           = todo subject   => $subject,
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
                skip "Match failed", 2 unless ok $result, $comment;
                is $&, $subject, "${__}match is complete";
                ok @- == 1 && keys %- == 0, "${__}no captures";
            }
        }
        if ($match && defined $keep_pattern) {
            #
            # Test keep. Should match, and the parts as well.
            #
            SKIP: {
                my $skips  = 1 + @aa_captures;
                   $skips += @{$_} for values %hh_captures;

                my ($amp, @numbered_matches, %minus);

                my $result = $subject =~ /^$keep_pattern/;
                skip "Match failed" => $skips unless
                    ok $result, "$comment (with -Keep)";
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
                # Test named captures.
                #
                while (my ($key, $value) = each %hh_captures) {
                    for (my $i = 0; $i < @$value; $i ++) {
                        is $minus {$key} [$i], $$value [$i],
                           "${__}\$- {$key} [$i] " . mess $$value [$i];
                    }
                    is scalar @{$minus {$key}}, scalar @$value, 
                           "${__} capture '$key' has " . @$value .
                           " matches";
                }
                #
                # Test for the right number of captures.
                #
                is scalar keys %minus, scalar keys %hh_captures,
                   $__ . scalar (keys %hh_captures)
                       . " named capture groups";


                #
                # Test numbered captures.
                #
                for (my $i = 0; $i < @aa_captures; $i ++) {
                    is $numbered_matches [$i], $aa_captures [$i],
                       "${__}\$$i " . mess $aa_captures [$i];
                }
                is scalar @numbered_matches, scalar @aa_captures,
                   $__ . @aa_captures . " numbered captured groups";
            }
        }

        if (!$match && defined $pattern) {
            my $r = $subject =~ /^$pattern/;
            ok !$r || $subject ne $&, "$comment$reason";
        }
        if (!$match && defined $keep_pattern) {
            my $r = $subject =~ /^$keep_pattern/;
            ok !$r || $subject ne $&, "$comment (with -Keep)$reason";
        }
    }

    !$TESTS_FAIL;
}

sub no_match {
    push @_ => match => 0;
    goto &match;
}



use charnames ();
sub _u {map {chr} grep {charnames::viacode ($_)} @_}

sub r_string {
    state $latin = [map {chr} 0x20 .. 0x7F, 0xA0 .. 0xFF];
    state $uni   = [
        [_u 0x0020 .. 0x007F, 0x00A0 .. 0x00FF],   # Latin-1
        [_u 0x0100 .. 0x02AD,                      # More Latin-1
            0x1E00 .. 0x1EFF],                     # ... and more
        [_u 0x0384 .. 0x03E1,                      # Greek
            0x1F00 .. 0x1FFE],                     # ... and more
        [_u 0x0400 .. 0x0482, 0x048A .. 0x0513],   # Cyrillic
        [_u 0x0530 .. 0x058A],                     # Armenian
        [_u 0x05D0 .. 0x05F4],                     # Hebrew
        [_u 0x0621 .. 0x064A, 0x0660 .. 0x0669],   # Arabic
        [_u 0x0E01 .. 0x0E5B],                     # Thai
        [_u 0x10D0 .. 0x10F8],                     # Gregorian
        [_u 0x11A8 .. 0x11C2],                     # Hangul
        [_u 0x1680 .. 0x169C],                     # Ogham
        [_u 0x16A0 .. 0x16F0],                     # Runic
        [_u 0x2200 .. 0x23BD],                     # Math symbols
        [_u 0x23BE .. 0x23CC],                     # Dentistry symbols
        [_u 0x2800 .. 0x28FF],                     # Braille
        [_u 0x3041 .. 0x3093],                     # Hiragana
        [_u 0x30A1 .. 0x30F6],                     # Katakana

        [_u 0x2010 .. 0x2027,                      # Symbols, sign, misc stuff
            0x2030 .. 0x2052,
            0x2070 .. 0x208E,
            0x20A0 .. 0x20B1,
            0x2100 .. 0x21FF,
            0x2400 .. 0x2426,
            0x2440 .. 0x2441,
            0x2460 .. 0x2486,
            0x2500 .. 0x2689,
            0x2701 .. 0x2767,
            0x2778 .. 0x27A7,
            0x27F5 .. 0x27FF,
            0xFE30 .. 0xFE69,
            0xFF01 .. 0xFF5F,
            0xFFE0 .. 0xFFE6,
        ],
    ];

    my %arg = @_;
    my $min_l = $arg {min} //  3;
    my $max_l = $arg {max} // 10;

    my $index = $arg {unicode} ? int rand @$uni : 0;
    my $chars = $$uni [$index];

  again:
    my $str;

    $str .= $$chars [rand @$chars] for 1 .. $min_l + rand ($max_l - $min_l);

    if ($arg {exclude}) {
        my $pat = $arg {exclude};
        $str =~ s/$pat//g;
        goto again if length $str < $min_l;
    }

    $str;
}

my @LOREM = grep {/\S/} split ' ' =><< '--';
    Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do
    eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut
    enim ad minim veniam, quis nostrud exercitation ullamco laboris
    nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in
    reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla
    pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
    culpa qui officia deserunt mollit anim id est laborum.
--

#
# Give back a bunch of random ASCII text.
#
sub lorem {
    my %arg = @_;
    $arg {lines} = 1 unless wantarray;
    my @lorem;

    $lorem [0] = join ' ' => @LOREM [0 .. 18] if wantarray;

    foreach my $c (1 .. $arg {lines} // 10) {
        my $i = int rand @LOREM;
        my $j = int rand @LOREM;
        redo if $i == $j;
        ($i, $j)  = ($j, $i) if $j < $i;
        push @lorem => join ' ' => @LOREM [$i .. $j];
    }

    wantarray ? @lorem : $lorem [0];
}




1;

__END__
