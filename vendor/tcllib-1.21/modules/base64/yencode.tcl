# yencode.tcl - Copyright (C) 2002 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# Provide a Tcl only implementation of yEnc encoding algorithm
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

# FUTURE: Rework to allow switching between the tcl/critcl implementations.

package require Tcl 8.2;                # tcl minimum version
catch {package require crc32};          # tcllib 1.1
catch {package require tcllibc};        # critcl enhancements for tcllib

namespace eval ::yencode {
    namespace export encode decode yencode ydecode
}

# -------------------------------------------------------------------------

proc ::yencode::Encode {s} {
    set r {}
    binary scan $s c* d
    foreach {c} $d {
        set v [expr {($c + 42) % 256}]
        if {$v == 0x00 || $v == 0x09 || $v == 0x0A
            || $v == 0x0D || $v == 0x3D} {
            append r "="
            set v [expr {($v + 64) % 256}]
        }
        append r [format %c $v]
    }
    return $r
}

proc ::yencode::Decode {s} {
    if {[string length $s] == 0} {return ""}
    set r {}
    set esc 0
    binary scan $s c* d
    foreach c $d {
        if {$c == 61 && $esc == 0} {
            set esc 1
            continue
        }
        set v [expr {($c - 42) % 256}]
        if {$esc} {
            set v [expr {($v - 64) % 256}]
            set esc 0
        }
        append r [format %c $v]
    }
    return $r
}

# -------------------------------------------------------------------------
# C coded versions for critcl built base64c package
# -------------------------------------------------------------------------

if {[package provide critcl] != {}} {
    namespace eval ::yencode {
        critcl::ccode {
            #include <string.h>
        }
        critcl::ccommand CEncode {dummy interp objc objv} {
            Tcl_Obj *inputPtr, *resultPtr;
            int len, rlen, xtra;
            unsigned char *input, *p, *r, v;

            if (objc !=  2) {
                Tcl_WrongNumArgs(interp, 1, objv, "data");
                return TCL_ERROR;
            }

            /* fetch the input data */
            inputPtr = objv[1];
            input = Tcl_GetByteArrayFromObj(inputPtr, &len);

            /* calculate the length of the encoded result */
            rlen = len;
            for (p = input; p < input + len; p++) {
                v = (*p + 42) % 256;
                if (v == 0 || v == 9 || v == 0x0A || v == 0x0D || v == 0x3D)
                   rlen++;
            }

            /* allocate the output buffer */
            resultPtr = Tcl_NewObj();
            r = Tcl_SetByteArrayLength(resultPtr, rlen);

            /* encode the input */
            for (p = input; p < input + len; p++) {
                v = (*p + 42) % 256;
                if (v == 0 || v == 9 || v == 0x0A || v == 0x0D || v == 0x3D) {
                    *r++ = '=';
                    v = (v + 64) % 256;
                }
                *r++ = v;
            }
            Tcl_SetObjResult(interp, resultPtr);
            return TCL_OK;
        }

        critcl::ccommand CDecode {dummy interp objc objv} {
            Tcl_Obj *inputPtr, *resultPtr;
            int len, rlen, esc;
            unsigned char *input, *p, *r, v;

            if (objc !=  2) {
                Tcl_WrongNumArgs(interp, 1, objv, "data");
                return TCL_ERROR;
            }

            /* fetch the input data */
            inputPtr = objv[1];
            input = Tcl_GetByteArrayFromObj(inputPtr, &len);

            /* allocate the output buffer */
            resultPtr = Tcl_NewObj();
            r = Tcl_SetByteArrayLength(resultPtr, len);

            /* encode the input */
            for (p = input, esc = 0, rlen = 0; p < input + len; p++) {
                if (*p == 61 && esc == 0) {
                    esc = 1;
                    continue;
                }
                v = (*p - 42) % 256;
                if (esc) {
                    v = (v - 64) % 256;
                    esc = 0;
                }
                *r++ = v;
                rlen++;
            }
            Tcl_SetByteArrayLength(resultPtr, rlen);
            Tcl_SetObjResult(interp, resultPtr);
            return TCL_OK;
        }
    }
}

if {[info commands ::yencode::CEncode] != {}} {
    interp alias {} ::yencode::encode {} ::yencode::CEncode
    interp alias {} ::yencode::decode {} ::yencode::CDecode
} else {
    interp alias {} ::yencode::encode {} ::yencode::Encode
    interp alias {} ::yencode::decode {} ::yencode::Decode
}

# -------------------------------------------------------------------------
# Description:
#  Pop the nth element off a list. Used in options processing.
#
proc ::yencode::Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

# -------------------------------------------------------------------------

proc ::yencode::yencode {args} {
    array set opts {mode 0644 filename {} name {} line 128 crc32 1}
    while {[string match -* [lindex $args 0]]} {
        switch -glob -- [lindex $args 0] {
            -f* { set opts(filename) [Pop args 1] }
            -m* { set opts(mode) [Pop args 1] }
            -n* { set opts(name) [Pop args 1] }
            -l* { set opts(line) [Pop args 1] }
            -c* { set opts(crc32) [Pop args 1] }
            --  { Pop args ; break }
            default {
                set options [join [lsort [array names opts]] ", -"]
                return -code error "bad option [lindex $args 0]:\
                      must be -$options"
            }
        }
        Pop args
    }

    if {$opts(name) == {}} {
        set opts(name) $opts(filename)
    }
    if {$opts(name) == {}} {
        set opts(name) "data.dat"
    }
    if {! [string is boolean $opts(crc32)]} {
        return -code error "bad option -crc32: argument must be true or false"
    }

    if {$opts(filename) != {}} {
        set f [open $opts(filename) r]
        fconfigure $f -translation binary
        set data [read $f]
        close $f
    } else {
        if {[llength $args] != 1} {
            return -code error "wrong \# args: should be\
                  \"yencode ?options? -file name | data\""
        }
        set data [lindex $args 0]
    }

    set opts(size) [string length $data]

    set r {}
    append r [format "=ybegin line=%d size=%d name=%s" \
                  $opts(line) $opts(size) $opts(name)] "\n"

    set ndx 0
    while {$ndx < $opts(size)} {
        set pln [string range $data $ndx [expr {$ndx + $opts(line) - 1}]]
        set enc [encode $pln]
        incr ndx [string length $pln]
        append r $enc "\r\n"
    }

    append r [format "=yend size=%d" $ndx]
    if {$opts(crc32)} {
        append r " crc32=" [crc::crc32 -format %x $data]
    }
    return $r
}

# -------------------------------------------------------------------------
# Description:
#  Perform ydecoding of a file or data. A file may contain more than one
#  encoded data section so the result is a list where each element is a
#  three element list of the provided filename, the file size and the
#  data itself.
#
proc ::yencode::ydecode {args} {
    array set opts {mode 0644 filename {} name default.bin}
    while {[string match -* [lindex $args 0]]} {
        switch -glob -- [lindex $args 0] {
            -f* { set opts(filename) [Pop args 1] }
            -- { Pop args ; break; }
            default {
                set options [join [lsort [array names opts]] ", -"]
                return -code error "bad option [lindex $args 0]:\
                      must be -$opts"
            }
        }
        Pop args
    }

    if {$opts(filename) != {}} {
        set f [open $opts(filename) r]
        set data [read $f]
        close $f
    } else {
        if {[llength $args] != 1} {
            return -code error "wrong \# args: should be\
                  \"ydecode ?options? -file name | data\""
        }
        set data [lindex $args 0]
    }

    set state false
    set result {}

    foreach {line} [split $data "\n"] {
        set line [string trimright $line "\r\n"]
        switch -exact -- $state {
            false {
                if {[string match "=ybegin*" $line]} {
                    regexp {line=(\d+)} $line -> opts(line)
                    regexp {size=(\d+)} $line -> opts(size)
                    regexp {name=(\d+)} $line -> opts(name)

                    if {$opts(name) == {}} {
                        set opts(name) default.bin
                    }

                    set state true
                    set r {}
                }
            }

            true {
                if {[string match "=yend*" $line]} {
                    set state false
                    lappend result [list $opts(name) $opts(size) $r]
                } else {
                    append r [decode $line]
                }
            }
        }
    }

    return $result
}

# -------------------------------------------------------------------------

package provide yencode 1.1.3

# -------------------------------------------------------------------------
#
# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:

