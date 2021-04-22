# crc32.tcl -- Copyright (C) 2002 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# CRC32 Cyclic Redundancy Check. 
# (for algorithm see http://www.rad.com/networks/1994/err_con/crc.htm)
#
# From http://mini.net/tcl/2259.tcl
# Written by Wayland Augur and Pat Thoyts.
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require Tcl 8.2

namespace eval ::crc {
    variable  accel
    array set accel {critcl 0 trf 0}

    namespace export crc32

    variable crc32_tbl [list 0x00000000 0x77073096 0xEE0E612C 0x990951BA \
                           0x076DC419 0x706AF48F 0xE963A535 0x9E6495A3 \
                           0x0EDB8832 0x79DCB8A4 0xE0D5E91E 0x97D2D988 \
                           0x09B64C2B 0x7EB17CBD 0xE7B82D07 0x90BF1D91 \
                           0x1DB71064 0x6AB020F2 0xF3B97148 0x84BE41DE \
                           0x1ADAD47D 0x6DDDE4EB 0xF4D4B551 0x83D385C7 \
                           0x136C9856 0x646BA8C0 0xFD62F97A 0x8A65C9EC \
                           0x14015C4F 0x63066CD9 0xFA0F3D63 0x8D080DF5 \
                           0x3B6E20C8 0x4C69105E 0xD56041E4 0xA2677172 \
                           0x3C03E4D1 0x4B04D447 0xD20D85FD 0xA50AB56B \
                           0x35B5A8FA 0x42B2986C 0xDBBBC9D6 0xACBCF940 \
                           0x32D86CE3 0x45DF5C75 0xDCD60DCF 0xABD13D59 \
                           0x26D930AC 0x51DE003A 0xC8D75180 0xBFD06116 \
                           0x21B4F4B5 0x56B3C423 0xCFBA9599 0xB8BDA50F \
                           0x2802B89E 0x5F058808 0xC60CD9B2 0xB10BE924 \
                           0x2F6F7C87 0x58684C11 0xC1611DAB 0xB6662D3D \
                           0x76DC4190 0x01DB7106 0x98D220BC 0xEFD5102A \
                           0x71B18589 0x06B6B51F 0x9FBFE4A5 0xE8B8D433 \
                           0x7807C9A2 0x0F00F934 0x9609A88E 0xE10E9818 \
                           0x7F6A0DBB 0x086D3D2D 0x91646C97 0xE6635C01 \
                           0x6B6B51F4 0x1C6C6162 0x856530D8 0xF262004E \
                           0x6C0695ED 0x1B01A57B 0x8208F4C1 0xF50FC457 \
                           0x65B0D9C6 0x12B7E950 0x8BBEB8EA 0xFCB9887C \
                           0x62DD1DDF 0x15DA2D49 0x8CD37CF3 0xFBD44C65 \
                           0x4DB26158 0x3AB551CE 0xA3BC0074 0xD4BB30E2 \
                           0x4ADFA541 0x3DD895D7 0xA4D1C46D 0xD3D6F4FB \
                           0x4369E96A 0x346ED9FC 0xAD678846 0xDA60B8D0 \
                           0x44042D73 0x33031DE5 0xAA0A4C5F 0xDD0D7CC9 \
                           0x5005713C 0x270241AA 0xBE0B1010 0xC90C2086 \
                           0x5768B525 0x206F85B3 0xB966D409 0xCE61E49F \
                           0x5EDEF90E 0x29D9C998 0xB0D09822 0xC7D7A8B4 \
                           0x59B33D17 0x2EB40D81 0xB7BD5C3B 0xC0BA6CAD \
                           0xEDB88320 0x9ABFB3B6 0x03B6E20C 0x74B1D29A \
                           0xEAD54739 0x9DD277AF 0x04DB2615 0x73DC1683 \
                           0xE3630B12 0x94643B84 0x0D6D6A3E 0x7A6A5AA8 \
                           0xE40ECF0B 0x9309FF9D 0x0A00AE27 0x7D079EB1 \
                           0xF00F9344 0x8708A3D2 0x1E01F268 0x6906C2FE \
                           0xF762575D 0x806567CB 0x196C3671 0x6E6B06E7 \
                           0xFED41B76 0x89D32BE0 0x10DA7A5A 0x67DD4ACC \
                           0xF9B9DF6F 0x8EBEEFF9 0x17B7BE43 0x60B08ED5 \
                           0xD6D6A3E8 0xA1D1937E 0x38D8C2C4 0x4FDFF252 \
                           0xD1BB67F1 0xA6BC5767 0x3FB506DD 0x48B2364B \
                           0xD80D2BDA 0xAF0A1B4C 0x36034AF6 0x41047A60 \
                           0xDF60EFC3 0xA867DF55 0x316E8EEF 0x4669BE79 \
                           0xCB61B38C 0xBC66831A 0x256FD2A0 0x5268E236 \
                           0xCC0C7795 0xBB0B4703 0x220216B9 0x5505262F \
                           0xC5BA3BBE 0xB2BD0B28 0x2BB45A92 0x5CB36A04 \
                           0xC2D7FFA7 0xB5D0CF31 0x2CD99E8B 0x5BDEAE1D \
                           0x9B64C2B0 0xEC63F226 0x756AA39C 0x026D930A \
                           0x9C0906A9 0xEB0E363F 0x72076785 0x05005713 \
                           0x95BF4A82 0xE2B87A14 0x7BB12BAE 0x0CB61B38 \
                           0x92D28E9B 0xE5D5BE0D 0x7CDCEFB7 0x0BDBDF21 \
                           0x86D3D2D4 0xF1D4E242 0x68DDB3F8 0x1FDA836E \
                           0x81BE16CD 0xF6B9265B 0x6FB077E1 0x18B74777 \
                           0x88085AE6 0xFF0F6A70 0x66063BCA 0x11010B5C \
                           0x8F659EFF 0xF862AE69 0x616BFFD3 0x166CCF45 \
                           0xA00AE278 0xD70DD2EE 0x4E048354 0x3903B3C2 \
                           0xA7672661 0xD06016F7 0x4969474D 0x3E6E77DB \
                           0xAED16A4A 0xD9D65ADC 0x40DF0B66 0x37D83BF0 \
                           0xA9BCAE53 0xDEBB9EC5 0x47B2CF7F 0x30B5FFE9 \
                           0xBDBDF21C 0xCABAC28A 0x53B39330 0x24B4A3A6 \
                           0xBAD03605 0xCDD70693 0x54DE5729 0x23D967BF \
                           0xB3667A2E 0xC4614AB8 0x5D681B02 0x2A6F2B94 \
                           0xB40BBE37 0xC30C8EA1 0x5A05DF1B 0x2D02EF8D]

    # calculate the sign bit for the current platform.
    variable signbit
    if {![info exists signbit]} {
        if {[info exists tcl_platform(wordSize)]} {
            set signbit [expr {1 << (8*$tcl_platform(wordSize)-1)}]
        } else {
            # Old Tcl. Find bit by shifting until wrap around to 0.
            # With int() result limited to system word size the loop will end.
            variable v
            for {set v 1} {int($v) != 0} {set signbit $v; set v [expr {$v<<1}]} {}
            unset v
        }
    }
    
    variable uid ; if {![info exists uid]} {set uid 0}
}

# -------------------------------------------------------------------------

# crc::Crc32Init --
#
#	Create and initialize a crc32 context. This is cleaned up
#	when we we call Crc32Final to obtain the result.
#
proc ::crc::Crc32Init {{seed 0xFFFFFFFF}} {
    variable uid
    variable accel
    set token [namespace current]::[incr uid]
    upvar #0 $token state
    array set state [list sum $seed]
    # If the initial seed is set to some other value we cannot use Trf.
    if {$accel(trf) && $seed == 0xFFFFFFFF} {
        set s {}
        switch -exact -- $::tcl_platform(platform) {
            windows { set s [open NUL w] }
            unix    { set s [open /dev/null w] }
        }
        if {$s != {}} {
            fconfigure $s -translation binary -buffering none
            ::crc-zlib -attach $s -mode write \
                -write-type variable \
                -write-destination ${token}(trfwrite)
            array set state [list trfread 0 trfwrite 0 trf $s]
        }
    }
    return $token
}

# crc::Crc32Update --
#
#	This is called to add more data into the checksum. You may
#	call this as many times as you require. Note that passing in
#	"ABC" is equivalent to passing these letters in as separate
#	calls -- hence this proc permits summing of chunked data.
#
#	If we have a C-based implementation available, then we will
#	use it here in preference to the pure-Tcl implementation.
#
proc ::crc::Crc32Update {token data} {
    variable accel
    upvar #0 $token state
    set sum $state(sum)
    if {$accel(critcl)} {
        set sum [Crc32_c $data $sum]
    } elseif {[info exists state(trf)]} {
        puts -nonewline $state(trf) $data
        return
    } else {
        set sum [Crc32_tcl $data $sum]
    }
    set state(sum) [expr {$sum ^ 0xFFFFFFFF}]
    return
}

# crc::Crc32Final -- 
#
#	This procedure is used to close the context and returns the
#	checksum value. Once this procedure has been called the checksum
#	context is freed and cannot be used again.  
#
proc ::crc::Crc32Final {token} {
    upvar #0 $token state
    if {[info exists state(trf)]} {
        close $state(trf)
        binary scan $state(trfwrite) i sum
        set sum [expr {$sum & 0xFFFFFFFF}]
    } else {
        set sum [expr {($state(sum) ^ 0xFFFFFFFF) & 0xFFFFFFFF}]
    }
    unset state
    return $sum
}

# crc::Crc32_tcl --
#
#	The pure-Tcl implementation of a table based CRC-32 checksum.
#	The seed should always be 0xFFFFFFFF to begin with, but for
#	successive chunks of data the seed should be set to the result
#	of the last chunk.
#
proc ::crc::Crc32_tcl {data {seed 0xFFFFFFFF}} {
    variable crc32_tbl
    variable signbit
    set signmask [expr {~$signbit>>7}]
    set crcval $seed

    binary scan $data c* nums
    foreach {n} $nums {
        set ndx [expr {($crcval ^ $n) & 0xFF}]
        set lkp [lindex $crc32_tbl $ndx]
        set crcval [expr {($lkp ^ ($crcval >> 8 & $signmask)) & 0xFFFFFFFF}]
    }
    
    return [expr {$crcval ^ 0xFFFFFFFF}]
}

# crc::Crc32_c --
#
#	A C version of the CRC-32 code using the same table. This is
#	designed to be compiled using critcl.
#
if {[package provide critcl] != {}} {
    namespace eval ::crc {
        critcl::ccommand Crc32_c {dummy interp objc objv} {
            int r = TCL_OK;
            unsigned long t = 0xFFFFFFFFL;

            if (objc < 2 || objc > 3) {
                Tcl_WrongNumArgs(interp, 1, objv, "data ?seed?");
                return TCL_ERROR;
            }
            
            if (objc == 3) {
                r = Tcl_GetLongFromObj(interp, objv[2], (long *)&t);
            }

            if (r == TCL_OK) {
                int cn, size, ndx;
                unsigned char *data;
                unsigned long lkp;
                Tcl_Obj *tblPtr, *lkpPtr;

                tblPtr = Tcl_GetVar2Ex(interp, "::crc::crc32_tbl", NULL,
                                       TCL_LEAVE_ERR_MSG );
                if (tblPtr == NULL) {
                    r = TCL_ERROR;
                }
                if (r == TCL_OK) {
                    data = Tcl_GetByteArrayFromObj(objv[1], &size);
                }
                for (cn = 0; r == TCL_OK && cn < size; cn++) {
                    ndx = (t ^ data[cn]) & 0xFF;
                    r = Tcl_ListObjIndex(interp, tblPtr, ndx, &lkpPtr);
                    if (r == TCL_OK) {
                        r = Tcl_GetLongFromObj(interp, lkpPtr, (long*) &lkp);
                    }
                    if (r == TCL_OK) {
                        t = lkp ^ (t >> 8);
                    }
                }
            }

            if (r == TCL_OK) {
                Tcl_SetObjResult(interp, Tcl_NewLongObj(t ^ 0xFFFFFFFF));
            }
            return r;
        }
    }
}

# LoadAccelerator --
#
#	This package can make use of a number of compiled extensions to
#	accelerate the digest computation. This procedure manages the
#	use of these extensions within the package. During normal usage
#	this should not be called, but the test package manipulates the
#	list of enabled accelerators.
#
proc ::crc::LoadAccelerator {name} {
    variable accel
    set r 0
    switch -exact -- $name {
        critcl {
            if {![catch {package require tcllibc}]
                || ![catch {package require crcc}]} {
                set r [expr {[info commands ::crc::Crc32_c] != {}}]
            }
        }
        trf {
            if {![catch {package require Trf}]} {
                set r [expr {![catch {::crc-zlib aa} msg]}]
            }
        }
        default {
            return -code error "invalid accelerator package:\
                must be one of [join [array names accel] {, }]"
        }
    }
    set accel($name) $r
}

# crc::Pop --
#
#	Pop the nth element off a list. Used in options processing.
#
proc ::crc::Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

# crc::crc32 --
#
#	Provide a Tcl implementation of a crc32 checksum similar to the
#	cksum and sum unix commands.
#
# Options:
#  -filename name - return a checksum for the specified file.
#  -format string - return the checksum using this format string.
#  -seed value    - seed the algorithm using value (default is 0xffffffff)
#
proc ::crc::crc32 {args} {
    array set opts [list -filename {} -format %u -seed 0xffffffff \
                        -channel {} -chunksize 4096 -timeout 30000]
    while {[string match -* [set option [lindex $args 0]]]} {
        switch -glob -- $option {
            -file*  { set opts(-filename) [Pop args 1] }
            -for*   { set opts(-format) [Pop args 1] }
            -chan*  { set opts(-channel) [Pop args 1] }
            -chunk* { set opts(-chunksize) [Pop args 1] }
            -time*  { set opts(-timeout) [Pop args 1] }
            -seed   { set opts(-seed) [Pop args 1] }
            -impl*  { set junk [Pop args 1] }
            default {
                if {[llength $args] == 1} { break }
                if {[string compare $option "--"] == 0} { Pop args; break }
                set err [join [lsort [array names opts -*]] ", "]
                return -code error "bad option \"$option\": must be $err"
            }
        }
        Pop args
    }

    # If a file was given - open it
    if {$opts(-filename) != {}} {
        set opts(-channel) [open $opts(-filename) r]
        fconfigure $opts(-channel) -translation binary
    }

    if {$opts(-channel) == {}} {
        
        if {[llength $args] != 1} {
            return -code error "wrong # args: should be \
                 \"crc32 ?-format string? ?-seed value? \
                 -channel chan | -file name | data\""
        }
        set tok [Crc32Init $opts(-seed)]
        Crc32Update $tok [lindex $args 0]
        set r [Crc32Final $tok]

    } else {

        set r $opts(-seed)
        set tok [Crc32Init $opts(-seed)]
        while {![eof $opts(-channel)]} {
            Crc32Update $tok [read $opts(-channel) $opts(-chunksize)]
        }
        set r [Crc32Final $tok]

        if {$opts(-filename) != {}} {
            close $opts(-channel)
        }
    }

    return [format $opts(-format) $r]
}

# -------------------------------------------------------------------------

# Try and load a compiled extension to help (note - trf is fastest)
namespace eval ::crc {
    variable e {}
    foreach e {trf critcl} {
        if {[LoadAccelerator $e]} break
    }
    unset e
}

package provide crc32 1.3.3

# -------------------------------------------------------------------------
#
# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
