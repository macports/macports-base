###
# Adapted from tcllib module
#
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
# Usage: clay::uuid generate
#        clay::uuid equal $idA $idB
namespace eval ::clay::uuid {
    namespace export uuid
}

###
# Optimization
# Caches machine info after the first pass
###

proc ::clay::uuid::generate_tcl_machinfo {} {
  variable machinfo
  if {[info exists machinfo]} {
    return $machinfo
  }
  lappend machinfo [clock seconds]; # timestamp
  lappend machinfo [clock clicks];  # system incrementing counter
  lappend machinfo [info hostname]; # spatial unique id (poor)
  lappend machinfo [pid];           # additional entropy
  lappend machinfo [array get ::tcl_platform]

  ###
  # If we have /dev/urandom just stream 128 bits from that
  ###
  if {[file exists /dev/urandom]} {
    set fin [open /dev/urandom r]
    binary scan [read $fin 128] H* machinfo
    close $fin
  } elseif {[catch {package require nettool}]} {
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
          ::clay::K [fconfigure $s -sockname] [close $s]
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
if {[info commands irmmd5] ne {}} {
proc ::clay::uuid::generate {{type {}}} {
    variable nextuuid
    set s [irmmd5 "$type [incr nextuuid(type)] [generate_tcl_machinfo]"]
    foreach {a b} {0 7 8 11 12 15 16 19 20 31} {
         append r [string range $s $a $b] -
     }
     return [string tolower [string trimright $r -]]
}
proc ::clay::uuid::short {{type {}}} {
  variable nextuuid
  set r [irmmd5 "$type [incr nextuuid(type)] [generate_tcl_machinfo]"]
  return [string range $r 0 16]
}

} else {
package require md5 2
proc ::clay::uuid::raw {{type {}}} {
    variable nextuuid
    set tok [md5::MD5Init]
    md5::MD5Update $tok "$type [incr nextuuid($type)] [generate_tcl_machinfo]"
    set r [md5::MD5Final $tok]
    return $r
    #return [::clay::uuid::tostring $r]
}
proc ::clay::uuid::generate {{type {}}} {
    return [::clay::uuid::tostring [::clay::uuid::raw  $type]]
}
proc ::clay::uuid::short {{type {}}} {
  set r [::clay::uuid::raw $type]
  binary scan $r H* s
  return [string range $s 0 16]
}
}
proc ::clay::uuid::tostring {uuid} {
    binary scan $uuid H* s
    foreach {a b} {0 7 8 11 12 15 16 19 20 31} {
        append r [string range $s $a $b] -
    }
    return [string tolower [string trimright $r -]]
}
# Convert a string representation of a uuid into its binary format.
#
proc ::clay::uuid::fromstring {uuid} {
    return [binary format H* [string map {- {}} $uuid]]
}

# Compare two uuids for equality.
#
proc ::clay::uuid::equal {left right} {
    set l [fromstring $left]
    set r [fromstring $right]
    return [string equal $l $r]
}

# uuid generate -> string rep of a new uuid
# uuid equal uuid1 uuid2
#
proc ::clay::uuid {cmd args} {
    switch -exact -- $cmd {
        generate {
           return [::clay::uuid::generate {*}$args]
        }
        short {
          set uuid [::clay::uuid::short {*}$args]
        }
        equal {
            tailcall ::clay::uuid::equal {*}$args
        }
        default {
            return -code error "bad option \"$cmd\":\
                must be generate or equal"
        }
    }
}
