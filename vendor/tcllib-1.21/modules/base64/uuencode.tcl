# uuencode - Copyright (C) 2002 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# Provide a Tcl only implementation of uuencode and uudecode.
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require Tcl 8.2;                # tcl minimum version

# Try and get some compiled helper package.
if {[catch {package require tcllibc}]} {
    catch {package require Trf}
}

namespace eval ::uuencode {
    namespace export encode decode uuencode uudecode
}

proc ::uuencode::Enc {c} {
    return [format %c [expr {($c != 0) ? (($c & 0x3f) + 0x20) : 0x60}]]
}

proc ::uuencode::Encode {s} {
    set r {}
    binary scan $s c* d
    foreach {c1 c2 c3} $d {
        if {$c1 == {}} {set c1 0}
        if {$c2 == {}} {set c2 0}
        if {$c3 == {}} {set c3 0}
        append r [Enc [expr {$c1 >> 2}]]
        append r [Enc [expr {(($c1 << 4) & 060) | (($c2 >> 4) & 017)}]]
        append r [Enc [expr {(($c2 << 2) & 074) | (($c3 >> 6) & 003)}]]
        append r [Enc [expr {($c3 & 077)}]]
    }
    return $r
}


proc ::uuencode::Decode {s} {
    if {[string length $s] == 0} {return ""}
    set r {}
    binary scan [pad $s] c* d

    foreach {c0 c1 c2 c3} $d {
        append r [format %c [expr {((($c0-0x20)&0x3F) << 2) & 0xFF
                                   | ((($c1-0x20)&0x3F) >> 4) & 0xFF}]]
        append r [format %c [expr {((($c1-0x20)&0x3F) << 4) & 0xFF
                                   | ((($c2-0x20)&0x3F) >> 2) & 0xFF}]]
        append r [format %c [expr {((($c2-0x20)&0x3F) << 6) & 0xFF
                                   | (($c3-0x20)&0x3F) & 0xFF}]]
    }
    return $r
}

# -------------------------------------------------------------------------
# C coded version of the Encode/Decode functions for base64c package.
# -------------------------------------------------------------------------
if {[package provide critcl] != {}} {
    namespace eval ::uuencode {
        critcl::ccode {
            #include <string.h>
            static unsigned char Enc(unsigned char c) {
                return (c != 0) ? ((c & 0x3f) + 0x20) : 0x60;
            }
        }
        critcl::ccommand CEncode {dummy interp objc objv} {
            Tcl_Obj *inputPtr, *resultPtr;
            int len, rlen, xtra;
            unsigned char *input, *p, *r;

            if (objc !=  2) {
                Tcl_WrongNumArgs(interp, 1, objv, "data");
                return TCL_ERROR;
            }

            inputPtr = objv[1];
            input = Tcl_GetByteArrayFromObj(inputPtr, &len);
            if ((xtra = (3 - (len % 3))) != 3) {
                if (Tcl_IsShared(inputPtr))
                    inputPtr = Tcl_DuplicateObj(inputPtr);
                input = Tcl_SetByteArrayLength(inputPtr, len + xtra);
                memset(input + len, 0, xtra);
                len += xtra;
            }

            rlen = (len / 3) * 4;
            resultPtr = Tcl_NewObj();
            r = Tcl_SetByteArrayLength(resultPtr, rlen);
            memset(r, 0, rlen);

            for (p = input; p < input + len; p += 3) {
                char a, b, c;
                a = *p; b = *(p+1), c = *(p+2);
                *r++ = Enc(a >> 2);
                *r++ = Enc(((a << 4) & 060) | ((b >> 4) & 017));
                *r++ = Enc(((b << 2) & 074) | ((c >> 6) & 003));
                *r++ = Enc(c & 077);
            }
            Tcl_SetObjResult(interp, resultPtr);
            return TCL_OK;
        }

        critcl::ccommand CDecode {dummy interp objc objv} {
            Tcl_Obj *inputPtr, *resultPtr;
            int len, rlen, xtra;
            unsigned char *input, *p, *r;

            if (objc !=  2) {
                Tcl_WrongNumArgs(interp, 1, objv, "data");
                return TCL_ERROR;
            }

            /* if input is not mod 4, extend it with nuls */
            inputPtr = objv[1];
            input = Tcl_GetByteArrayFromObj(inputPtr, &len);
            if ((xtra = (4 - (len % 4))) != 4) {
                if (Tcl_IsShared(inputPtr))
                    inputPtr = Tcl_DuplicateObj(inputPtr);
                input = Tcl_SetByteArrayLength(inputPtr, len + xtra);
                memset(input + len, 0, xtra);
                len += xtra;
            }

            /* output will be 1/3 smaller than input and a multiple of 3 */
            rlen = (len / 4) * 3;
            resultPtr = Tcl_NewObj();
            r = Tcl_SetByteArrayLength(resultPtr, rlen);
            memset(r, 0, rlen);

            for (p = input; p < input + len; p += 4) {
                char a, b, c, d;
                a = *p; b = *(p+1), c = *(p+2), d = *(p+3);
                *r++ = (((a - 0x20) & 0x3f) << 2) | (((b - 0x20) & 0x3f) >> 4);
                *r++ = (((b - 0x20) & 0x3f) << 4) | (((c - 0x20) & 0x3f) >> 2);
                *r++ = (((c - 0x20) & 0x3f) << 6) | (((d - 0x20) & 0x3f) );
            }
            Tcl_SetObjResult(interp, resultPtr);
            return TCL_OK;
        }
    }
}

# -------------------------------------------------------------------------

# Description:
#  Permit more tolerant decoding of invalid input strings by padding to
#  a multiple of 4 bytes with nulls.
# Result:
#  Returns the input string - possibly padded with uuencoded null chars.
#
proc ::uuencode::pad {s} {
    if {[set mod [expr {[string length $s] % 4}]] != 0} {
        append s [string repeat "`" [expr {4 - $mod}]]
    }
    return $s
}

# -------------------------------------------------------------------------

# If the Trf package is available then we shall use this by default but the
# Tcllib implementations are always visible if needed (ie: for testing)
if {[info commands ::uuencode::CDecode] != {}} {
    # tcllib critcl package
    interp alias {} ::uuencode::encode {} ::uuencode::CEncode
    interp alias {} ::uuencode::decode {} ::uuencode::CDecode
} elseif {[package provide Trf] != {}} {
    proc ::uuencode::encode {s} {
        return [::uuencode -mode encode -- $s]
    }
    proc ::uuencode::decode {s} {
        return [::uuencode -mode decode -- [pad $s]]
    }
} else {
    # pure-tcl then
    interp alias {} ::uuencode::encode {} ::uuencode::Encode
    interp alias {} ::uuencode::decode {} ::uuencode::Decode
}

# -------------------------------------------------------------------------

proc ::uuencode::uuencode {args} {
    array set opts {mode 0644 filename {} name {}}
    set wrongargs "wrong \# args: should be\
            \"uuencode ?-name string? ?-mode octal?\
            (-file filename | ?--? string)\""
    while {[string match -* [lindex $args 0]]} {
        switch -glob -- [lindex $args 0] {
            -f* {
                if {[llength $args] < 2} {
                    return -code error $wrongargs
                }
                set opts(filename) [lindex $args 1]
                set args [lreplace $args 0 0]
            }
            -m* {
                if {[llength $args] < 2} {
                    return -code error $wrongargs
                }
                set opts(mode) [lindex $args 1]
                set args [lreplace $args 0 0]
            }
            -n* {
                if {[llength $args] < 2} {
                    return -code error $wrongargs
                }
                set opts(name) [lindex $args 1]
                set args [lreplace $args 0 0]
            }
            -- {
                set args [lreplace $args 0 0]
                break
            }
            default {
                return -code error "bad option [lindex $args 0]:\
                      must be -file, -mode, or -name"
            }
        }
        set args [lreplace $args 0 0]
    }

    if {$opts(name) == {}} {
        set opts(name) $opts(filename)
    }
    if {$opts(name) == {}} {
        set opts(name) "data.dat"
    }

    if {$opts(filename) != {}} {
        set f [open $opts(filename) r]
        fconfigure $f -translation binary
        set data [read $f]
        close $f
    } else {
        if {[llength $args] != 1} {
            return -code error $wrongargs
        }
        set data [lindex $args 0]
    }

    set r {}
    append r [format "begin %o %s" $opts(mode) $opts(name)] "\n"
    for {set n 0} {$n < [string length $data]} {incr n 45} {
        set s [string range $data $n [expr {$n + 44}]]
        append r [Enc [string length $s]]
        append r [encode $s] "\n"
    }
    append r "`\nend"
    return $r
}

# -------------------------------------------------------------------------
# Description:
#  Perform uudecoding of a file or data. A file may contain more than one
#  encoded data section so the result is a list where each element is a
#  three element list of the provided filename, the suggested mode and the
#  data itself.
#
proc ::uuencode::uudecode {args} {
    array set opts {mode 0644 filename {}}
    set wrongargs "wrong \# args: should be \"uudecode (-file filename | ?--? string)\""
    while {[string match -* [lindex $args 0]]} {
        switch -glob -- [lindex $args 0] {
            -f* {
                if {[llength $args] < 2} {
                    return -code error $wrongargs
                }
                set opts(filename) [lindex $args 1]
                set args [lreplace $args 0 0]
            }
            -- {
                set args [lreplace $args 0 0]
                break
            }
            default {
                return -code error "bad option [lindex $args 0]:\
                      must be -file"
            }
        }
        set args [lreplace $args 0 0]
    }

    if {$opts(filename) != {}} {
        set f [open $opts(filename) r]
        set data [read $f]
        close $f
    } else {
        if {[llength $args] != 1} {
            return -code error $wrongargs
        }
        set data [lindex $args 0]
    }

    set state false
    set result {}

    foreach {line} [split $data "\n"] {
        switch -exact -- $state {
            false {
                if {[regexp {^begin ([0-7]+) ([^\s]*)} $line \
                         -> opts(mode) opts(name)]} {
                    set state true
                    set r {}
                }
            }

            true {
                if {[string match "end" $line]} {
                    set state false
                    lappend result [list $opts(name) $opts(mode) $r]
                } else {
                    scan $line %c c
                    set n [expr {($c - 0x21)}]
                    append r [string range \
                                  [decode [string range $line 1 end]] 0 $n]
                }
            }
        }
    }

    return $result
}

# -------------------------------------------------------------------------

package provide uuencode 1.1.5

# -------------------------------------------------------------------------
#
# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:

