# ascii85.tcl --
#
# Encode/Decode ascii85 for a string
#
# Copyright (c) Emiliano Gavilan
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.4

namespace eval ascii85 {
    namespace export encode encodefile decode
    # default values for encode options
    variable options
    array set options [list -wrapchar \n -maxlen 76]
}

# ::ascii85::encode --
#
#   Ascii85 encode a given string.
#
# Arguments:
#   args    ?-maxlen maxlen? ?-wrapchar wrapchar? string
#
#   If maxlen is 0, the output is not wrapped.
#
# Results:
#   A Ascii85 encoded version of $string, wrapped at $maxlen characters
#   by $wrapchar.

proc ascii85::encode {args} {
    variable options

    set alen [llength $args]
    if {$alen != 1 && $alen != 3 && $alen != 5} {
        return -code error "wrong # args:\
            should be \"[lindex [info level 0] 0]\
            ?-maxlen maxlen?\
            ?-wrapchar wrapchar? string\""
    }

    set data [lindex $args end]
    array set opts [array get options]
    array set opts [lrange $args 0 end-1]
    foreach key [array names opts] {
        if {[lsearch -exact [array names options] $key] == -1} {
            return -code error "unknown option \"$key\":\
                must be -maxlen or -wrapchar"
        }
    }

    if {![string is integer -strict $opts(-maxlen)]
        || $opts(-maxlen) < 0} {
        return -code error "expected positive integer but got\
            \"$opts(-maxlen)\""
    }

    # perform this check early
    if {[string length $data] == 0} {
        return ""
    }

    # shorten the names
    set ml $opts(-maxlen)
    set wc $opts(-wrapchar)

    # if maxlen is zero, don't wrap the output
    if {$ml == 0} {
        set wc ""
    }

    set encoded {}

    binary scan $data c* X
    set len      [llength $X]
    set rest     [expr {$len % 4}]
    set lastidx  [expr {$len - $rest - 1}]

    foreach {b1 b2 b3 b4} [lrange $X 0 $lastidx] {
        # calculate the 32 bit value
        # this is an inlined version of the [encode4bytes] proc
        # included here for performance reasons
        set val [expr {
            (  (($b1 & 0xff) << 24)
              |(($b2 & 0xff) << 16)
              |(($b3 & 0xff) << 8)
              | ($b4 & 0xff)
            ) & 0xffffffff }]

        if {$val == 0} {
            # four \0 bytes encodes as "z" instead of "!!!!!"
            append current "z"
        } else {
            # no magic numbers here.
            # 52200625 -> 85 ** 4
            # 614125   -> 85 ** 3
            # 7225     -> 85 ** 2
            append current [binary format ccccc \
                [expr { ( $val / 52200625) + 33 }] \
                [expr { (($val % 52200625) / 614125) + 33 }] \
                [expr { (($val % 614125) / 7225) + 33 }] \
                [expr { (($val % 7225) / 85) + 33 }] \
                [expr { ( $val % 85) + 33 }]]
        }

        if {[string length $current] >= $ml} {
            append encoded [string range $current 0 [expr {$ml - 1}]] $wc
            set current    [string range $current $ml end]
        }
    }

    if { $rest } {
        # there are remaining bytes.
        # pad with \0 and encode not using the "z" convention.
        # finally, add ($rest + 1) chars.
        set val 0
        foreach {b1 b2 b3 b4} [pad [lrange $X [incr lastidx] end] 4 0] break
        append current [string range [encode4bytes $b1 $b2 $b3 $b4] 0 $rest]
    }
    append encoded [regsub -all -- ".{$ml}" $current "&$wc"]

    return $encoded
}

proc ascii85::encode4bytes {b1 b2 b3 b4} {
    set val [expr {
        (  (($b1 & 0xff) << 24)
          |(($b2 & 0xff) << 16)
          |(($b3 & 0xff) << 8)
          | ($b4 & 0xff)
        ) & 0xffffffff }]
    return [binary format ccccc \
            [expr { ( $val / 52200625) + 33 }] \
            [expr { (($val % 52200625) / 614125) + 33 }] \
            [expr { (($val % 614125) / 7225) + 33 }] \
            [expr { (($val % 7225) / 85) + 33 }] \
            [expr { ( $val % 85) + 33 }]]
}

# ::ascii85::encodefile --
#
#   Ascii85 encode the contents of a file using default values
#   for maxlen and wrapchar parameters.
#
# Arguments:
#   fname    The name of the file to encode.
#
# Results:
#   An Ascii85 encoded version of the contents of the file.
#   This is a convenience command

proc ascii85::encodefile {fname} {
    set fd [open $fname]
    fconfigure $fd -encoding binary -translation binary
    return [encode [read $fd]][close $fd]
}

# ::ascii85::decode --
#
#   Ascii85 decode a given string.
#
# Arguments:
#   string      The string to decode.
# Leading spaces and tabs are removed, along with trailing newlines
#
# Results:
#   The decoded value.

proc ascii85::decode {data} {
    # get rid of leading spaces/tabs and trailing newlines
    set data [string map [list \n {} \t {} { } {}] $data]
    set len [string length $data]

    # perform this ckeck early
    if {! $len} {
        return ""
    }

    set decoded {}
    set count 0
    set group [list]
    binary scan $data c* X

    foreach char $X {
        # we must check that every char is in the allowed range
        if {$char < 33 || $char > 117 } {
            # "z" is an exception
            if {$char == 122} {
                if {$count == 0} {
                    # if a "z" char appears at the beggining of a group,
                    # it decodes as four null bytes
                    append decoded \x00\x00\x00\x00
                    continue
                } else {
                    # if not, is an error
                    return -code error \
                        "error decoding data: \"z\" char misplaced"
                }
            }
            # char is not in range and not a "z" at the beggining of a group
            return -code error \
                "error decoding data: chars outside the allowed range"
        }

        lappend group $char
        incr count
        if {$count == 5} {
            # this is an inlined version of the [decode5chars] proc
            # included here for performance reasons
            set val [expr {
                ([lindex $group 0] - 33) * wide(52200625) +
                ([lindex $group 1] - 33) * 614125 +
                ([lindex $group 2] - 33) * 7225 +
                ([lindex $group 3] - 33) * 85 +
                ([lindex $group 4] - 33) }]
            if {$val > 0xffffffff} {
                return -code error "error decoding data: decoded group overflow"
            } else {
                append decoded [binary format I $val]
                incr count -5
                set group [list]
            }
        }
    }

    set len [llength $group]
    switch -- $len {
        0 {
            # all input has been consumed
            # do nothing
        }
        1 {
            # a single char is a condition error, there should be at least 2
            return -code error \
                "error decoding data: trailing char"
        }
        default {
            # pad with "u"s, decode and add ($len - 1) bytes
            append decoded [string range \
                    [decode5chars [pad $group 5 122]] \
                    0 \
                    [expr {$len - 2}]]
        }
    }

    return $decoded
}

proc ascii85::decode5chars {group} {
    set val [expr {
        ([lindex $group 0] - 33) * wide(52200625) +
        ([lindex $group 1] - 33) * 614125 +
        ([lindex $group 2] - 33) * 7225 +
        ([lindex $group 3] - 33) * 85 +
        ([lindex $group 4] - 33) }]
    if {$val > 0xffffffff} {
        return -code error "error decoding data: decoded group overflow"
    }

    return [binary format I $val]
}

proc ascii85::pad {chars len padchar} {
    while {[llength $chars] < $len} {
        lappend chars $padchar
    }

    return $chars
}

package provide ascii85 1.0
