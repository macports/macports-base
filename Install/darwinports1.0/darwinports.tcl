#!/usr/bin/tclsh
# /etc/ports.conf options
package provide darwinports 1.0

namespace eval darwinports {
	variable options
	variable bootstrap_options "portpath libpath"

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
	
	proc bootstrap {args} {
		global auto_path env
		
		if [file isfile /etc/ports.conf] {
			set fd [open /etc/ports.conf r]
			while {[gets $fd line] >= 0} {
				foreach option $darwinports::bootstrap_options {
					if {[regexp "^$option\[ \t\]+(\[A-Za-z0-9/\]+$)" $line match val] == 1} {
						set $option $val
					}
				}
			}
		}


		# Prefer the PORTPATH environment variable
		if {[llength [array names env PORTPATH]] > 0} {
			set portpath [lindex [array get env PORTPATH] 1]
		}

		if ![info exists portpath] {
			return -code error "portpath must be set in /etc/ports.conf or in the PORTPATH env variable"
		}

		if ![info exists libpath] {
			set libpath [file join $portpath Tcl]
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
		package require portutil
		return $portpath
	}

	proc init {args} {
		# Bootstrap ports system and bring in darwinports packages
		set portpath [darwinports::bootstrap]
		# Register standard darwinports package options
		globals darwinports::options portpath distpath prefix
		options darwinports::options portpath distpath prefix
		# Register defaults
		default darwinports::options portpath $portpath
		default darwinports::options prefix /usr/local/bin
		default darwinports::options distpath [file join $portpath distfiles]

		return
	}
}
