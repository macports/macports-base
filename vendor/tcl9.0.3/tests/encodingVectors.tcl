# This file contains test vectors for verifying various encodings. They are
# stored in a common file so that they can be sourced into the various test
# modules that are dependent on encodings. This file contains statically defined
# test vectors. In addition, it sources the ICU-generated test vectors from
# icuUcmTests.tcl.
#
# Note that sourcing the file will reinitialize any existing encoding test
# vectors.
#

# List of defined encoding profiles
set encProfiles {tcl8 strict replace}
set encDefaultProfile strict; # Should reflect the default from implementation

# encValidStrings - Table of valid strings.
#
# Each row is <ENCODING STR BYTES CTRL COMMENT>
# The pair <ENCODING,STR> should be unique for generated test ids to be unique.
# STR is a string that can be encoded in the encoding ENCODING resulting
# in the byte sequence BYTES. The CTRL field is a list that controls test
# generation. It may contain zero or more of `solo`, `lead`, `tail` and
# `middle` indicating that the generated tests should include the string
# by itself, as the lead of a longer string, as the tail of a longer string
# and in the middle of a longer string. If CTRL is empty, it is treated as
# containing all four of the above. The CTRL field may also contain the
# words knownBug or knownW3C which will cause the test generation for that
# vector to be skipped.
#
# utf-16, utf-32 missing because they are automatically
# generated based on le/be versions.
set encValidStrings {}; # Reset the table

lappend encValidStrings {*}{
    ascii    \u0000 00 {} {Lowest ASCII}
    ascii    \u007F 7F {} {Highest ASCII}
    ascii    \u007D 7D {} {Brace - just to verify test scripts are escaped correctly}
    ascii    \u007B 7B {} {Terminating brace - just to verify test scripts are escaped correctly}

    utf-8    \u0000 00 {} {Unicode Table 3.7 Row 1}
    utf-8    \u007F 7F {} {Unicode Table 3.7 Row 1}
    utf-8    \u0080 C280 {} {Unicode Table 3.7 Row 2}
    utf-8    \u07FF DFBF {} {Unicode Table 3.7 Row 2}
    utf-8    \u0800 E0A080 {} {Unicode Table 3.7 Row 3}
    utf-8    \u0FFF E0BFBF {} {Unicode Table 3.7 Row 3}
    utf-8    \u1000 E18080 {} {Unicode Table 3.7 Row 4}
    utf-8    \uCFFF ECBFBF {} {Unicode Table 3.7 Row 4}
    utf-8    \uD000 ED8080 {} {Unicode Table 3.7 Row 5}
    utf-8    \uD7FF ED9FBF {} {Unicode Table 3.7 Row 5}
    utf-8    \uE000 EE8080 {} {Unicode Table 3.7 Row 6}
    utf-8    \uFFFF EFBFBF {} {Unicode Table 3.7 Row 6}
    utf-8    \U10000 F0908080 {} {Unicode Table 3.7 Row 7}
    utf-8    \U3FFFF F0BFBFBF {} {Unicode Table 3.7 Row 7}
    utf-8    \U40000 F1808080 {} {Unicode Table 3.7 Row 8}
    utf-8    \UFFFFF F3BFBFBF {} {Unicode Table 3.7 Row 8}
    utf-8    \U100000 F4808080 {} {Unicode Table 3.7 Row 9}
    utf-8    \U10FFFF F48FBFBF {} {Unicode Table 3.7 Row 9}
    utf-8    A\u03A9\u8A9E\U00010384 41CEA9E8AA9EF0908E84 {} {Unicode 2.5}

    utf-16le \u0000 0000 {} {Lowest code unit}
    utf-16le \uD7FF FFD7 {} {Below high surrogate range}
    utf-16le \uE000 00E0 {} {Above low surrogate range}
    utf-16le \uFFFF FFFF {} {Highest code unit}
    utf-16le \U010000 00D800DC {} {First surrogate pair}
    utf-16le \U10FFFF FFDBFFDF {} {First surrogate pair}
    utf-16le A\u03A9\u8A9E\U00010384 4100A9039E8A00D884DF {} {Unicode 2.5}

    utf-16be \u0000 0000 {} {Lowest code unit}
    utf-16be \uD7FF D7FF {} {Below high surrogate range}
    utf-16be \uE000 E000 {} {Above low surrogate range}
    utf-16be \uFFFF FFFF {} {Highest code unit}
    utf-16be \U010000 D800DC00 {} {First surrogate pair}
    utf-16be \U10FFFF DBFFDFFF {} {First surrogate pair}
    utf-16be A\u03A9\u8A9E\U00010384 004103A98A9ED800DF84 {} {Unicode 2.5}

    utf-32le \u0000 00000000 {} {Lowest code unit}
    utf-32le \uFFFF FFFF0000 {} {Highest BMP}
    utf-32le \U010000 00000100 {} {First supplementary}
    utf-32le \U10FFFF ffff1000 {} {Last supplementary}
    utf-32le A\u03A9\u8A9E\U00010384 41000000A90300009E8A000084030100 {} {Unicode 2.5}

    utf-32be \u0000 00000000 {} {Lowest code unit}
    utf-32be \uFFFF 0000FFFF {} {Highest BMP}
    utf-32be \U010000 00010000 {} {First supplementary}
    utf-32be \U10FFFF 0010FFFF {} {Last supplementary}
    utf-32be A\u03A9\u8A9E\U00010384 00000041000003A900008A9E00010384 {} {Unicode 2.5}
}

# encInvalidBytes - Table of invalid byte sequences
# These are byte sequences that should appear for an encoding. Each row is
# of the form
#    <ENCODING BYTES PROFILE EXPECTEDRESULT EXPECTEDFAILINDEX CTRL COMMENT>
# The triple <ENCODING,BYTES,PROFILE> should be unique for test ids to be
# unique. BYTES is a byte sequence that is invalid. EXPECTEDRESULT is the
# expected string when the bytes are decoded using the PROFILE profile.
# FAILINDEX gives the expected index of the invalid byte under that profile. The
# CTRL field is a list that controls test generation. It may contain zero or
# more of `solo`, `lead`, `tail` and `middle` indicating that the generated the
# tail of a longer and in the middle of a longer string. If empty, it is treated
# as containing all four of the above. The CTRL field may also contain the words
# knownBug or knownW3C which will cause the test generation for that vector to
# be skipped.
#
# utf-32 missing because they are automatically generated based on le/be
# versions.
set encInvalidBytes {}; # Reset the table

# ascii - Any byte above 127 is invalid and is mapped
# to the same numeric code point except for the range
# 80-9F which is treated as cp1252.
# This tests the TableToUtfProc code path.
lappend encInvalidBytes {*}{
    ascii 80 tcl8    \u20AC -1 {} {map to cp1252}
    ascii 80 replace \uFFFD -1 {} {Smallest invalid byte}
    ascii 80 strict  {}      0 {} {Smallest invalid byte}
    ascii 81 tcl8    \u0081 -1 {} {map to cp1252}
    ascii 82 tcl8    \u201A -1 {} {map to cp1252}
    ascii 83 tcl8    \u0192 -1 {} {map to cp1252}
    ascii 84 tcl8    \u201E -1 {} {map to cp1252}
    ascii 85 tcl8    \u2026 -1 {} {map to cp1252}
    ascii 86 tcl8    \u2020 -1 {} {map to cp1252}
    ascii 87 tcl8    \u2021 -1 {} {map to cp1252}
    ascii 88 tcl8    \u02C6 -1 {} {map to cp1252}
    ascii 89 tcl8    \u2030 -1 {} {map to cp1252}
    ascii 8A tcl8    \u0160 -1 {} {map to cp1252}
    ascii 8B tcl8    \u2039 -1 {} {map to cp1252}
    ascii 8C tcl8    \u0152 -1 {} {map to cp1252}
    ascii 8D tcl8    \u008D -1 {} {map to cp1252}
    ascii 8E tcl8    \u017D -1 {} {map to cp1252}
    ascii 8F tcl8    \u008F -1 {} {map to cp1252}
    ascii 90 tcl8    \u0090 -1 {} {map to cp1252}
    ascii 91 tcl8    \u2018 -1 {} {map to cp1252}
    ascii 92 tcl8    \u2019 -1 {} {map to cp1252}
    ascii 93 tcl8    \u201C -1 {} {map to cp1252}
    ascii 94 tcl8    \u201D -1 {} {map to cp1252}
    ascii 95 tcl8    \u2022 -1 {} {map to cp1252}
    ascii 96 tcl8    \u2013 -1 {} {map to cp1252}
    ascii 97 tcl8    \u2014 -1 {} {map to cp1252}
    ascii 98 tcl8    \u02DC -1 {} {map to cp1252}
    ascii 99 tcl8    \u2122 -1 {} {map to cp1252}
    ascii 9A tcl8    \u0161 -1 {} {map to cp1252}
    ascii 9B tcl8    \u203A -1 {} {map to cp1252}
    ascii 9C tcl8    \u0153 -1 {} {map to cp1252}
    ascii 9D tcl8    \u009D -1 {} {map to cp1252}
    ascii 9E tcl8    \u017E -1 {} {map to cp1252}
    ascii 9F tcl8    \u0178 -1 {} {map to cp1252}

    ascii FF tcl8    \u00FF -1 {} {Largest invalid byte}
    ascii FF replace \uFFFD -1 {} {Largest invalid byte}
    ascii FF strict  {}      0 {} {Largest invalid byte}
}

# utf-8 - valid sequences based on Table 3.7 in the Unicode
# standard.
#
# Code Points        First   Second  Third   Fourth Byte
# U+0000..U+007F     00..7F
# U+0080..U+07FF     C2..DF  80..BF
# U+0800..U+0FFF     E0      A0..BF  80..BF
# U+1000..U+CFFF     E1..EC  80..BF  80..BF
# U+D000..U+D7FF     ED      80..9F  80..BF
# U+E000..U+FFFF     EE..EF  80..BF  80..BF
# U+10000..U+3FFFF   F0      90..BF  80..BF  80..BF
# U+40000..U+FFFFF   F1..F3  80..BF  80..BF  80..BF
# U+100000..U+10FFFF F4      80..8F  80..BF  80..BF
#
# Tests below are based on the "gaps" in the above table. Note ascii test
# values are repeated because internally a different code path is used
# (UtfToUtfProc).
# Note C0, C1, F5:FF are invalid bytes ANYWHERE. Exception is C080
lappend encInvalidBytes {*}{
    utf-8 80 tcl8    \u20AC -1 {} {map to cp1252}
    utf-8 80 replace \uFFFD -1 {} {Smallest invalid byte}
    utf-8 80 strict  {}      0 {} {Smallest invalid byte}
    utf-8 81 tcl8    \u0081 -1 {} {map to cp1252}
    utf-8 82 tcl8    \u201A -1 {} {map to cp1252}
    utf-8 83 tcl8    \u0192 -1 {} {map to cp1252}
    utf-8 84 tcl8    \u201E -1 {} {map to cp1252}
    utf-8 85 tcl8    \u2026 -1 {} {map to cp1252}
    utf-8 86 tcl8    \u2020 -1 {} {map to cp1252}
    utf-8 87 tcl8    \u2021 -1 {} {map to cp1252}
    utf-8 88 tcl8    \u02C6 -1 {} {map to cp1252}
    utf-8 89 tcl8    \u2030 -1 {} {map to cp1252}
    utf-8 8A tcl8    \u0160 -1 {} {map to cp1252}
    utf-8 8B tcl8    \u2039 -1 {} {map to cp1252}
    utf-8 8C tcl8    \u0152 -1 {} {map to cp1252}
    utf-8 8D tcl8    \u008D -1 {} {map to cp1252}
    utf-8 8E tcl8    \u017D -1 {} {map to cp1252}
    utf-8 8F tcl8    \u008F -1 {} {map to cp1252}
    utf-8 90 tcl8    \u0090 -1 {} {map to cp1252}
    utf-8 91 tcl8    \u2018 -1 {} {map to cp1252}
    utf-8 92 tcl8    \u2019 -1 {} {map to cp1252}
    utf-8 93 tcl8    \u201C -1 {} {map to cp1252}
    utf-8 94 tcl8    \u201D -1 {} {map to cp1252}
    utf-8 95 tcl8    \u2022 -1 {} {map to cp1252}
    utf-8 96 tcl8    \u2013 -1 {} {map to cp1252}
    utf-8 97 tcl8    \u2014 -1 {} {map to cp1252}
    utf-8 98 tcl8    \u02DC -1 {} {map to cp1252}
    utf-8 99 tcl8    \u2122 -1 {} {map to cp1252}
    utf-8 9A tcl8    \u0161 -1 {} {map to cp1252}
    utf-8 9B tcl8    \u203A -1 {} {map to cp1252}
    utf-8 9C tcl8    \u0153 -1 {} {map to cp1252}
    utf-8 9D tcl8    \u009D -1 {} {map to cp1252}
    utf-8 9E tcl8    \u017E -1 {} {map to cp1252}
    utf-8 9F tcl8    \u0178 -1 {} {map to cp1252}

    utf-8 C0 tcl8    \u00C0 -1 {} {C0 is invalid anywhere}
    utf-8 C0 strict  {}      0 {} {C0 is invalid anywhere}
    utf-8 C0 replace \uFFFD -1 {} {C0 is invalid anywhere}
    utf-8 C080 tcl8    \u0000 -1 {} {C080 -> U+0 in Tcl's internal modified UTF8}
    utf-8 C080 strict  {}      0 {} {C080 -> invalid}
    utf-8 C080 replace \uFFFD -1 {} {C080 -> single replacement char}
    utf-8 C0A2 tcl8    \u00C0\u00A2 -1 {} {websec.github.io - A}
    utf-8 C0A2 replace \uFFFD\uFFFD -1 {} {websec.github.io - A}
    utf-8 C0A2 strict  {}            0 {} {websec.github.io - A}
    utf-8 C0A7 tcl8    \u00C0\u00A7 -1 {} {websec.github.io - double quote}
    utf-8 C0A7 replace \uFFFD\uFFFD -1 {} {websec.github.io - double quote}
    utf-8 C0A7 strict  {}            0 {} {websec.github.io - double quote}
    utf-8 C0AE tcl8    \u00C0\u00AE -1 {} {websec.github.io - full stop}
    utf-8 C0AE replace \uFFFD\uFFFD -1 {} {websec.github.io - full stop}
    utf-8 C0AE strict  {}            0 {} {websec.github.io - full stop}
    utf-8 C0AF tcl8    \u00C0\u00AF -1 {} {websec.github.io - solidus}
    utf-8 C0AF replace \uFFFD\uFFFD -1 {} {websec.github.io - solidus}
    utf-8 C0AF strict  {}            0 {} {websec.github.io - solidus}

    utf-8 C1 tcl8    \u00C1 -1 {} {C1 is invalid everywhere}
    utf-8 C1 replace \uFFFD -1 {} {C1 is invalid everywhere}
    utf-8 C1 strict  {}      0 {} {C1 is invalid everywhere}
    utf-8 C181 tcl8    \u00C1\u0081 -1 {} {websec.github.io - base test (A)}
    utf-8 C181 replace \uFFFD\uFFFD -1 {} {websec.github.io - base test (A)}
    utf-8 C181 strict  {}            0 {} {websec.github.io - base test (A)}
    utf-8 C19C tcl8    \u00C1\u0153 -1 {} {websec.github.io - reverse solidus}
    utf-8 C19C replace \uFFFD\uFFFD -1 {} {websec.github.io - reverse solidus}
    utf-8 C19C strict  {}            0 {} {websec.github.io - reverse solidus}

    utf-8 C2 tcl8      \u00C2     -1 {} {Missing trail byte}
    utf-8 C2 replace   \uFFFD     -1 {} {Missing trail byte}
    utf-8 C2 strict    {}          0 {} {Missing trail byte}
    utf-8 C27F tcl8    \u00C2\x7F -1 {} {Trail byte must be 80:BF}
    utf-8 C27F replace \uFFFD\x7F -1 {} {Trail byte must be 80:BF}
    utf-8 C27F strict  {}          0 {} {Trail byte must be 80:BF}
    utf-8 DF tcl8      \u00DF     -1 {} {Missing trail byte}
    utf-8 DF replace   \uFFFD     -1 {} {Missing trail byte}
    utf-8 DF strict    {}          0 {} {Missing trail byte}
    utf-8 DF7F tcl8    \u00DF\x7F -1 {} {Trail byte must be 80:BF}
    utf-8 DF7F replace \uFFFD\x7F -1 {} {Trail byte must be 80:BF}
    utf-8 DF7F strict  {}          0 {} {Trail byte must be 80:BF}
    utf-8 DFE0A080 tcl8    \u00DF\u0800 -1 {} {Invalid trail byte is start of valid sequence}
    utf-8 DFE0A080 replace \uFFFD\u0800 -1 {} {Invalid trail byte is start of valid sequence}
    utf-8 DFE0A080 strict  {}            0 {} {Invalid trail byte is start of valid sequence}

    utf-8 E0 tcl8      \u00E0     -1 {} {Missing trail byte}
    utf-8 E0 replace   \uFFFD     -1 {} {Missing trail byte}
    utf-8 E0 strict    {}          0 {} {Missing trail byte}
    utf-8 E080 tcl8      \u00E0\u20AC   -1 {} {First trail byte must be A0:BF}
    utf-8 E080 replace   \uFFFD\uFFFD   -1 {} {First trail byte must be A0:BF}
    utf-8 E080 strict    {}              0 {} {First trail byte must be A0:BF}
    utf-8 E0819C tcl8    \u00E0\u0081\u0153 -1 {} {websec.github.io - reverse solidus}
    utf-8 E0819C replace \uFFFD\uFFFD\uFFFD -1 {} {websec.github.io - reverse solidus}
    utf-8 E0819C strict  {}                  0 {} {websec.github.io - reverse solidus}
    utf-8 E09F tcl8      \u00E0\u0178   -1 {} {First trail byte must be A0:BF}
    utf-8 E09F replace   \uFFFD\uFFFD   -1 {} {First trail byte must be A0:BF}
    utf-8 E09F strict    {}              0 {} {First trail byte must be A0:BF}
    utf-8 E0A0 tcl8      \u00E0\u00A0   -1 {} {Missing second trail byte}
    utf-8 E0A0 replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 E0A0 strict    {}              0 {} {Missing second trail byte}
    utf-8 E0BF tcl8      \u00E0\u00BF   -1 {} {Missing second trail byte}
    utf-8 E0BF replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 E0BF strict    {}              0 {} {Missing second trail byte}
    utf-8 E0A07F tcl8    \u00E0\u00A0\x7F   -1 {}     {Second trail byte must be 80:BF}
    utf-8 E0A07F replace \uFFFD\u7F         -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 E0A07F strict  {}                  0 {}         {Second trail byte must be 80:BF}
    utf-8 E0BF7F tcl8    \u00E0\u00BF\x7F   -1 {}         {Second trail byte must be 80:BF}
    utf-8 E0BF7F replace \uFFFD\u7F         -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 E0BF7F strict  {}                  0 {}         {Second trail byte must be 80:BF}

    utf-8 E1 tcl8      \u00E1     -1 {} {Missing trail byte}
    utf-8 E1 replace   \uFFFD     -1 {} {Missing trail byte}
    utf-8 E1 strict    {}          0 {} {Missing trail byte}
    utf-8 E17F tcl8    \u00E1\x7F -1 {} {Trail byte must be 80:BF}
    utf-8 E17F replace \uFFFD\x7F -1 {} {Trail byte must be 80:BF}
    utf-8 E17F strict  {}          0 {} {Trail byte must be 80:BF}
    utf-8 E181 tcl8      \u00E1\u0081   -1 {} {Missing second trail byte}
    utf-8 E181 replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 E181 strict    {}              0 {} {Missing second trail byte}
    utf-8 E1BF tcl8      \u00E1\u00BF   -1 {} {Missing second trail byte}
    utf-8 E1BF replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 E1BF strict    {}              0 {} {Missing second trail byte}
    utf-8 E1807F tcl8    \u00E1\u20AC\x7F   -1 {} {Second trail byte must be 80:BF}
    utf-8 E1807F replace \uFFFD\u7F         -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 E1807F strict  {}                  0 {}         {Second trail byte must be 80:BF}
    utf-8 E1BF7F tcl8    \u00E1\u00BF\x7F   -1 {}         {Second trail byte must be 80:BF}
    utf-8 E1BF7F replace \uFFFD\u7F         -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 E1BF7F strict  {}                  0 {}         {Second trail byte must be 80:BF}
    utf-8 EC tcl8      \u00EC     -1 {} {Missing trail byte}
    utf-8 EC replace   \uFFFD     -1 {} {Missing trail byte}
    utf-8 EC strict    {}          0 {} {Missing trail byte}
    utf-8 EC7F tcl8    \u00EC\x7F -1 {} {Trail byte must be 80:BF}
    utf-8 EC7F replace \uFFFD\x7F -1 {} {Trail byte must be 80:BF}
    utf-8 EC7F strict  {}          0 {} {Trail byte must be 80:BF}
    utf-8 EC81 tcl8      \u00EC\u0081   -1 {} {Missing second trail byte}
    utf-8 EC81 replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 EC81 strict    {}              0 {} {Missing second trail byte}
    utf-8 ECBF tcl8      \u00EC\u00BF   -1 {} {Missing second trail byte}
    utf-8 ECBF replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 ECBF strict    {}              0 {} {Missing second trail byte}
    utf-8 EC807F tcl8    \u00EC\u20AC\x7F   -1 {} {Second trail byte must be 80:BF}
    utf-8 EC807F replace \uFFFD\u7F         -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 EC807F strict  {}                  0 {}         {Second trail byte must be 80:BF}
    utf-8 ECBF7F tcl8    \u00EC\u00BF\x7F   -1 {}         {Second trail byte must be 80:BF}
    utf-8 ECBF7F replace \uFFFD\u7F         -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 ECBF7F strict  {}                  0 {}         {Second trail byte must be 80:BF}

    utf-8 ED tcl8       \u00ED        -1 {} {Missing trail byte}
    utf-8 ED replace    \uFFFD        -1 {} {Missing trail byte}
    utf-8 ED strict     {}             0 {} {Missing trail byte}
    utf-8 ED7F tcl8     \u00ED\u7F    -1 {} {First trail byte must be 80:9F}
    utf-8 ED7F replace  \uFFFD\u7F    -1 {} {First trail byte must be 80:9F}
    utf-8 ED7F strict   {}             0 {} {First trail byte must be 80:9F}
    utf-8 EDA0 tcl8     \u00ED\u00A0  -1 {} {First trail byte must be 80:9F}
    utf-8 EDA0 replace  \uFFFD\uFFFD  -1 {} {First trail byte must be 80:9F}
    utf-8 EDA0 strict   {}             0 {} {First trail byte must be 80:9F}
    utf-8 ED81 tcl8      \u00ED\u0081   -1 {} {Missing second trail byte}
    utf-8 ED81 replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 ED81 strict    {}              0 {} {Missing second trail byte}
    utf-8 EDBF tcl8      \u00ED\u00BF   -1 {} {Missing second trail byte}
    utf-8 EDBF replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 EDBF strict    {}              0 {} {Missing second trail byte}
    utf-8 ED807F tcl8      \u00ED\u20AC\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 ED807F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 ED807F strict    {}                0 {}  {Second trail byte must be 80:BF}
    utf-8 ED9F7F tcl8      \u00ED\u0178\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 ED9F7F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 ED9F7F strict    {}                0 {}  {Second trail byte must be 80:BF}
    utf-8 EDA080 tcl8       \uD800          -1 {}  {High surrogate}
    utf-8 EDA080 replace    \uFFFD          -1 {}  {High surrogate}
    utf-8 EDA080 strict     {}               0 {}  {High surrogate}
    utf-8 EDAFBF tcl8       \uDBFF          -1 {}  {High surrogate}
    utf-8 EDAFBF replace    \uFFFD          -1 {}  {High surrogate}
    utf-8 EDAFBF strict     {}               0 {}  {High surrogate}
    utf-8 EDB080 tcl8       \uDC00          -1 {}  {Low surrogate}
    utf-8 EDB080 replace    \uFFFD          -1 {}  {Low surrogate}
    utf-8 EDB080 strict     {}               0 {}  {Low surrogate}
    utf-8 EDBFBF tcl8       \uDFFF          -1 {}  {Low surrogate}
    utf-8 EDBFBF replace    \uFFFD          -1 {}  {Low surrogate}
    utf-8 EDBFBF strict     {}               0 {}  {Low surrogate}
    utf-8 EDA080EDB080 tcl8 \uD800\uDC00    -1 {}  {High low surrogate pair}
    utf-8 EDA080EDB080 replace \uFFFD\uFFFD -1 {}  {High low surrogate pair}
    utf-8 EDA080EDB080 strict {}             0 {}  {High low surrogate pair}
    utf-8 EDAFBFEDBFBF tcl8 \uDBFF\uDFFF    -1 {}  {High low surrogate pair}
    utf-8 EDAFBFEDBFBF replace \uFFFD\uFFFD -1 {}  {High low surrogate pair}
    utf-8 EDAFBFEDBFBF strict {}             0 {}  {High low surrogate pair}

    utf-8 EE tcl8       \u00EE        -1 {} {Missing trail byte}
    utf-8 EE replace    \uFFFD        -1 {} {Missing trail byte}
    utf-8 EE strict     {}             0 {} {Missing trail byte}
    utf-8 EE7F tcl8     \u00EE\u7F    -1 {} {First trail byte must be 80:BF}
    utf-8 EE7F replace  \uFFFD\u7F    -1 {} {First trail byte must be 80:BF}
    utf-8 EE7F strict   {}             0 {} {First trail byte must be 80:BF}
    utf-8 EED0 tcl8     \u00EE\u00D0  -1 {} {First trail byte must be 80:BF}
    utf-8 EED0 replace  \uFFFD\uFFFD  -1 {} {First trail byte must be 80:BF}
    utf-8 EED0 strict   {}             0 {} {First trail byte must be 80:BF}
    utf-8 EE81 tcl8      \u00EE\u0081   -1 {} {Missing second trail byte}
    utf-8 EE81 replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 EE81 strict    {}              0 {} {Missing second trail byte}
    utf-8 EEBF tcl8      \u00EE\u00BF   -1 {} {Missing second trail byte}
    utf-8 EEBF replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 EEBF strict    {}              0 {} {Missing second trail byte}
    utf-8 EE807F tcl8      \u00EE\u20AC\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 EE807F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 EE807F strict    {}                0 {}  {Second trail byte must be 80:BF}
    utf-8 EEBF7F tcl8      \u00EE\u00BF\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 EEBF7F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 EEBF7F strict    {}                0 {}  {Second trail byte must be 80:BF}
    utf-8 EF tcl8       \u00EF        -1 {} {Missing trail byte}
    utf-8 EF replace    \uFFFD        -1 {} {Missing trail byte}
    utf-8 EF strict     {}             0 {} {Missing trail byte}
    utf-8 EF7F tcl8     \u00EF\u7F    -1 {} {First trail byte must be 80:BF}
    utf-8 EF7F replace  \uFFFD\u7F    -1 {} {First trail byte must be 80:BF}
    utf-8 EF7F strict   {}             0 {} {First trail byte must be 80:BF}
    utf-8 EFD0 tcl8     \u00EF\u00D0  -1 {} {First trail byte must be 80:BF}
    utf-8 EFD0 replace  \uFFFD\uFFFD  -1 {} {First trail byte must be 80:BF}
    utf-8 EFD0 strict   {}             0 {} {First trail byte must be 80:BF}
    utf-8 EF81 tcl8      \u00EF\u0081   -1 {} {Missing second trail byte}
    utf-8 EF81 replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 EF81 strict    {}              0 {} {Missing second trail byte}
    utf-8 EFBF tcl8      \u00EF\u00BF   -1 {} {Missing second trail byte}
    utf-8 EFBF replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 EFBF strict    {}              0 {} {Missing second trail byte}
    utf-8 EF807F tcl8      \u00EF\u20AC\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 EF807F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 EF807F strict    {}                0 {}  {Second trail byte must be 80:BF}
    utf-8 EFBF7F tcl8      \u00EF\u00BF\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 EFBF7F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 EFBF7F strict    {}                0 {}  {Second trail byte must be 80:BF}

    utf-8 F0 tcl8       \u00F0        -1 {} {Missing trail byte}
    utf-8 F0 replace    \uFFFD        -1 {} {Missing trail byte}
    utf-8 F0 strict     {}             0 {} {Missing trail byte}
    utf-8 F080 tcl8     \u00F0\u20AC  -1 {} {First trail byte must be 90:BF}
    utf-8 F080 replace  \uFFFD        -1 {knownW3C} {First trail byte must be 90:BF}
    utf-8 F080 strict   {}             0 {} {First trail byte must be 90:BF}
    utf-8 F08F tcl8     \u00F0\u8F    -1 {} {First trail byte must be 90:BF}
    utf-8 F08F replace  \uFFFD        -1 {knownW3C} {First trail byte must be 90:BF}
    utf-8 F08F strict   {}             0 {} {First trail byte must be 90:BF}
    utf-8 F0D0 tcl8     \u00F0\u00D0  -1 {} {First trail byte must be 90:BF}
    utf-8 F0D0 replace  \uFFFD\uFFFD  -1 {} {First trail byte must be 90:BF}
    utf-8 F0D0 strict   {}             0 {} {First trail byte must be 90:BF}
    utf-8 F090 tcl8      \u00F0\u0090   -1 {} {Missing second trail byte}
    utf-8 F090 replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 F090 strict    {}              0 {} {Missing second trail byte}
    utf-8 F0BF tcl8      \u00F0\u00BF   -1 {} {Missing second trail byte}
    utf-8 F0BF replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 F0BF strict    {}              0 {} {Missing second trail byte}
    utf-8 F0907F tcl8      \u00F0\u0090\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 F0907F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 F0907F strict    {}                0 {}  {Second trail byte must be 80:BF}
    utf-8 F0BF7F tcl8      \u00F0\u00BF\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 F0BF7F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 F0BF7F strict    {}                0 {}  {Second trail byte must be 80:BF}
    utf-8 F090BF tcl8      \u00F0\u0090\u00BF   -1 {} {Missing third trail byte}
    utf-8 F090BF replace   \uFFFD         -1 {knownW3C} {Missing third trail byte}
    utf-8 F090BF strict    {}              0 {} {Missing third trail byte}
    utf-8 F0BF81 tcl8      \u00F0\u00BF\u0081   -1 {} {Missing third trail byte}
    utf-8 F0BF81 replace   \uFFFD         -1 {knownW3C} {Missing third trail byte}
    utf-8 F0BF81 strict    {}              0 {} {Missing third trail byte}
    utf-8 F0BF807F tcl8      \u00F0\u00BF\u20AC\x7F   -1 {} {Third trail byte must be 80:BF}
    utf-8 F0BF817F replace   \uFFFD\x7F           -1 {knownW3C} {Third trail byte must be 80:BF}
    utf-8 F0BF817F strict    {}              0 {} {Third trail byte must be 80:BF}
    utf-8 F090BFD0 tcl8      \u00F0\u0090\u00BF\u00D0   -1 {} {Third trail byte must be 80:BF}
    utf-8 F090BFD0 replace   \uFFFD         -1 {knownW3C} {Third trail byte must be 80:BF}
    utf-8 F090BFD0 strict    {}              0 {} {Third trail byte must be 80:BF}

    utf-8 F1 tcl8       \u00F1        -1 {} {Missing trail byte}
    utf-8 F1 replace    \uFFFD        -1 {} {Missing trail byte}
    utf-8 F1 strict     {}             0 {} {Missing trail byte}
    utf-8 F17F tcl8     \u00F1\u7F    -1 {} {First trail byte must be 80:BF}
    utf-8 F17F replace  \uFFFD        -1 {knownW3C} {First trail byte must be 80:BF}
    utf-8 F17F strict   {}             0 {} {First trail byte must be 80:BF}
    utf-8 F1D0 tcl8     \u00F1\u00D0  -1 {} {First trail byte must be 80:BF}
    utf-8 F1D0 replace  \uFFFD\uFFFD  -1 {} {First trail byte must be 80:BF}
    utf-8 F1D0 strict   {}             0 {} {First trail byte must be 80:BF}
    utf-8 F180 tcl8      \u00F1\u20AC   -1 {} {Missing second trail byte}
    utf-8 F180 replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 F180 strict    {}              0 {} {Missing second trail byte}
    utf-8 F1BF tcl8      \u00F1\u00BF   -1 {} {Missing second trail byte}
    utf-8 F1BF replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 F1BF strict    {}              0 {} {Missing second trail byte}
    utf-8 F1807F tcl8      \u00F1\u20AC\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 F1807F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 F1807F strict    {}                0 {}  {Second trail byte must be 80:BF}
    utf-8 F1BF7F tcl8      \u00F1\u00BF\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 F1BF7F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 F1BF7F strict    {}                0 {}  {Second trail byte must be 80:BF}
    utf-8 F180BF tcl8      \u00F1\u20AC\u00BF   -1 {} {Missing third trail byte}
    utf-8 F180BF replace   \uFFFD         -1 {knownW3C} {Missing third trail byte}
    utf-8 F180BF strict    {}              0 {} {Missing third trail byte}
    utf-8 F1BF81 tcl8      \u00F1\u00BF\u0081   -1 {} {Missing third trail byte}
    utf-8 F1BF81 replace   \uFFFD         -1 {knownW3C} {Missing third trail byte}
    utf-8 F1BF81 strict    {}              0 {} {Missing third trail byte}
    utf-8 F1BF807F tcl8      \u00F1\u00BF\u20AC\x7F   -1 {} {Third trail byte must be 80:BF}
    utf-8 F1BF817F replace   \uFFFD\x7F           -1 {knownW3C} {Third trail byte must be 80:BF}
    utf-8 F1BF817F strict    {}              0 {} {Third trail byte must be 80:BF}
    utf-8 F180BFD0 tcl8      \u00F1\u20AC\u00BF\u00D0   -1 {} {Third trail byte must be 80:BF}
    utf-8 F180BFD0 replace   \uFFFD         -1 {knownW3C} {Third trail byte must be 80:BF}
    utf-8 F180BFD0 strict    {}              0 {} {Third trail byte must be 80:BF}
    utf-8 F3 tcl8       \u00F3        -1 {} {Missing trail byte}
    utf-8 F3 replace    \uFFFD        -1 {} {Missing trail byte}
    utf-8 F3 strict     {}             0 {} {Missing trail byte}
    utf-8 F37F tcl8     \u00F3\x7F    -1 {} {First trail byte must be 80:BF}
    utf-8 F37F replace  \uFFFD        -1 {knownW3C} {First trail byte must be 80:BF}
    utf-8 F37F strict   {}             0 {} {First trail byte must be 80:BF}
    utf-8 F3D0 tcl8     \u00F3\u00D0  -1 {} {First trail byte must be 80:BF}
    utf-8 F3D0 replace  \uFFFD\uFFFD  -1 {} {First trail byte must be 80:BF}
    utf-8 F3D0 strict   {}             0 {} {First trail byte must be 80:BF}
    utf-8 F380 tcl8      \u00F3\u20AC   -1 {} {Missing second trail byte}
    utf-8 F380 replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 F380 strict    {}              0 {} {Missing second trail byte}
    utf-8 F3BF tcl8      \u00F3\u00BF   -1 {} {Missing second trail byte}
    utf-8 F3BF replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 F3BF strict    {}              0 {} {Missing second trail byte}
    utf-8 F3807F tcl8      \u00F3\u20AC\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 F3807F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 F3807F strict    {}                0 {}  {Second trail byte must be 80:BF}
    utf-8 F3BF7F tcl8      \u00F3\u00BF\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 F3BF7F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 F3BF7F strict    {}                0 {}  {Second trail byte must be 80:BF}
    utf-8 F380BF tcl8      \u00F3\u20AC\u00BF   -1 {} {Missing third trail byte}
    utf-8 F380BF replace   \uFFFD         -1 {knownW3C} {Missing third trail byte}
    utf-8 F380BF strict    {}              0 {} {Missing third trail byte}
    utf-8 F3BF81 tcl8      \u00F3\u00BF\u0081   -1 {} {Missing third trail byte}
    utf-8 F3BF81 replace   \uFFFD         -1 {knownW3C} {Missing third trail byte}
    utf-8 F3BF81 strict    {}              0 {} {Missing third trail byte}
    utf-8 F3BF807F tcl8      \u00F3\u00BF\u20AC\x7F   -1 {} {Third trail byte must be 80:BF}
    utf-8 F3BF817F replace   \uFFFD\x7F           -1 {knownW3C} {Third trail byte must be 80:BF}
    utf-8 F3BF817F strict    {}              0 {} {Third trail byte must be 80:BF}
    utf-8 F380BFD0 tcl8      \u00F3\u20AC\u00BF\u00D0   -1 {} {Third trail byte must be 80:BF}
    utf-8 F380BFD0 replace   \uFFFD         -1 {knownW3C} {Third trail byte must be 80:BF}
    utf-8 F380BFD0 strict    {}              0 {} {Third trail byte must be 80:BF}

    utf-8 F4 tcl8       \u00F4        -1 {} {Missing trail byte}
    utf-8 F4 replace    \uFFFD        -1 {} {Missing trail byte}
    utf-8 F4 strict     {}             0 {} {Missing trail byte}
    utf-8 F47F tcl8     \u00F4\u7F    -1 {} {First trail byte must be 80:8F}
    utf-8 F47F replace  \uFFFD\u7F    -1 {knownW3C} {First trail byte must be 80:8F}
    utf-8 F47F strict   {}             0 {} {First trail byte must be 80:8F}
    utf-8 F490 tcl8     \u00F4\u0090  -1 {} {First trail byte must be 80:8F}
    utf-8 F490 replace  \uFFFD\uFFFD  -1 {} {First trail byte must be 80:8F}
    utf-8 F490 strict   {}             0 {} {First trail byte must be 80:8F}
    utf-8 F480 tcl8      \u00F4\u20AC   -1 {} {Missing second trail byte}
    utf-8 F480 replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 F480 strict    {}              0 {} {Missing second trail byte}
    utf-8 F48F tcl8      \u00F4\u008F   -1 {} {Missing second trail byte}
    utf-8 F48F replace   \uFFFD         -1 {knownW3C} {Missing second trail byte}
    utf-8 F48F strict    {}              0 {} {Missing second trail byte}
    utf-8 F4807F tcl8      \u00F4\u20AC\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 F4807F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 F4807F strict    {}                0 {}  {Second trail byte must be 80:BF}
    utf-8 F48F7F tcl8      \u00F4\u008F\x7F -1 {} {Second trail byte must be 80:BF}
    utf-8 F48F7F replace   \uFFFD\u7F       -1 {knownW3C} {Second trail byte must be 80:BF}
    utf-8 F48F7F strict    {}                0 {}  {Second trail byte must be 80:BF}
    utf-8 F48081 tcl8      \u00F4\u20AC\u0081   -1 {} {Missing third trail byte}
    utf-8 F48081 replace   \uFFFD         -1 {knownW3C} {Missing third trail byte}
    utf-8 F48081 strict    {}              0 {} {Missing third trail byte}
    utf-8 F48F81 tcl8      \u00F4\u008F\u0081   -1 {} {Missing third trail byte}
    utf-8 F48F81 replace   \uFFFD         -1 {knownW3C} {Missing third trail byte}
    utf-8 F48F81 strict    {}              0 {} {Missing third trail byte}
    utf-8 F481817F tcl8      \u00F4\u0081\u0081\x7F   -1 {} {Third trail byte must be 80:BF}
    utf-8 F480817F replace   \uFFFD\x7F           -1 {knownW3C} {Third trail byte must be 80:BF}
    utf-8 F480817F strict    {}              0 {} {Third trail byte must be 80:BF}
    utf-8 F48FBFD0 tcl8      \u00F4\u008F\u00BF\u00D0   -1 {} {Third trail byte must be 80:BF}
    utf-8 F48FBFD0 replace   \uFFFD         -1 {knownW3C} {Third trail byte must be 80:BF}
    utf-8 F48FBFD0 strict    {}              0 {} {Third trail byte must be 80:BF}

    utf-8 F5 tcl8    \u00F5 -1 {} {F5:FF are invalid everywhere}
    utf-8 F5 replace \uFFFD -1 {} {F5:FF are invalid everywhere}
    utf-8 F5 strict  {}      0 {} {F5:FF are invalid everywhere}
    utf-8 FF tcl8    \u00FF -1 {} {F5:FF are invalid everywhere}
    utf-8 FF replace \uFFFD -1 {} {F5:FF are invalid everywhere}
    utf-8 FF strict  {}      0 {} {F5:FF are invalid everywhere}

    utf-8 C0AFE080BFF0818130 replace \uFFFD\uFFFD\uFFFD\uFFFD\uFFFD\uFFFD\uFFFD\uFFFD\x30 -1 {} {Unicode Table 3-8}
    utf-8 EDA080EDBFBFEDAF30 replace \uFFFD\uFFFD\uFFFD\uFFFD\uFFFD\uFFFD\uFFFD\uFFFD\x30 -1 {knownW3C} {Unicode Table 3-9}
    utf-8 F4919293FF4180BF30 replace \uFFFD\uFFFD\uFFFD\uFFFD\uFFFD\u0041\uFFFD\uFFFD\x30 -1 {} {Unicode Table 3-10}
    utf-8 E180E2F09192F1BF30 replace \uFFFD\uFFFD\uFFFD\uFFFD\x30                         -1 {knownW3C} {Unicode Table 3.11}
}

# utf16-le and utf16-be test cases. Note utf16 cases are automatically generated
# based on these depending on platform endianness. Note truncated tests can only
# happen when the sequence is at the end (including by itself) Thus {solo tail}
# in some cases.
lappend encInvalidBytes {*}{
    utf-16le 41      tcl8      \uFFFD -1 {solo tail} {Truncated}
    utf-16le 41      replace   \uFFFD -1 {solo tail} {Truncated}
    utf-16le 41      strict    {}      0 {solo tail} {Truncated}
    utf-16le 00D8    tcl8      \uD800 -1 {} {Missing low surrogate}
    utf-16le 00D8    replace   \uFFFD -1 {} {Missing low surrogate}
    utf-16le 00D8    strict    {}      0 {} {Missing low surrogate}
    utf-16le 00DC    tcl8      \uDC00 -1 {} {Missing high surrogate}
    utf-16le 00DC    replace   \uFFFD -1 {} {Missing high surrogate}
    utf-16le 00DC    strict    {}      0 {} {Missing high surrogate}

    utf-16be 41      tcl8      \uFFFD -1 {solo tail} {Truncated}
    utf-16be 41      replace   \uFFFD -1 {solo tail} {Truncated}
    utf-16be 41      strict    {}      0 {solo tail} {Truncated}
    utf-16be D800    tcl8      \uD800 -1 {} {Missing low surrogate}
    utf-16be D800    replace   \uFFFD -1 {} {Missing low surrogate}
    utf-16be D800    strict    {}      0 {} {Missing low surrogate}
    utf-16be DC00    tcl8      \uDC00 -1 {} {Missing high surrogate}
    utf-16be DC00    replace   \uFFFD -1 {} {Missing high surrogate}
    utf-16be DC00    strict    {}      0 {} {Missing high surrogate}
}

# utf32-le and utf32-be test cases. Note utf32 cases are automatically generated
# based on these depending on platform endianness. Note truncated tests can only
# happen when the sequence is at the end (including by itself) Thus {solo tail}
# in some cases.
lappend encInvalidBytes {*}{
    utf-32le 41      tcl8      \uFFFD  -1 {solo tail} {Truncated}
    utf-32le 41      replace   \uFFFD  -1 {solo} {Truncated}
    utf-32le 41      strict    {}   0 {solo tail} {Truncated}
    utf-32le 4100    tcl8      \uFFFD  -1 {solo tail} {Truncated}
    utf-32le 4100    replace   \uFFFD  -1 {solo} {Truncated}
    utf-32le 4100    strict    {}   0 {solo tail} {Truncated}
    utf-32le 410000  tcl8      \uFFFD  -1 {solo tail} {Truncated}
    utf-32le 410000  replace   \uFFFD  -1 {solo} {Truncated}
    utf-32le 410000  strict    {}       0 {solo tail} {Truncated}
    utf-32le 00D80000 tcl8     \uD800   -1 {} {High-surrogate}
    utf-32le 00D80000 replace  \uFFFD   -1 {} {High-surrogate}
    utf-32le 00D80000 strict   {}        0 {} {High-surrogate}
    utf-32le 00DC0000 tcl8     \uDC00   -1 {} {Low-surrogate}
    utf-32le 00DC0000 replace  \uFFFD   -1 {} {Low-surrogate}
    utf-32le 00DC0000 strict   {}        0 {} {Low-surrogate}
    utf-32le 00D8000000DC0000 tcl8 \uD800\uDC00    -1 {} {High-low-surrogate-pair}
    utf-32le 00D8000000DC0000 replace \uFFFD\uFFFD -1 {} {High-low-surrogate-pair}
    utf-32le 00D8000000DC0000 strict  {}            0 {} {High-low-surrogate-pair}
    utf-32le 00001100 tcl8 \uFFFD    -1 {} {Out of range}
    utf-32le 00001100 replace \uFFFD -1 {} {Out of range}
    utf-32le 00001100 strict {}       0 {} {Out of range}
    utf-32le FFFFFFFF tcl8 \uFFFD    -1 {} {Out of range}
    utf-32le FFFFFFFF replace \uFFFD -1 {} {Out of range}
    utf-32le FFFFFFFF strict {}       0 {} {Out of range}

    utf-32be 41      tcl8      \uFFFD  -1 {solo tail} {Truncated}
    utf-32be 41      replace   \uFFFD  -1 {solo tail} {Truncated}
    utf-32be 41      strict    {}       0 {solo tail} {Truncated}
    utf-32be 0041    tcl8      \uFFFD  -1 {solo tail} {Truncated}
    utf-32be 0041    replace   \uFFFD  -1 {solo} {Truncated}
    utf-32be 0041    strict    {}   0 {solo tail} {Truncated}
    utf-32be 000041  tcl8      \uFFFD  -1 {solo tail} {Truncated}
    utf-32be 000041  replace   \uFFFD  -1 {solo} {Truncated}
    utf-32be 000041  strict    {}       0 {solo tail} {Truncated}
    utf-32be 0000D800 tcl8     \uD800   -1 {} {High-surrogate}
    utf-32be 0000D800 replace  \uFFFD   -1 {} {High-surrogate}
    utf-32be 0000D800 strict   {}        0 {} {High-surrogate}
    utf-32be 0000DC00 tcl8     \uDC00   -1 {} {Low-surrogate}
    utf-32be 0000DC00 replace  \uFFFD   -1 {} {Low-surrogate}
    utf-32be 0000DC00 strict   {}        0 {} {Low-surrogate}
    utf-32be 0000D8000000DC00 tcl8 \uD800\uDC00    -1 {} {High-low-surrogate-pair}
    utf-32be 0000D8000000DC00 replace \uFFFD\uFFFD -1 {} {High-low-surrogate-pair}
    utf-32be 0000D8000000DC00 strict  {}            0 {} {High-low-surrogate-pair}
    utf-32be 00110000 tcl8 \uFFFD    -1 {} {Out of range}
    utf-32be 00110000 replace \uFFFD -1 {} {Out of range}
    utf-32be 00110000 strict {}       0 {} {Out of range}
    utf-32be FFFFFFFF tcl8 \uFFFD    -1 {} {Out of range}
    utf-32be FFFFFFFF replace \uFFFD -1 {} {Out of range}
    utf-32be FFFFFFFF strict {}       0 {} {Out of range}
}

# Strings that cannot be encoded for specific encoding / profiles
# <ENCODING STRING PROFILE EXPECTEDRESULT EXPECTEDFAILINDEX CTRL COMMENT>
# <ENCODING,STRING,PROFILE> should be unique for test ids to be unique.
# See earlier comments about CTRL field.
#
# Note utf-16, utf-32 missing because they are automatically
# generated based on le/be versions.
# TODO - out of range code point (note cannot be generated by \U notation)
lappend encUnencodableStrings {*}{
    ascii \u00e0 tcl8    3f -1 {} {unencodable}
    ascii \u00e0 strict  {}  0 {} {unencodable}

    iso8859-1 \u0141 tcl8    3f -1 {} unencodable
    iso8859-1 \u0141 strict  {}  0 {} unencodable

    utf-8 \uD800 tcl8    eda080 -1 {} Low-surrogate
    utf-8 \uD800 replace efbfbd -1 {} Low-surrogate
    utf-8 \uD800 strict  {}      0 {} Low-surrogate
    utf-8 \uDC00 tcl8    edb080 -1 {} High-surrogate
    utf-8 \uDC00 strict  {}      0 {} High-surrogate
    utf-8 \uDC00 replace efbfbd -1 {} High-surrogate
}


# The icuUcmTests.tcl is generated by the tools/ucm2tests.tcl script
# and generates test vectors for the above tables for various encodings
# based on ICU UCM files.
# TODO - commented out for now as generating a lot of mismatches.
# source [file join [file dirname [info script]] icuUcmTests.tcl]
