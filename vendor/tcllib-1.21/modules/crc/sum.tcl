# sum.tcl - Copyright (C) 2002 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# Provides a Tcl only implementation of the unix sum(1) command. There are
# a number of these and they use differing algorithms to get a checksum of
# the input data. We provide two: one using the BSD algorithm and the other
# using the SysV algorithm. More consistent results across multiple
# implementations can be obtained by using cksum(1).
#
# These commands have been checked against the GNU sum program from the GNU
# textutils package version 2.0 to ensure the same results.
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require Tcl 8.2;                # tcl minimum version

catch {package require tcllibc};        # critcl enhancements to tcllib
#catch {package require crcc};           # critcl enhanced crc module

namespace eval ::crc {
    namespace export sum

    variable uid
    if {![info exists uid]} {
        set uid 0
    }
}

# -------------------------------------------------------------------------
# Description:
#  The SysV algorithm is fairly naive. The byte values are summed and any
#  overflow is discarded. The lowest 16 bits are returned as the checksum.
# Notes:
#  Input with the same content but different ordering will give the same 
#  result.
#
proc ::crc::SumSysV {s {seed 0}} {
    set t $seed
    binary scan $s c* r
    foreach n $r {
        incr t [expr {$n & 0xFF}]
    }

    set t [expr {$t & 0xffffffff}]
    set t [expr {($t & 0xffff) + ($t >> 16)}]
    set t [expr {($t & 0xffff) + ($t >> 16)}]

    return $t
}

# -------------------------------------------------------------------------
# Description:
#  This algorithm is similar to the SysV version but includes a bit rotation
#  step which provides a dependency on the order of the data values.
#
proc ::crc::SumBsd {s {seed 0}} {
    set t $seed
    binary scan $s c* r
    foreach n $r {
        set t [expr {($t & 1) ? (($t >> 1) + 0x8000) : ($t >> 1)}]
        set t [expr {($t + ($n & 0xFF)) & 0xFFFF}]
    }
    return $t
}

# -------------------------------------------------------------------------

if {[package provide critcl] != {}} {
    namespace eval ::crc {
        critcl::ccommand SumSysV_c {dummy interp objc objv} {
            int r = TCL_OK;
            unsigned int t = 0;

            if (objc < 2 || objc > 3) {
                Tcl_WrongNumArgs(interp, 1, objv, "data ?seed?");
                return TCL_ERROR;
            }
            
            if (objc == 3)
                r = Tcl_GetIntFromObj(interp, objv[2], (int *)&t);

            if (r == TCL_OK) {
                int cn, size;
                unsigned char *data;

                data = Tcl_GetByteArrayFromObj(objv[1], &size);
                for (cn = 0; cn < size; cn++)
                    t += data[cn];
            }

            t = t & 0xffffffffLU;
            t = (t & 0xffff) + (t >> 16);
            t = (t & 0xffff) + (t >> 16);

            Tcl_SetObjResult(interp, Tcl_NewIntObj(t));
            return r;
        }

        critcl::ccommand SumBsd_c {dummy interp objc objv} {
            int r = TCL_OK;
            unsigned int t = 0;

            if (objc < 2 || objc > 3) {
                Tcl_WrongNumArgs(interp, 1, objv, "data ?seed?");
                return TCL_ERROR;
            }
            
            if (objc == 3)
                r = Tcl_GetIntFromObj(interp, objv[2], (int *)&t);

            if (r == TCL_OK) {
                int cn, size;
                unsigned char *data;

                data = Tcl_GetByteArrayFromObj(objv[1], &size);
                for (cn = 0; cn < size; cn++) {
                    t = (t & 1) ? ((t >> 1) + 0x8000) : (t >> 1);
                    t = (t + data[cn]) & 0xFFFF;
                }
            }

            Tcl_SetObjResult(interp, Tcl_NewIntObj(t & 0xFFFF));
            return r;
        }
    }
}

# -------------------------------------------------------------------------
# Switch from pure tcl to compiled if available.
#
if {[info commands ::crc::SumBsd_c] == {}} {
    interp alias {} ::crc::sum-bsd  {} ::crc::SumBsd
} else {
    interp alias {} ::crc::sum-bsd  {} ::crc::SumBsd_c
}

if {[info commands ::crc::SumSysV_c] == {}} {
    interp alias {} ::crc::sum-sysv {} ::crc::SumSysV
} else {
    interp alias {} ::crc::sum-sysv {} ::crc::SumSysV_c
}

# -------------------------------------------------------------------------
# Description:
#  Pop the nth element off a list. Used in options processing.
#
proc ::crc::Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

# -------------------------------------------------------------------------
# timeout handler for the chunked file handling
# This avoids us waiting for ever
#
proc ::crc::SumTimeout {token} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state
    set state(error) "operation timed out"
    set state(reading) 0
}

# -------------------------------------------------------------------------
# fileevent handler for chunked file handling.
#
proc ::crc::SumChunk {token channel} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state
    
    if {[eof $channel]} {
        fileevent $channel readable {}
        set state(reading) 0
    }
    
    after cancel $state(after)
    set state(after) [after $state(timeout) \
                          [list [namespace origin SumTimeout] $token]]
    set state(result) [$state(algorithm) \
                           [read $channel $state(chunksize)] \
                           $state(result)]
}

# -------------------------------------------------------------------------
# Description:
#  Provide a Tcl equivalent of the unix sum(1) command. We default to the
#  BSD algorithm and return a checkum for the input string unless a filename
#  has been provided. Using sum on a file should give the same results as
#  the unix sum command with equivalent algorithm.
# Options:
#  -bsd           - use the BSD algorithm to calculate the checksum (default)
#  -sysv          - use the SysV algorithm to calculate the checksum
#  -filename name - return a checksum for the specified file
#  -format string - return the checksum using this format string
#
proc ::crc::sum {args} {
    array set opts [list -filename {} -channel {} -chunksize 4096 \
                        -timeout 30000 -bsd 1 -sysv 0 -format %u \
                        algorithm [namespace origin sum-bsd]]
    while {[string match -* [set option [lindex $args 0]]]} {
        switch -glob -- $option {
            -bsd    { set opts(-bsd) 1 ; set opts(-sysv) 0 }
            -sysv   { set opts(-bsd) 0 ; set opts(-sysv) 1 }
            -file*  { set opts(-filename) [Pop args 1] }
            -for*   { set opts(-format) [Pop args 1] }
            -chan*  { set opts(-channel) [Pop args 1] }
            -chunk* { set opts(-chunksize) [Pop args 1] }
            -time*  { set opts(-timeout) [Pop args 1] }
            --      { Pop args ; break }
            default {
                set err [join [lsort [array names opts -*]] ", "]
                return -code error "bad option $option:\
                    must be one of $err"
            }
        }
        Pop args
    }

    # Set the correct sum algorithm
    if {$opts(-sysv)} {
        set opts(algorithm) [namespace origin sum-sysv]
    }

    # If a file was given - open it for binary reading.
    if {$opts(-filename) != {}} {
        set opts(-channel) [open $opts(-filename) r]
        fconfigure $opts(-channel) -translation binary
    }

    if {$opts(-channel) == {}} {

        if {[llength $args] != 1} {
            return -code error "wrong # args: should be \
                 \"sum ?-bsd|-sysv? ?-format string? ?-chunksize size? \
                 ?-timeout ms? -file name | -channel chan | data\""
        }
        set r [$opts(algorithm) [lindex $args 0]]

    } else {

        # Create a unique token for the event handling
        variable uid
        set token [namespace current]::[incr uid]
        upvar #0 $token tok
        array set tok [list reading 1 result 0 timeout $opts(-timeout) \
                           chunksize $opts(-chunksize) \
                           algorithm $opts(algorithm)]
        set tok(after) [after $tok(timeout) \
                            [list [namespace origin SumTimeout] $token]]

        fileevent $opts(-channel) readable \
            [list [namespace origin SumChunk] $token $opts(-channel)]
        vwait [subst $token](reading)

        # If we opened the channel we must close it too.
        if {$opts(-filename) != {}} {
            close $opts(-channel)
        }

        # Extract the result or error message if there was a problem.
        set r $tok(result)
        if {[info exists tok(error)]} {
            return -code error $tok(error)
        }

        unset tok
    }

    return [format $opts(-format) $r]
}

# -------------------------------------------------------------------------

package provide sum 1.1.2

# -------------------------------------------------------------------------    
# Local Variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
