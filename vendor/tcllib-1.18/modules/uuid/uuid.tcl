# uuid.tcl - Copyright (C) 2004 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# UUIDs are 128 bit values that attempt to be unique in time and space.
#
# Reference:
#   http://www.opengroup.org/dce/info/draft-leach-uuids-guids-01.txt
#
# uuid: scheme:
# http://www.globecom.net/ietf/draft/draft-kindel-uuid-uri-00.html
#
# Usage: uuid::uuid generate
#        uuid::uuid equal $idA $idB

package require Tcl 8.5

namespace eval uuid {
    variable accel
    array set accel {critcl 0}

    namespace export uuid

    variable uid
    if {![info exists uid]} {
        set uid 1
    }

    proc K {a b} {set a}
}

###
# Optimization
# Caches machine info after the first pass
###

proc ::uuid::generate_tcl_machinfo {} {
  variable machinfo
  if {[info exists machinfo]} {
    return $machinfo
  }
  lappend machinfo [clock seconds]; # timestamp
  lappend machinfo [clock clicks];  # system incrementing counter
  lappend machinfo [info hostname]; # spatial unique id (poor)
  lappend machinfo [pid];           # additional entropy
  lappend machinfo [array get ::tcl_platform]
  if {[catch {package require nettool}]} {
    # More spatial information -- better than hostname.
    # bug 1150714: opening a server socket may raise a warning messagebox
    #   with WinXP firewall, using ipconfig will return all IP addresses
    #   including ipv6 ones if available. ipconfig is OK on win98+
    if {[string equal $::tcl_platform(platform) "windows"]} {
      catch {exec ipconfig} config
      lappend machinfo $config
    } else {
      catch {
          set s [socket -server void -myaddr [info hostname] 0]
          K [fconfigure $s -sockname] [close $s]
      } r
      lappend machinfo $r
    }
  
    if {[package provide Tk] != {}} {
      lappend machinfo [winfo pointerxy .]
      lappend machinfo [winfo id .]
    }
  } else {
    ###
    # If the nettool package works on this platform
    # use the stream of hardware ids from it
    ###
    lappend machinfo {*}[::nettool::hwid_list]
  }
  return $machinfo
}

# Generates a binary UUID as per the draft spec. We generate a pseudo-random
# type uuid (type 4). See section 3.4
#
proc ::uuid::generate_tcl {} {
    package require md5 2
    variable uid
    
    set tok [md5::MD5Init]
    md5::MD5Update $tok [incr uid];      # package incrementing counter 
    foreach string [generate_tcl_machinfo] {
      md5::MD5Update $tok $string
    }
    set r [md5::MD5Final $tok]
    binary scan $r c* r
    
    # 3.4: set uuid versioning fields
    lset r 8 [expr {([lindex $r 8] & 0x3F) | 0x80}]
    lset r 6 [expr {([lindex $r 6] & 0x0F) | 0x40}]
    
    return [binary format c* $r]
}

if {[string equal $tcl_platform(platform) "windows"] 
        && [package provide critcl] != {}} {
    namespace eval uuid {
        critcl::ccode {
            #define WIN32_LEAN_AND_MEAN
            #define STRICT
            #include <windows.h>
            #include <ole2.h>
            typedef long (__stdcall *LPFNUUIDCREATE)(UUID *);
            typedef const unsigned char cu_char;
        }
        critcl::cproc generate_c {Tcl_Interp* interp} ok {
            HRESULT hr = S_OK;
            int r = TCL_OK;
            UUID uuid = {0};
            HMODULE hLib;
            LPFNUUIDCREATE lpfnUuidCreate = NULL;

            hLib = LoadLibrary(_T("rpcrt4.dll"));
            if (hLib)
                lpfnUuidCreate = (LPFNUUIDCREATE)
                    GetProcAddress(hLib, "UuidCreate");
            if (lpfnUuidCreate) {
                Tcl_Obj *obj;
                lpfnUuidCreate(&uuid);
                obj = Tcl_NewByteArrayObj((cu_char *)&uuid, sizeof(uuid));
                Tcl_SetObjResult(interp, obj);
            } else {
                Tcl_SetResult(interp, "error: failed to create a guid",
                              TCL_STATIC);
                r = TCL_ERROR;
            }
            return r;
        }
    }
}

# Convert a binary uuid into its string representation.
#
proc ::uuid::tostring {uuid} {
    binary scan $uuid H* s
    foreach {a b} {0 7 8 11 12 15 16 19 20 end} {
        append r [string range $s $a $b] -
    }
    return [string tolower [string trimright $r -]]
}

# Convert a string representation of a uuid into its binary format.
#
proc ::uuid::fromstring {uuid} {
    return [binary format H* [string map {- {}} $uuid]]
}

# Compare two uuids for equality.
#
proc ::uuid::equal {left right} {
    set l [fromstring $left]
    set r [fromstring $right]
    return [string equal $l $r]
}

# Call our generate uuid implementation
proc ::uuid::generate {} {
    variable accel
    if {$accel(critcl)} {
        return [generate_c]
    } else {
        return [generate_tcl]
    }
}

# uuid generate -> string rep of a new uuid
# uuid equal uuid1 uuid2
#
proc uuid::uuid {cmd args} {
    switch -exact -- $cmd {
        generate {
            if {[llength $args] != 0} {
                return -code error "wrong # args:\
                    should be \"uuid generate\""
            }
            return [tostring [generate]]
        }
        equal {
            if {[llength $args] != 2} {
                return -code error "wrong \# args:\
                    should be \"uuid equal uuid1 uuid2\""
            }
            return [eval [linsert $args 0 equal]]
        }
        default {
            return -code error "bad option \"$cmd\":\
                must be generate or equal"
        }
    }
}

# -------------------------------------------------------------------------

# LoadAccelerator --
#
#	This package can make use of a number of compiled extensions to
#	accelerate the digest computation. This procedure manages the
#	use of these extensions within the package. During normal usage
#	this should not be called, but the test package manipulates the
#	list of enabled accelerators.
#
proc ::uuid::LoadAccelerator {name} {
    variable accel
    set r 0
    switch -exact -- $name {
        critcl {
            if {![catch {package require tcllibc}]} {
                set r [expr {[info commands ::uuid::generate_c] != {}}]
            }
        }
        default {
            return -code error "invalid accelerator package:\
                must be one of [join [array names accel] {, }]"
        }
    }
    set accel($name) $r
}

# -------------------------------------------------------------------------

# Try and load a compiled extension to help.
namespace eval ::uuid {
    variable e {}
    foreach e {critcl} {
        if {[LoadAccelerator $e]} break
    }
    unset e
}

package provide uuid 1.0.5

# -------------------------------------------------------------------------
# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
