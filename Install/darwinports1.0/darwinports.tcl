#!/usr/bin/tclsh
# /etc/ports.conf options
package provide darwinports 1.0

global ports_opts
global bootstrap_options
set bootstrap_options "sysportpath libpath"
set portinterp_options "sysportpath portpath auto_path portconf"

# XXX not portable
proc ccextension {file} {
    if {[regexp {([A-Za-z]+).c} [file tail $file] match name] == 1} {
	set objfile [file join [file dirname $file] $name.dylib]
	if {[file exists $objfile]} {
	    if {[file mtime $file] <= [file mtime $objfile]} {
		return
	    }
	}
	exec cc -dynamiclib $file -o $objfile -ltcl
    }
}

proc init {args} {
    global auto_path env bootstrap_options sysportpath portconf

    if [file isfile /etc/ports.conf] {
	set portconf /etc/ports.conf
	set fd [open /etc/ports.conf r]
	while {[gets $fd line] >= 0} {
	    foreach option $bootstrap_options {
		if {[regexp "^$option\[ \t\]+(\[A-Za-z0-9/\]+$)" $line match val] == 1} {
		    set $option $val
		}
	    }
	}
    }

    # Prefer the PORTPATH environment variable
    if {[llength [array names env PORTPATH]] > 0} {
	set sysportpath [lindex [array get env PORTPATH] 1]
    }

    if ![info exists sysportpath] {
	return -code error "sysportpath must be set in /etc/ports.conf or in the PORTPATH env variable"
    }
	
    if ![info exists libpath] {
	set libpath [file join $sysportpath Tcl]
    }

    if [file isdirectory $libpath] {
	lappend auto_path $libpath
	foreach dir [glob -nocomplain -directory $libpath -types d *] {
	    if [file isdirectory $dir] {
		foreach srcfile [glob -nocomplain -directory $dir -types f *.c] {
		    ccextension $srcfile
		}
		catch {pkg_mkIndex $dir *.tcl *.so *.dylib} result
	    }
	}
    } else {
	return -code error "Library directory '$libpath' must exist"
    }
}

proc build {portdir chain target args} {
    global targets portpath portinterp_options user_options

    if [file isdirectory $portdir] {
	cd $portdir
	set portpath [pwd]
	interp create workerbee
	workerbee alias {} build workerbee build
	foreach opt $portinterp_options {
		upvar #0 $opt upopt
		if [info exists upopt] {
			workerbee eval set $opt \"$upopt\"
		}
	}
	if {[llength $args] > 0} {
		workerbee eval set user_options $args
	}
	workerbee eval source Portfile
	workerbee eval eval_targets targets $chain $target
    } else {
	return -code error "Portdir $portpath does not exist"
    }
}
