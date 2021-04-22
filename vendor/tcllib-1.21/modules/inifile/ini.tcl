# ini.tcl --
#
#       Querying and modifying old-style windows configuration files (.ini)
#
# Copyright (c) 2003-2007    Aaron Faupell <afaupell@users.sourceforge.net>
# Copyright (c) 2008-2012    Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package provide inifile 0.3.2

namespace eval ini {
    variable nexthandle  0
    variable commentchar \;
}

proc ::ini::open {ini args} {
    variable nexthandle

    while {[string match -* [::set opt [lindex $args 0]]]} {
	switch -exact -- $opt {
	    -- {
		::set args [lrange $args 1 end]
		break
	    }
	    -encoding {
		::set enc  [lindex $args 1]
		::set args [lrange $args 2 end]
	    }
	    default {
		return -code error \
		    -errorcode {INIFILE OPTION INVALID} \
		    "Invalid option $opt, expected -encoding"
	    }
	}
    }

    ::set remainder [llength $args]
    if {$remainder > 1} {
	return -code error \
	    -errorcode {WRONG-ARGS INIFILE} \
	    "wrong\#args: should be \"ini::open ?-encoding E? ?mode?\""
    } elseif {$remainder == 1} {
	::set mode [lindex $args 0]
    } else {
	::set mode r+
    }

    if { ![regexp {^(w|r)\+?$} $mode] } {
        return -code error \
	    -errorcode {INIFILE MODE INVALID} \
	    "$mode is not a valid access mode"
    }

    ::set fh ini$nexthandle
    ::set tmp [::open $ini $mode]
    namespace eval ::ini::$fh {
        variable data;     array set data     {}
        variable comments; array set comments {}
        variable sections; array set sections {}
    }
    fconfigure $tmp -translation crlf
    if {[info exists enc]} {
	::ini::_setfileenc $tmp $enc
	::set ::ini::${fh}::enc     $enc
    }

    ::set ::ini::${fh}::channel $tmp
    ::set ::ini::${fh}::file    [_normalize $ini]
    ::set ::ini::${fh}::mode    $mode

    incr nexthandle
    if { [string match "r*" $mode] } {
        _loadfile $fh
    }
    return $fh
}

# close the file and delete all stored info about it
# this does not save any changes. see ::ini::commit

proc ::ini::close {fh} {
    _valid_ns $fh
    variable ::ini::${fh}::channel
    ::close $channel
    namespace delete ::ini::$fh
    return
}

# write all changes to disk

proc ::ini::commit {fh} {
    _valid_ns $fh

    variable ::ini::${fh}::data
    variable ::ini::${fh}::comments
    variable ::ini::${fh}::sections
    variable ::ini::${fh}::channel
    variable ::ini::${fh}::file
    variable ::ini::${fh}::mode
    variable ::ini::${fh}::enc
    variable commentchar

    if { $mode == "r" } {
	return -code error \
	    -errorcode {INIFILE READ-ONLY} \
	    "cannot write to read-only file"
    }
    ::close $channel
    ::set channel [::open $file w]
    if {[info exists enc]} {
	::ini::_setfileenc $channel $enc
    }
    ::set char $commentchar
    #seek $channel 0 start
    foreach sec [array names sections] {
	variable ::ini::${fh}::enc
	if { [info exists comments($sec)] } {
	    puts $channel "$char [join $comments($sec) "\n$char "]\n"
	}
	puts $channel "\[$sec\]"
	foreach key [lsort -dictionary [array names data [_globescape $sec]\000*]] {
	    ::set key [lindex [split $key \000] 1]
	    if {[info exists comments($sec\000$key)]} {
		puts $channel "$char [join $comments($sec\000$key) "\n$char "]"
	    }
	    if {[info exists enc]} {
		::ini::_setfileenc $channel $enc
	    }
	    puts $channel "$key=$data($sec\000$key)"
	}
	puts $channel ""
    }
    ::close $channel
    ::set channel [::open $file r+]
    if {[info exists enc]} {
	::ini::_setfileenc $channel $enc
    }
    return
}

# internal command to read in a file
# see open and revert for public commands

proc ::ini::_loadfile {fh} {
    variable ::ini::${fh}::data
    variable ::ini::${fh}::comments
    variable ::ini::${fh}::sections
    variable ::ini::${fh}::channel
    variable ::ini::${fh}::file
    variable ::ini::${fh}::mode
    variable commentchar

    ::set cur {}
    ::set com {}

    ::set char $commentchar
    seek $channel 0 start

    foreach line [split [read $channel] "\n"] {
	# bug 3612465 - allow and ignore leading and trailing whitespace.
	::set line [string trim $line]

	if { [string match "$char*" $line] } {
	    lappend com [string trim [string range $line [string length $char] end]]
	} elseif { [string match {\[*\]} $line] } {
	    ::set cur [string range $line 1 end-1]
	    if { $cur == "" } { continue }
	    ::set sections($cur) 1
	    if { $com != "" } {
		::set comments($cur) $com
		::set com {}
	    }
	} elseif { [string match {*=*} $line] } {
	    ::set line [split $line =]
	    ::set key [string trim [lindex $line 0]]
	    if { $key == "" || $cur == "" } { continue }
	    ::set value [string trim [join [lrange $line 1 end] =]]
	    if { [regexp "^(\".*\")\s+${char}(.*)$" $value -> 1 2] } {
		::set value $1
		lappend com $2
	    }
	    ::set data($cur\000$key) $value
	    if { $com != "" } {
		::set comments($cur\000$key) $com
		::set com {}
	    }
	}
    }
    return
}

# internal command to escape glob special characters

proc ::ini::_globescape {string} {
    return [string map {* \\* ? \\? \\ \\\\ \[ \\\[ \] \\\]} $string]
}

# internal command to check if a section or key is nonexistant

proc ::ini::_exists {fh sec args} {
    variable ::ini::${fh}::sections
    variable ::ini::${fh}::data

    if { ![info exists sections($sec)] } {
        return -code error \
	    -errorcode {INIFILE SECTION INVALID} \
	    "no such section \"$sec\""
    }
    if { [llength $args] > 0 } {
        ::set key [lindex $args 0]
        if { ![info exists data($sec\000$key)] } {
            return -code error \
		-errorcode {INIFILE KEY INVALID} \
		"can't read key \"$key\""
        }
    }
    return
}

proc ::ini::_setfileenc {fh enc} {
    if {[catch {
	fconfigure $fh -encoding $enc
    } msg]} {
	catch { ::close $fh }
	return -code error $msg
    }
}

# internal command to check validity of a handle

if { [package vcompare [package provide Tcl] 8.4] < 0 } {
    proc ::ini::_normalize {path} {
	return $path
    }
    proc ::ini::_valid_ns {name} {
	variable ::ini::${name}::data
	if { ![info exists data] } {
	    return -code error \
		-errorcode {INIFILE HANDLE INVALID} \
		"$name is not an open INI file"
	}
    }
} else {
    proc ::ini::_normalize {path} {
	file normalize $path
    }
    proc ::ini::_valid_ns {name} {
	if { ![namespace exists ::ini::$name] } {
	    return -code error \
		-errorcode {INIFILE HANDLE INVALID} \
		"$name is not an open INI file"
	}
    }
}

# get and set the ini comment character

proc ::ini::commentchar { {new {}} } {
    variable commentchar
    if {$new != ""} {
        if {[string length $new] > 1} {
	    return -code error \
		-errorcode {INIFILE COMMENT-CHAR INVALID} \
		"comment char must be a single character"
	}
        ::set commentchar $new
    }
    return $commentchar
}

# return all section names

proc ::ini::sections {fh} {
    _valid_ns $fh
    variable ::ini::${fh}::sections
    return [array names sections]
}

# return boolean indicating existance of section or key in section

proc ::ini::exists {fh sec {key {}}} {
    _valid_ns $fh
    variable ::ini::${fh}::sections
    variable ::ini::${fh}::data

    if { $key == "" } {
        return [info exists sections($sec)]
    }
    return [info exists data($sec\000$key)]
}

# return all key names of section
# error if section is nonexistant

proc ::ini::keys {fh sec} {
    _valid_ns $fh
    _exists $fh $sec
    variable ::ini::${fh}::data

    ::set keys {}
    foreach x [array names data [_globescape $sec]\000*] {
        lappend keys [lindex [split $x \000] 1]
    }
    return $keys
}

# return all key value pairs of section
# error if section is nonexistant

proc ::ini::get {fh sec} {
    _valid_ns $fh
    _exists $fh $sec
    variable ::ini::${fh}::data

    ::set r {}
    foreach x [array names data [_globescape $sec]\000*] {
        lappend r [lindex [split $x \000] 1] $data($x)
    }
    return $r
}

# return the value of a key
# return default value if key or section is nonexistant otherwise error

proc ::ini::value {fh sec key {default {}}} {
    _valid_ns $fh
    variable ::ini::${fh}::data

    if {$default != "" && ![info exists data($sec\000$key)]} {
        return $default
    }
    _exists $fh $sec $key
    return [::set data($sec\000$key)]
}

# set the value of a key
# new section or key names are created

proc ::ini::set {fh sec key value} {
    _valid_ns $fh
    variable ::ini::${fh}::sections
    variable ::ini::${fh}::data

    ::set sec [string trim $sec]
    ::set key [string trim $key]
    if { $sec == "" || $key == "" } {
        return -code error \
	    -errorcode {INIFILE SYNTAX} \
	    "section or key may not be empty"
    }
    ::set data($sec\000$key) $value
    ::set sections($sec) 1
    return $value
}

# delete a key or an entire section
# may delete nonexistant keys and sections

proc ::ini::delete {fh sec {key {}}} {
    _valid_ns $fh
    variable ::ini::${fh}::sections
    variable ::ini::${fh}::data

    if { $key == "" } {
        array unset data     [_globescape $sec]\000*
        array unset sections [_globescape $sec]
    }
    catch {unset data($sec\000$key)}
}

# read and set comments for sections and keys
# may comment nonexistant sections and keys

proc ::ini::comment {fh sec key args} {
    _valid_ns $fh
    variable ::ini::${fh}::comments

    ::set r $sec
    if { $key != "" } { append r \000$key }
    if { [llength $args] == 0 } {
        if { ![info exists comments($r)] } { return {} }
        return $comments($r)
    }
    if { [llength $args] == 1 && [lindex $args 0] == "" } {
        unset -nocomplain comments($r)
        return {}
    }
    # take care of any embedded newlines
    for {::set i 0} {$i < [llength $args]} {incr i} {
        ::set args [eval [list lreplace $args $i $i] [split [lindex $args $i] \n]]
    }
    eval [list lappend comments($r)] $args
}

# return the physical filename for the handle

proc ::ini::filename {fh} {
    _valid_ns $fh
    variable ::ini::${fh}::file
    return $file
}

# reload the file from disk losing all changes since the last commit

proc ::ini::revert {fh} {
    _valid_ns $fh
    namespace eval ::ini::$fh {
        array set data     {}
        array set comments {}
        array set sections {}
    }
    variable ::ini::${fh}::enc
    if {[info exists enc]} {
	::ini::_setfileenc $fh $enc
    }
    variable ::ini::${fh}::mode
    if { ![string match "w*" $mode] } {
        _loadfile $fh
    }
}
