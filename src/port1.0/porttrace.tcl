# et:ts=4
# porttrace.tcl
#
# $Id: porttrace.tcl,v 1.2 2005/07/22 21:45:55 pguyot Exp $
#
# Copyright (c) 2005 Paul Guyot <pguyot@kallisys.net>,
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

package provide porttrace 1.0
package require Pextlib 1.0
package require registry 1.0
package require Tcl 8.3
package require Thread 2.6

#set_ui_prefix

proc trace_start {workpath} {
	global os.platform
	if {${os.platform} == "darwin"} {
		global prefix env trace_fifo trace_thread darwinports::portinterp_options
		# Create a fifo.
		set trace_fifo "$workpath/trace_fifo"
		file delete -force $trace_fifo
		mkfifo $trace_fifo 0600
		
		# Create the thread.
		set trace_thread [thread::create -preserved {thread::wait}]

		# Tell the thread about all the Tcl packages we already
		# know about so it won't glob for packages.
		foreach pkgName [package names] {
			foreach pkgVers [package versions $pkgName] {
				set pkgLoadScript [package ifneeded $pkgName $pkgVers]
				thread::send -async $trace_thread "package ifneeded $pkgName $pkgVers {$pkgLoadScript}"
			}
		}

		# inherit some configuration variables.
		thread::send -async $trace_thread "namespace eval darwinports {}"
		namespace eval darwinports {
			foreach opt $portinterp_options {
				if {![info exists $opt]} {
					global darwinports::$opt
				}
				thread::send -async $trace_thread "global darwinports::$opt"
				set val [set $opt]
				thread::send -async $trace_thread "set darwinports::$opt \"$val\""
			}
		}

		# load this file
		thread::send -async $trace_thread "package require porttrace 1.0"
		thread::send -async $trace_thread "trace_thread_start $trace_fifo"
		
		# Launch darwintrace.dylib.
		
		set env(DYLD_INSERT_LIBRARIES) \
			"$prefix/share/darwinports/Tcl/darwintrace1.0/darwintrace.dylib"
		set env(DYLD_FORCE_FLAT_NAMESPACE) 1
		set env(DARWINTRACE_LOG) "$trace_fifo"
	}
}

# Check the list of ports.
# Output a warning for every port the trace revealed a dependency on
# that isn't included in portslist
proc trace_check_deps {portslist} {
	global trace_thread
	
	# Get the list of ports.
	thread::send $trace_thread "trace_get_ports" ports
	
	# Compare with portslist
	set portslist [lsort $portslist]
	foreach port $ports {
		if {[lsearch -sorted -exact $portslist $port] == -1} {
			ui_warn "trace revealed an undeclared dependency on $port"
		}
	}
}

# Stop the trace and return the list of ports the port depends on.
proc trace_stop {} {
	global os.platform
	if {${os.platform} == "darwin"} {
		global env trace_thread trace_fifo
		unset env(DYLD_INSERT_LIBRARIES)
		unset env(DYLD_FORCE_FLAT_NAMESPACE)
		unset env(DARWINTRACE_LOG)

		# Destroy the thread.
		thread::release $trace_thread

		file delete -force $trace_fifo
		
		return ports
	} else {
		return {}
	}
}

# Private.
# Thread method to read a line from the trace.
proc trace_read_line {chan} {
	global files_list ports_list
	if {![eof $chan]} {

		# The line is of the form: verb\tpath
		# Get the path by chopping it.
		set theline [gets $chan]

		set line_length [string length $theline]
		set path_start [expr [string first "\t" $theline] + 1]
		set path [string range $theline $path_start [expr $line_length - 1]]

		# Did we process the file yet?
		if {[lsearch -sorted -exact $files_list $path] == -1} {
			# Add the file to the list. Once is enough.
			lappend files_list $path
			set files_list [lsort $files_list]

			# Obtain information about this file.
			set port [registry::file_registered $path]
			if { $port != 0 } {
				# Add the port to the list.
				if {[lsearch -sorted -exact $ports_list $port] == -1} {
					lappend ports_list $port
					set ports_list [lsort $ports_list]
					# Maybe fill files_list for efficiency?
				}
			}
		}
	}
}

# Private.
# Thread init method.
proc trace_thread_start {fifo} {
	global files_list ports_list
	set files_list {}
	set ports_list {}
	set chan [open $fifo {RDONLY NONBLOCK}]
	fileevent $chan readable [list trace_read_line $chan]
}

# Private.
# Thread ports export method.
proc trace_get_ports {} {
	global ports_list
	return $ports_list
}
