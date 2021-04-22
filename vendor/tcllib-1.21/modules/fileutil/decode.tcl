# -*- tcl -*-
# ### ### ### ######### ######### #########
## Copyright (c) 2008-2009 ActiveState Software Inc., Andreas Kupries
##                    2016 Andreas Kupries
## BSD License
##
# Package to help the writing of file decoders. Provides generic
# low-level support commands.

package require Tcl 8.4

namespace eval ::fileutil::decode {
    namespace export mark go rewind at
    namespace export byte short-le long-le nbytes skip
    namespace export unsigned match recode getval
    namespace export clear get put putloc setbuf
}

# ### ### ### ######### ######### #########
##

proc ::fileutil::decode::open {fname} {
    variable chan
    set chan [::open $fname r]
    fconfigure $chan \
	-translation binary \
	-encoding    binary \
	-eofchar     {}
    return
}

proc ::fileutil::decode::close {} {
    variable chan
    ::close $chan
}

# ### ### ### ######### ######### #########
##

proc ::fileutil::decode::mark {} {
    variable chan
    variable mark
    set mark [tell $chan]
    return
}

proc ::fileutil::decode::go {to} {
    variable chan
    seek $chan $to start
    return
}

proc ::fileutil::decode::rewind {} {
    variable chan
    variable mark
    if {$mark == {}} {
	return -code error \
	    -errorcode {FILE DECODE NO MARK} \
	    "No mark to rewind to"
    }
    seek $chan $mark start
    set mark {}
    return
}

proc ::fileutil::decode::at {} {
    variable chan
    return [tell $chan]
}

# ### ### ### ######### ######### #########
##

proc ::fileutil::decode::byte {} {
    variable chan
    variable mask 0xff
    variable val [read $chan 1]
    binary scan $val c val
    return
}

proc ::fileutil::decode::short-le {} {
    variable chan
    variable mask 0xffff
    variable val [read $chan 2]
    binary scan $val s val
    return
}

proc ::fileutil::decode::long-le {} {
    variable chan
    variable mask 0xffffffff
    variable val [read $chan 4]
    binary scan $val i val
    return
}

proc ::fileutil::decode::nbytes {n} {
    variable chan
    variable mask {}
    variable val [read $chan $n]
    return
}

proc ::fileutil::decode::skip {n} {
    variable chan
    #read $chan $n
    seek $chan $n current
    return
}

# ### ### ### ######### ######### #########
##

proc ::fileutil::decode::unsigned {} {
    variable val
    if {$val >= 0} return
    variable mask
    if {$mask eq {}} {
	return -code error \
	    -errorcode {FILE DECODE ILLEGAL UNSIGNED} \
	    "Unsigned not possible here"
    }
    set val [format %u [expr {$val & $mask}]]
    return
}

proc ::fileutil::decode::match {eval} {
    variable val

    #puts "Match: Expected $eval, Got: [format 0x%08x $val]"

    if {$val == $eval} {return 1}
    rewind
    return 0
}

proc ::fileutil::decode::recode {cmdpfx} {
    variable val
    lappend cmdpfx $val
    set val [uplevel 1 $cmdpfx]
    return
}

proc ::fileutil::decode::getval {} {
    variable val
    return $val
}

# ### ### ### ######### ######### #########
##

proc ::fileutil::decode::clear {} {
    variable buf {}
    return
}

proc ::fileutil::decode::get {} {
    variable buf
    return $buf
}

proc ::fileutil::decode::setbuf {list} {
    variable buf $list
    return
}

proc ::fileutil::decode::put {name} {
    variable buf
    variable val
    lappend buf $name $val
    return
}

proc ::fileutil::decode::putloc {name} {
    variable buf
    variable chan
    lappend buf $name [tell $chan]
    return
}

# ### ### ### ######### ######### #########
##

namespace eval ::fileutil::decode {
    # Stream to read from
    variable chan {}

    # Last value read from the stream, or modified through decoder
    # operations.
    variable val  {}

    # Remembered location in the stream
    variable mark {}

    # Buffer for accumulating structured results
    variable buf  {}

    # Mask for trimming a value to unsigned.
    # Size-dependent
    variable mask {}
}

# ### ### ### ######### ######### #########
## Ready
package provide fileutil::decode 0.2.1
return
