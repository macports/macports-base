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

	# XXX not portable
	proc ccextension {file} {
		if {[regexp {([A-Za-z]+).c} [file tail $file] match name] == 1} {
			set objfile [file dirname $file]/$name.dylib
			if {[file exists $objfile]} {
				if {[file mtime $file] <= [file mtime $objfile]} {
					return
				}
			}
			exec cc -dynamiclib $file -o $objfile -ltcl
		}
	}
	
	proc init {args} {
		global portpath distpath libpath auto_path env
		# Defaults

		set portpath /usr/darwinports
		darwinports::readconf
		
		# Prefer the PORTPATH environment variable
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
			return -1
		}
		return 0
	}
}
