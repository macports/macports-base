# genStubs.tcl --
#
#	This script generates a set of stub files for a given
#	interface.
#
#
# Copyright (c) 1998-1999 by Scriptics Corporation.
# Copyright (c) 2007 Daniel A. Steffen <das@users.sourceforge.net>
# Copyright (c) 2011,2022 Andreas Kupries <andreas_kupries@users.sourceforge.net>
# (Conversion into package set).
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.6 9

lappend auto_path [file dirname [file normalize [info script]]]/lib/stubs
lappend auto_path [file dirname [file normalize [info script]]]/lib/util84

package require stubs::container
package require stubs::reader
package require stubs::gen::init
package require stubs::gen::header

proc main {} {
    global argv argv0

    if {[llength $argv] < 2} {
	puts stderr "usage: $argv0 outDir declFile ?declFile...?"
	exit 1
    }

    set outDir [lindex $argv 0]

    set T [stubs::container::new]

    foreach file [lrange $argv 1 end] {
	stubs::reader::file T $file
    }

    foreach name [lsort [stubs::container::interfaces $T]] {
	puts "Emitting $name"
	stubs::gen::header::rewrite@ $outDir $T $name
    }

    stubs::gen::init::rewrite@ $outDir $T
    return
}

main
exit 0
