#!/usr/bin/tclsh
# /etc/ports.conf options
package provide darwinports 1.0


namespace eval darwinports {
	proc portpath {args} {
		global portpath
		set portpath $args
	}

	proc distpath {args} {
		global distpath
		set distpath $args
	}

	proc readconf {args} {
		global portpath distpath
		if [file isfile /etc/ports.conf] {
			source /etc/ports.conf
		}
	}
	
	proc init {args} {
		global portpath distpath libpath auto_path
		# Defaults

		set portpath /usr/darwinports
		darwinports::readconf
		
		# Prefer the PORTPATH environment variable
		upvar env env
		if {[llength [array names env PORTPATH]] > 0} {
			set portpath [lindex [array get env PORTPATH] 1]
		}

		if ![info exists distpath] {
			set distpath $portpath/distfiles
		}
		if ![info exists libpath] {
			set libpath $portpath/Tcl
		}

		if [file isdirectory $libpath] {
			if [catch {pkg_mkIndex $libpath *.tcl *.so *.dylib} result] {
				return -1
			} else {
				lappend auto_path $libpath
			}
		} else {
			return -1
		}
		return 0
	}
}

