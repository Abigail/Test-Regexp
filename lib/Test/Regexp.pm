package Test::Regexp;

use 5.010;

use strict;
use warnings;
no  warnings 'syntax';

use Exporter ();

our @EXPORT  = qw [match no_match r_string lorem v_diag];
our @ISA     = qw [Exporter];

our $VERSION = '0.01';

BEGIN {
    binmode STDOUT, ":utf8";
}

use Test::More;

# 
# Intercept the call to Test::Builder::caller; this allows us to
# to have error reported in the file/line it occurs, not in Test/Regexp.pm.
#
BEGIN {
    no strict 'refs';
    my $orig = *{"Test::Builder::caller"} {CODE};
    no warnings 'redefine';
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


sub match {
    my %arg            = @_;

    my $name           = $arg {name};
    my $Name           = $name; $Name =~ s/[^a-zA-Z0-9_]+/_/g;
    my $pattern        = $arg {pattern};
    my $keep_pattern   = $arg {keep_pattern};
    my $subject        = $arg {subject};
    my $subject_pretty = pretty $subject;
    my $captures       = $arg {captures};
    my $comment        = escape $arg {comment} // $name;
    my $keep           = $arg {keep} // 1;

    my $plus;
       $$plus {"${Name}"}     = $subject;
       $$plus {"${Name}__$_"} = $$captures {$_} for keys %$captures;

    my $Comment        = qq {qq {$subject_pretty}};
       $Comment       .= qq { matched by "$comment"};

    my @todo           = [$subject, $Comment];

    #
    # If the subject isn't already UTF-8, and there are characters in
    # the range "\x{80}" .. "\x{FF}", we do the test a second time,
    # with the subject upgraded to UTF-8.
    #
    # Otherwise, if the subject is in UTF-8 format, and there are *no*
    # characters with code point > 0xFF, but with characters in the 
    # range 0x80 .. 0xFF, we downgrade and test again.
    #
    if (!utf8::is_utf8 ($subject) && $subject =~ /[\x80-\xFF]/) {
        my $subject_utf8 = $subject;
        if (utf8::upgrade ($subject_utf8)) {
            my $Comment_utf8   = qq {qq {$subject_pretty}};
               $Comment_utf8  .= qq { [UTF-8]};
               $Comment_utf8  .= qq { matched by "$comment"};

            push @todo => [$subject_utf8, $Comment_utf8];
        }
    }
    elsif (utf8::is_utf8 ($subject) && $subject =~ /[\x80-\xFF]/ &&
                                       $subject !~ /[^\x00-\xFF]/) {
        my $subject_non_utf8 = $subject;
        if (utf8::downgrade ($subject_non_utf8)) {
            my $Comment_non_utf8  = qq {qq {$subject_pretty}};
               $Comment_non_utf8 .= qq { [non-UTF-8]};
               $Comment_non_utf8 .= qq { matched by "$comment"};

            push @todo => [$subject_non_utf8, $Comment_non_utf8];
        }
    }

    #
    # Test match; match should also be complete.
    #
    if (defined $pattern) {
        foreach my $todo (@todo) {
            my $subject = $$todo [0];
            my $comment = $$todo [1];
            SKIP: {
                skip "Match failed", 1 unless
                    ok $subject =~ /$pattern/, $comment;
                is $&, $subject, "${__}match is complete";
            }
        }
    }

    #
    # Test keep. Should match, and the parts as well.
    #
    if ($keep && defined $keep_pattern) {
        foreach my $todo (@todo) {
            my $subject = $$todo [0];
            my $comment = $$todo [1];

            SKIP: {
                skip "Match failed" => scalar keys %$captures unless
                    ok $subject =~ /^$keep_pattern$/, "$Comment (with -Keep)";

                while (my ($key, $value) = each %$plus) {
                    my $val = defined $value ? 'eq "' . pretty ($value) . '"'
                                             : 'undefined';
                    is $+ {$key}, $value, "${__}\$+ {$key} $val";
                }
                #
                # Not %+, as that's buggy in 5.10.0.
                #
                my $c = keys %$plus;
                is scalar  keys %-,
                   scalar (keys %$plus) + ($arg {extra_groups} // 0),
                   qq {${__}$c capture groups};
            }
        }
    }
}

sub no_match {
    my %arg            = @_;
 
    my $name           = $arg {name};
    my $pattern        = $arg {pattern};
    my $keep_pattern   = $arg {keep_pattern};
    my $subject        = $arg {subject};
    my $subject_pretty = pretty $subject;
    my $comment        = escape $arg {comment} // $name;
    my $reason         = $arg {reason} ? " [Reason: " . $arg {reason} . "]" 
                                      : "";

    my $Comment        = qq {qq {$subject_pretty}};
       $Comment       .= qq { not matched by "$comment"};

    my @todo           = [$subject, $Comment];

    if (!utf8::is_utf8 ($subject) && $subject =~ /[\x80-\xFF]/) {
        my $subject_utf8   = $subject;
        utf8::upgrade ($subject_utf8);

        my $Comment_utf8   = qq {qq {$subject_pretty}};
           $Comment_utf8  .= qq { [UTF-8]};
           $Comment_utf8  .= qq { not matched by "$comment"};

        push @todo => [$subject_utf8, $Comment_utf8];
    }

    foreach my $todo (@todo) {
        my $subject = $$todo [0];
        my $comment = $$todo [1];

        ok $subject !~ /^$pattern\z/,      "$comment$reason"
            if defined $pattern;
        ok $subject !~ /^$keep_pattern\z/, "$comment (with -Keep)$reason"
            if defined $keep_pattern;
    }
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
    my @lorem;

    $lorem [0] = join ' ' => @LOREM [0 .. 18];

    foreach my $c (1 .. $arg {lines} // 10) {
        my $i = int rand @LOREM;
        my $j = int rand @LOREM;
        redo if $i == $j;
        ($i, $j)  = ($j, $i) if $j < $i;
        push @lorem => join ' ' => @LOREM [$i .. $j];
    }

    @lorem;
}




1;

__END__
