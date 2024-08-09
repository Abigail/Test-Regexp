use 5.026;

use strict;
use warnings;
use charnames ":full";
no  warnings 'syntax';

use           experimental 'signatures';
no  warnings 'experimental::signatures';

package Test::Regexp {

    use Exporter ();
    use Test::Builder;

    our @EXPORT  = qw [match no_match];
    our @ISA     = qw [Exporter Test::More];

    our $VERSION = '2017082201';

    my $Test = Test::Builder:: -> new;

    my $ESCAPE_NONE           = 0;
    my $ESCAPE_WHITE_SPACE    = 1;
    my $ESCAPE_NAMES          = 2;
    my $ESCAPE_CODES          = 3;
    my $ESCAPE_NON_PRINTABLE  = 4;
    my $ESCAPE_DEFAULT        =
               grep ({$_ eq 'utf8'} PerlIO::get_layers (STDOUT))
             ? $ESCAPE_NON_PRINTABLE
             : $ESCAPE_CODES;


  PRIVATE:

    ############################################################################
    #
    # escape ($str, $escape)
    #
    # "Escapes" a string, that is, replace some characters with escaped
    # values. 
    #
    # Arguments:
    #    1.  $str:    The string to be escaped.
    #    2.  $escape: (Default 4 if STDOUT has the UTF8 layer; 3 otherwise.)
    #                 Meaning:
    #                   $ESCAPE_NONE (0):  Don't do any escaping.
    #                   $ESCAPE_WHITE_SPACE (1):   Replace newlines, tabs and
    #                                              carriage returns with
    #                                              \n, \t, and \r. 
    #                   $ESCAPE_NAMES (2):         Replace any non-ASCII
    #                                              character with its Unicode
    #                                              name, or a hex escape if
    #                                              no such name exists.
    #                   $ESCAPE_CODES (3):         Replace any non-ASCII
    #                                              character with its hex
    #                                              escape.
    #                   $ESCAPE_NON_PRINTABLE (4): Replace any non-printable
    #                                              ASCII character with its
    #                                              hex escape.
    #                 Whitespace escaping, as described by 
    #                 $ESCAPE_WHITE_SPACE also happens for $ESCAPE_NAMES,
    #                 $ESCAPE_CODES and $ESCAPE_NON_PRINTABLE.
    #
    # Returns:
    #    1.  The escaped string.
    #
    my sub escape ($str, $escape = $ESCAPE_DEFAULT) {
        $escape //= $ESCAPE_DEFAULT;
        return $str if $escape == $ESCAPE_NONE;
        $str =~ s/\n/\\n/g;
        $str =~ s/\t/\\t/g;
        $str =~ s/\r/\\r/g;
        return $str if $escape == $ESCAPE_WHITE_SPACE;
        if ($escape == $ESCAPE_NAMES) {
            $str =~ s{([^\x20-\x7E])}
                     {my $name = charnames::viacode (ord $1);
                      $name ? sprintf "\\N{%s}"   => $name
                            : sprintf "\\x{%02X}" => ord $1}eg;
        }
        elsif ($escape == $ESCAPE_CODES) {
            $str =~ s{([^\x20-\x7E])}
                     {sprintf "\\x{%02X}" => ord $1}eg;
        }
        elsif ($escape == $ESCAPE_NON_PRINTABLE) {
            $str =~ s{([\x00-\x1F\xFF])}
                     {sprintf "\\x{%02X}" => ord $1}eg;
        }
        $str;
    }


    ############################################################################
    #
    # pretty ($str, %args)
    #
    # Makes a string "pretty"; that is, shortens long strings, and escapes
    # the rest. If a string is longer than 30 characters, the first 25 and
    # the last 5 are displayed, with "..." in between. This is to prevent
    # printing very long test names when testing long strings or patterns.
    #
    # Arguments:
    #    1.  $str:      The string to be prettified.
    #    -   full_text: (Optional) If true, the string isn't shortened.
    #    -   escape:    (Optional) Passed on the escape ().
    #
    # Returns:
    #    1.  The prettified string.
    #
    my sub pretty ($str, %args) {
        substr ($str, 25, -5, "...") if length $str > 30 && !$args {full_text};
        $str = escape $str, $args {escape};
        $str;
    }


    ############################################################################
    #
    # mess ($val, %args)
    #
    # Given a value, return a string to compare it with something else.
    # If it's undefined, it returns the string "undefined". Otherwise,
    # it calls pretty () to prettify the string, then it finds some quotes
    # to surround it, and returns "eq '$val'", 'eq "$val"', or 
    # "eq qq {$val}". The first if the value doesn't contain a single
    # quote, the second if the value contains a single quote but not a
    # double quote, else, the latter form.
    #
    # Arguments:
    #    1. $val:      The value to process.
    #    -  full_text: (Optional) Passed on to pretty ().
    #    -  escape:    (Optional) Passed on to pretty ().
    #
    my sub mess ($val, %args) {
        unless (defined $val) {return 'undefined'}
        my $pretty = pretty $val, %args;
        if ($pretty eq $val && $val !~ /'/) {
            return "eq '$val'";
        }
        elsif ($pretty !~ /"/) {
            return 'eq "' . $pretty . '"';
        }
        else {
            return "eq qq {$pretty}";
        }
    }


    ############################################################################
    #
    # todo_encodings (%args)
    #
    # Returns a set of tests in different encodings. Given the initial
    # subject, it checks whether it's possible to utf8 upgrade or to
    # utf8 down grade it. If so, it returns the up- or downgraded strings
    # and a marker indicating which change happened.
    #
    # A subject can be downgraded if it's in UTF8 format, contains
    # characters in the range 0x80 .. 0xFF, and no characters above 0xFF.
    # A subject can be upgraded if it's not in UTF8 format, and 
    # contains characters in the range 0x80 .. 0xFF.
    # Technically, strings can be up/downgraded if they only contain ASCII
    # characters (0x00 .. 0x7F), but Perl won't apply any possible different
    # matching, so we won't bother.
    #
    # Arguments:
    #    -  subject:   The subject being tested
    #    -  utf8_upgrade:    (Optional, default 1). If false, never do an
    #                        upgrade. If 2, always upgrade.
    #                        Else, inspect subject.
    #    -  utf8_downpgrade: (Optional, default 1). If false, never do a
    #                        downgrade.  If 2, always downgrade. Else,
    #                        inspect subject.
    #
    # Returns:
    #    1. Arrayref with two element arrayrefs, first element is the
    #       subject, possibly up or downgraded. Second element is the
    #       operation performed: 0  - no up or down grade
    #                            1  - utf8-upgraded         
    #                           -1  - utf8-downgraded
    #
    my sub todo_encodings (%args) {
        my $subject   =  $args {subject};
        my $upgrade   =  $args {utf8_upgrade}    // 1;
        my $downgrade =  $args {utf8_downgrade}  // 1;

        my @todo = [$subject, 0];

        #
        # If the subject isn't already UTF-8, and there are characters in
        # the range "\x{80}" .. "\x{FF}", we do the test a second time,
        # with the subject upgraded to UTF-8.
        #
        # Otherwise, if the subject is in UTF-8 format, and there are *no*
        # characters with code point > 0xFF, but with characters in the 
        # range 0x80 .. 0xFF, we downgrade and test again.
        #
        if ($upgrade && ($upgrade == 2 || !utf8::is_utf8 ($subject) 
                                       && $subject =~ /[\x80-\xFF]/)) {
            my $subject_utf8 = $subject;
            if (utf8::upgrade ($subject_utf8)) {
                push @todo => [$subject_utf8, 1];
            }
        }
        elsif ($downgrade && ($downgrade == 2 || utf8::is_utf8 ($subject)
                                             && $subject =~ /[\x80-\xFF]/
                                             && $subject !~ /[^\x00-\xFF]/)) {
            my $subject_non_utf8 = $subject;
            if (utf8::downgrade ($subject_non_utf8)) {
                push @todo => [$subject_non_utf8, -1];
            }
        }

        @todo;
    }
        

    ############################################################################
    #
    # check_match (%args)
    #
    # Check whether the pattern matches the string, and whether the match
    # is complete. If the pattern fails to match, the latter test is not
    # performed. This subroutine is called from a (nested) subtest.
    #
    # Arguments:
    #    -  subject:  String the pattern was matched against.
    #    -  match:    Substring of subject which was matched (${^MATCH})
    #    -  result:   Whether the match was successful.
    #
    # Return:
    #    1. True if the tests succeed, false otherwise.
    #
    my sub check_match (%args) {
        my $subject  = $args {subject};
        my $result   = $args {result};
        my $match    = $args {match};

        $Test -> ok    ($result, "Pattern matches")   &&
        $Test -> is_eq ($match, $subject, "Match is complete");
    }


    ############################################################################
    #
    # extract_captures (%args)
    #
    # Returns references to structures with the expected captures.
    # For positional captures, this will be a reference to an array
    # with the captures in successive order.
    # For named captures, this will be a reference to a hash, whose
    # keys are the names of the captures, and whose values are references
    # to arrays containing the captures with that name, in order (ala %-).
    #
    # Arguments:
    #    -  captures:  (Optional) Arrayref with the captures in order.
    #                  For purely positional captures (that is, without
    #                  a name), a capture is just a string. For named
    #                  captures, this is an arrayref whose first element
    #                  is the name of the capture, and the second element
    #                  the capture itself.
    #
    # Returns:
    #    1. Arrayref with positional captures (may be empty)
    #    2. Hashref with named captures (may be empty)
    #
    my sub extract_captures (%args) {
        my $exp_positional_captures = [];
        my $exp_named_captures      = {};
        return ($exp_positional_captures, $exp_named_captures)
                 unless $args {captures} &&
                    ref $args {captures} &&
                    ref $args {captures} eq 'ARRAY';
        if ($args {captures} && ref $args {captures} &&
                                ref $args {captures} eq 'ARRAY') {
            foreach my $capture (@{$args {captures}}) {
                if (ref $capture eq 'ARRAY') {
                    my ($name, $match) = @$capture;
                    push   @$exp_positional_captures => $match;
                    push @{$$exp_named_captures {$name}} => $match;
                }
                else {
                    push @$exp_positional_captures => $capture;
                }
            }
        }

        ($exp_positional_captures, $exp_named_captures);
    }



    ############################################################################
    #
    # named_captures (%args)
    #
    # Checks whether the named captures we got matches the expected named
    # captures.
    #   - For all each gotten capture name, we check whether the number
    #     of captures with that name matches the number of expected 
    #     captures of that name [1]; if so, then
    #   - For each capture of a given name, check whether it's equal to
    #     to expected captures of that name.
    #   - Check whether each expected capture name is accounted for.
    #
    # [1] This also triggers a failure if we got a capture we didn't expect.
    #
    # Arguments:
    #    -  exp_named_captures: Hash ref of expected named captures; keyed on 
    #                           capture name; values are references to arrays
    #                           with the captures.
    #    -  got_captures:       Deep copy of %-.
    #
    #    -  full_text:          Passed on to mess ().
    #    -  escape:             Passed on to mess ().
    #
    # Return:
    #    1. True if all tests succeed, false otherwise.
    #
    my sub named_captures (%args) {
        my $exp_captures = $args {exp_named_captures} // {};
        my $got_captures = $args {got_captures}       // {};

        return $Test -> is_eq (scalar keys %$got_captures,
                               scalar keys %$exp_captures,
                              "No named captures") unless %$exp_captures;

        my $pass = 1;
      CAPTURE_NAME:
        foreach my $name (keys %$got_captures) {
            my $exp_capture_count = scalar @{$$exp_captures {$name} || []};
            unless ($Test -> is_eq (scalar @{$$got_captures {$name} || []},
                                    $exp_capture_count,
                                    sprintf "%d capture%s named '%s'" =>
                                            $exp_capture_count,
                                            $exp_capture_count == 1 ? "" : "s",
                                            $name)) {
                $pass = 0;
                next CAPTURE_NAME;
            }
            for (my $i = 0; $i < @{$$got_captures {$name}}; $i ++) {
                $pass &&= $Test -> is_eq ($$got_captures {$name} [$i],
                                          $$exp_captures {$name} [$i],
                                          "\$- {$name} [$i] " .
                                          mess ($$exp_captures {$name} [$i],
                                                %args));
            }
        }

        my @did_not_get = grep {!exists $$got_captures {$_}}
                          keys          %$exp_captures;
        $pass &&= $Test -> is_eq (scalar @did_not_get, 0,
                                 "All expected captures accounted for");

        $pass;
    }


    ############################################################################
    #
    # positional_captures (%args)
    #
    # Checks whether the positional captures we got matches the expected
    # positional captures.
    #   -  We check the number of gotten captures equals the number of
    #      expected capture; we fail if we don't.
    #   -  Else, for each capture, we check it against the expected capture.
    #      If a capture doesn't match, the test fails
    #      (but we continue checking).
    #
    # Arguments:
    #    -  exp_positional_captures: Arrayref with expected captures.
    #    -  got_captures:            Arrayref with gotten captures.
    #
    #    -  full_text:               Passed on to mess ().
    #    -  escape:                  Passed on to mess ().
    #
    # Return:
    #    1. True if the tests succeed, false otherwise.
    #
    my sub positional_captures (%args) {
        my $exp_captures = $args {exp_positional_captures} // [];
        my $got_captures = $args {got_captures}            // [];

        return unless $Test -> is_eq (scalar @$got_captures,
                                      scalar @$exp_captures,
                                      "Number of positional captures");

        my $pass = 1;
        for (my $i = 0; $i < @$exp_captures; $i ++) {
            $pass &&= $Test -> is_eq ($$got_captures [$i],
                                      $$exp_captures [$i],
                                      '$' . ($i + 1) . " " .
                                      mess ($$exp_captures [$i], %args));
        }

        $pass;
    }


    ############################################################################
    #
    # should_not_match (%args)
    #
    # This is called to test whether a pattern does *not* match.
    # The regular expression match failing is considered a success, and
    # so is not completely matching the subject.
    #
    # Arguments:
    #    -  subject:  The string against we should match the pattern.
    #    -  pattern:  The pattern being tested.
    #
    # Return:
    #    1. True if the pattern fails to completely match the subject,
    #       fails otherwise.
    #
    my sub should_not_match (%args) {
        my $subject = $args {subject};
        my $pattern = $args {pattern};

        my $result  = $subject =~ /^$pattern/p;

        $Test -> ok (!$result || $subject ne ${^MATCH}, "Does not match");
    }


    ############################################################################
    #
    # should_match (%args)
    #
    # This is called when a pattern should match the subject (and the pattern
    # should match the subject completely).
    # We start by matching the pattern to the subject, collecting the result
    # of the match, the substring which was matched (${^MATCH}), and we copy
    # the captures, if any ($1, $2, ..., and %-).
    # We then call check_match (as a subtest) to check whether we have a
    # complete match; if this fails, we return false.
    # Else, we check whether we got the right captures, both positional and
    # named, by calling named_captures and _positional_captures, both as
    # different subtests.
    # We return true if all tests pass, false otherwise.
    #
    # Arguments:
    #    -  subject:  The string against we should match the pattern.
    #    -  pattern:  The pattern being tested.
    #
    # Return:
    #    1. True if the pattern completely match the subject, and if all
    #       the capture match the expected captures; fails if any test fails.
    # 
    my sub should_match (%args) {
        my $subject = $args {subject};
        my $pattern = $args {pattern};

        my $result = $subject =~ /^$pattern/p;

        my $match = ${^MATCH};

        #
        # Grab numbered captures.
        #
        my @got_captures = @{^CAPTURE};

        #
        # Copy %-;
        #
        my %got_captures;
        while (my ($key, $value) = each %-) {
            $got_captures {$key} = [@$value];
        }

        return unless $Test -> subtest ("Match",
                                        \&check_match,
                                        %args,
                                        result => $result,
                                        match  => $match,);

        my $pass = 1;

        $pass &&= $Test -> subtest ("Named captures",
                                    \&named_captures,
                                    %args,
                                    got_captures => \%got_captures);

        $pass &&= $Test -> subtest ("Positional captures",
                                    \&positional_captures,
                                    %args,
                                    got_captures => \@got_captures);

        $pass;
    }


    ############################################################################
    #
    # make_test_name (%args)
    #
    # Creates a name for the other level subtest. This will be of the form
    #    Matching/Not matching "subject" against /pattern/
    # By default, the subject and pattern are restricted to 30 characters,
    # and have funny characters escaped (see the escape subroutine)
    #
    # Arguments:
    #    -  match:     If true, the test name starts with "Matching",
    #                  else with "Not matching"
    #    -  name:      (Optional) Print the name (in quotes) instead of
    #                  /pattern/;
    #                  this may be useful if you generate the pattern, and what
    #                  to describe what it does, instead of showing the pattern.
    #    -  pattern:   The pattern the match is performed with. Ignore if name
    #                  is given.
    #    -  subject:   The string being matched against.
    #
    #    -  comment:   (Obsolete) Can be used instead of the 'name' argument.
    #                  Ignored if name is given.
    #
    #    -  escape:    (Optional) Passed on to pretty (), then to escape ().
    #                  See escape().
    #    -  full_text: (Optional) Passed on to pretty (). See pretty ().
    #
    # Return:
    #    1. Name of test
    #
    my sub make_test_name (%args) {
        my $match        = $args {match};
        my $name         = $args {name} // $args {comment};
        my $pattern      = $args {pattern};
        my $subject      = $args {subject};

        sprintf qq {%s "%s" against %s} =>
                    $match ? "Matching" : "Not matching",
                    pretty ($subject, %args),
                    $name ? qq {"$name"}
                          : "/" . (pretty $pattern, %args) . "/";
    }




  PUBLIC:

    ############################################################################
    #
    # import ($self, %args)
    #
    # Importer.
    #
    # Arguments:
    #    -  import:   (Optional). Takes an arrayref with methods to import.
    #    -  tests:    (Optional). How many tests you want to run.
    #
    sub import ($self, %args) {
        my $pkg  = caller;

        $Test -> exported_to ($pkg);

        $args {import} //= [qw [match no_match]];

        while (my ($key, $value) = each %args) {
            if ($key eq "tests") {
                $Test -> plan ($value);
            }
            elsif ($key eq "import") {
                $self -> export_to_level (1, $self, $_) for @{$value || []};
            }
            else {
                die "Unknown option '$key'\n";
            }
        }
    }

    ############################################################################
    #
    # match (%args)
    #
    # Performs all the tests to check whether a pattern matches against
    # a given string.
    #
    # Arguments:
    #   - pattern:         Pattern to be tested.
    #   - subject:         String to match against.
    #   - name:           (Optional) 'Name' of the pattern.
    #                      See make_test_name ().
    #   - captures:       (Optional) Arrayref with expected captures.
    #                      See extract_captures ().
    #   - match:          (Default 1) If true, pattern should match. If false
    #                      pattern should *not* match.
    #   - todo:           (Optional) If set, the tests are "TODO" tests;
    #                      its value will be the todo message.
    #   - show_line:      (Optional) If true, display file and line number
    #                      from where the test is called from.
    #   - full_text:      (Optional) If true, don't shorten long messages.
    #                      See pretty ().
    #   - test:           (Optional) If set, shows what exactly you are testing;
    #                      Will be printed as a note (diagnostic message).
    #   - reason:         (Optional) If set, shows why a pattern should fail
    #                      to match. Will be printed as a note
    #                      (diagnostic message)
    #   - utf8_upgrade:   (Default 1) If true, utf8 upgrade the string as
    #                      part of the test. See todo_encodings ().
    #   - utf8_downgrade: (Default 1) If true, utf8 downgrade the string as
    #                      part of the test. See todo_encodings ().
    #   - comment:        (Obsolete) Alternative for 'name'.
    #
    # Return:
    #    1.  True if all tests pass, false otherwise.
    #
    sub match (%args) {

        $args {__caller} //= [(caller) [2, 1]];

        my $pattern = $args {pattern};
        my $subject = $args {subject};
        my $match   = $args {match} //= 1;
        my $todo    = $args {todo};

        my $pass    = 1;

        my $test_name = make_test_name %args;

        my ($exp_positional_captures,
            $exp_named_captures) = extract_captures %args;

        my @todo_encodings = todo_encodings %args;

        $Test -> subtest ($test_name, sub {
            if ($match && defined $args {test}) {
                $Test -> note ('Test: ' , $args {test});
            }
            elsif (!$match && defined $args {reason}) {
                $Test -> note ('Reason: ' , $args {reason});
            }

            if ($args {show_line} && $args {__caller}) {
                $Test -> note (sprintf "Line %d in file %s",
                                      @{$args {__caller}});
            }

            $Test -> todo_start ($todo) if defined $todo;

            #
            # Now we will do the tests.
            #
            my $pass = 1;
            foreach my $todo_encoding (@todo_encodings) {
                my $subject = $$todo_encoding [0];
                my $up_down = $$todo_encoding [1];

                my $test_name = $up_down ==  0 ? "No conversion"
                              : $up_down == -1 ? "utf8 downgraded"
                              : $up_down ==  1 ? "utf8 upgraded"
                              : die "Unexpected up/down value";

                my %args = (
                    %args,
                    subject                 =>  $subject,
                    exp_named_captures      =>  $exp_named_captures,
                    exp_positional_captures =>  $exp_positional_captures,
                );

                my $sub = $match ? \&should_match
                                 : \&should_not_match;

                if (@todo_encodings > 1) {
                    $pass &&= $Test -> subtest ($test_name, $sub, %args);
                }
                else {
                    $pass &&= &$sub (%args);
                }
            }

            $Test -> todo_end if defined $todo;

            return $pass;
        });
    }

    sub no_match {
        push @_ => match => 0;
        goto &match;
    }

    sub new {
        Test::Regexp::Object:: -> new
    }
}


package Test::Regexp::Object {

    sub new {
        bless \do {my $var} => shift;
    }

    use Hash::Util::FieldHash qw [fieldhash];

    fieldhash my %pattern;
    fieldhash my %name;
    fieldhash my %comment;
    fieldhash my %utf8_upgrade;
    fieldhash my %utf8_downgrade;
    fieldhash my %match;
    fieldhash my %reason;
    fieldhash my %test;
    fieldhash my %show_line;
    fieldhash my %full_text;
    fieldhash my %escape;
    fieldhash my %todo;
    fieldhash my %tags;

    sub init {
        my $self = shift;
        my %arg  = @_;

        $pattern             {$self} = $arg {pattern};
        $name                {$self} = $arg {name};
        $comment             {$self} = $arg {comment};
        $utf8_upgrade        {$self} = $arg {utf8_upgrade};
        $utf8_downgrade      {$self} = $arg {utf8_downgrade};
        $match               {$self} = $arg {match};
        $reason              {$self} = $arg {reason};
        $test                {$self} = $arg {test};
        $show_line           {$self} = $arg {show_line};
        $full_text           {$self} = $arg {full_text};
        $escape              {$self} = $arg {escape};
        $todo                {$self} = $arg {todo};
        $tags                {$self} = $arg {tags} if exists $arg {tags};

        $self;
    }

    sub args {
        my  $self = shift;
        (
            pattern             => $pattern             {$self},
            name                => $name                {$self},
            comment             => $comment             {$self},
            utf8_upgrade        => $utf8_upgrade        {$self},
            utf8_downgrade      => $utf8_downgrade      {$self},
            match               => $match               {$self},
            reason              => $reason              {$self},
            test                => $test                {$self},
            show_line           => $show_line           {$self},
            full_text           => $full_text           {$self},
            escape              => $escape              {$self},
            todo                => $todo                {$self},
        )
    }

    sub match {
        my  $self     = shift;
        my  $subject  = shift;
        my  $captures = @_ % 2 ? shift : undef;

        Test::Regexp::match subject  => $subject,
                            captures => $captures,
                            __caller => [(caller) [2, 1]],
                            $self    -> args, 
                            @_;
    }

    sub no_match {
        my  $self    = shift;
        my  $subject = shift;

        Test::Regexp::no_match subject  => $subject,
                               __caller => [(caller) [2, 1]],
                               $self    -> args,
                               @_;
    }

    sub name {$name {+shift}}

    sub set_tag {
        my $self = shift;
        $tags {$self} {$_ [0]} = $_ [1];
    }
    sub tag {
        my $self = shift;
        $tags {$self} {$_ [0]};
    }
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
          pattern      => qr /(?<first_word>\w+)\s+(\w+)/,
          captures     => [[first_word => 'Foo'], ['bar']];

 no_match subject      => "Baz",
          pattern      => qr /Quux/;

 $checker = Test::Regexp -> new -> init (
    pattern      => qr /(\w+)\s+\g{-1}/,
    name         => "Double word matcher",
 );

 $checker -> match    ("foo foo", ["foo"]);
 $checker -> no_match ("foo bar");

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

A match is only considered to successfully match if the entire string
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
more tests. It returns 1 if all tests were run successfully, and 0
if one or more tests failed. The following options are available:

=over 4

=item C<< subject => STRING >>

The string against which the pattern is tested is passed to C<< match >>
using the C<< subject >> option. It's an error to not pass in a subject.

=item C<< pattern => PATTERN >>

The pattern (aka regular expression) to test with.

=item C<< captures => [LIST] >>

If a regular expression is passed with captures you should 
pass in a list of captures using the C<< captures >> option.

This list should contain all the captures, in order. For unnamed captures,
this should just be the string matched by the capture; for a named capture,
this should be a two element array, the first element being the name of
the capture, the second element the capture. Named and unnamed captures
may be mixed, and the same name for a capture may be repeated.

Example:

 match  subject      =>  "Eland Wapiti Caribou",
        pattern      =>  qr /(\w+)\s+(?<a>\w+)\s+(\w+)/,
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

=item C<< test => STRING >>

If the match is expected to pass (when C<< match >> is called, without
C<< match >> being false), and this option is passed, a message is printed
indicating what this specific test is testing (the argument to C<< test >>).

=item C<< todo => STRING >>

If the C<< todo >> parameter is used (with a defined value), the tests
are assumed to be TODO tests. The argument is used as the TODO message.

=item C<< full_text => BOOL >>

By default, long test messages are truncated; if a true value is passed, 
the message will not get truncated.

=item C<< escape => INTEGER >>

Controls how non-ASCII and non-printables are displayed in generated
test messages:

=over 2

=item B<< 0 >>

No characters are escape, everything is displayed as is.

=item B<< 1 >>

Show newlines, linefeeds and tabs using their usual escape sequences
(C<< \n >>, C<< \r >>, and C<< \t >>).

=item B<< 2 >>

Show any character outside of the printable ASCII characters as named
escapes (C<< \N{UNICODE NAME} >>), or a hex escape if the unicode name
is not found (C<< \x{XX} >>). This is the default if C<< -CO >> is not in
effect (C<< ${^UNICODE} >> is false).

Newlines, linefeeds and tabs are displayed as above.

=item B<< 3 >>

Show any character outside of the printable ASCII characters as hext
escapes (C<< \x{XX} >>).

Newlines, linefeeds and tabs are displayed as above.

=item B<< 4 >>

Show the non-printable ASCII characters as hex escapes (C<< \x{XX} >>);
any non-ASCII character is displayed as is. This is the default if
C<< -CO >> is in effect (C<< ${^UNICODE} >> is true).

Newlines, linefeeds and tabs are displayed as above.

=back

=head2 C<< no_match >>

Similar to C<< match >>, except that it tests whether a pattern does
B<< not >> match a string. Accepts the same arguments as C<< match >>,
except for C<< match >>.

=head2 OO interface

Since one typically checks a pattern with multiple strings, and it can
be tiresome to repeatedly call C<< match >> or C<< no_match >> with the
same arguments, there's also an OO interface. Using a pattern, one constructs
an object and can then repeatedly call the object to match a string.

To construct and initialize the object, call the following:

 my $checker = Test::Regexp -> new -> init (
    pattern      => qr  /PATTERN/,
    ...
 );

C<< init >> takes exactly the same arguments as C<< match >>, with the
exception of C<< subject >> and C<< captures >>. To perform a match,
all C<< match >> (or C<< no_match >>) on the object. The first argument
should be the subject the pattern should match against (see the
C<< subject >> argument of C<< match >> discussed above). If there is a
match against a capturing pattern, the second argument is a reference
to an array with the matches (see the C<< captures >> argument of
C<< match >> discussed above).

Both C<< match >> and C<< no_match >> can take additional (named) arguments,
identical to the none-OO C<< match >> and C<< no_match >> routines.

=head1 RATIONALE

The reason C<< Test::Regexp >> was created is to aid testing for
the rewrite of C<< Regexp::Common >>.

=head1 DEVELOPMENT

The current sources of this module are found on github,
L<< git://github.com/Abigail/Test-Regexp.git >>.

=head1 AUTHOR

Abigail L<< mailto:test-regexp@abigail.be >>.

=head1 COPYRIGHT and LICENSE

Copyright (C) 2009 by Abigail

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

=head1 INSTALLATION

To install this module, run, after unpacking the tar-ball, the
following commands:

   perl Makefile.PL
   make
   make test
   make install

=cut
