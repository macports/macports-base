#!/usr/bin/tclsh
# /etc/ports.conf options
package provide darwinports 1.0

global ports_opts
global bootstrap_options
set bootstrap_options "sysportpath libpath"

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
    global auto_path env bootstrap_options sysportpath

    if [file isfile /etc/ports.conf] {
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
    return $sysportpath
}

# XXX incomplete. Waiting for kevin's dependancy related submissions
proc build {portpath chain target} {
    global targets portpath

    if [file isdirectory $portpath] {
	cd $portpath
	set portpath [pwd]
	# XXX These must execute at a global scope
	uplevel #0 source Portfile
	uplevel #0 eval_targets targets $chain $target
    } else {
	return -code error "Portdir $portpath does not exist"
    }
}
