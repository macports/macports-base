# et:ts=4
# porttrace.tcl
#
# $Id$
#
# Copyright (c) 2005-2006 Paul Guyot <pguyot@kallisys.net>,
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

proc trace_start {workpath} {
	global os.platform
	if {${os.platform} == "darwin"} {
		if {[catch {package require Thread} error]} {
			ui_warn "trace requires Tcl Thread package ($error)"
		} else {
			global env trace_fifo trace_sandboxbounds portpath
			# Create a fifo.
			# path in unix socket limited to 109 chars
			# # set trace_fifo "$workpath/trace_fifo"
			set trace_fifo "/tmp/macports/[pid]_[expr {int(rand()*1000)}]" 
			file mkdir "/tmp/macports"
			file delete -force $trace_fifo
			
			# Create the thread/process.
			create_slave $workpath $trace_fifo
					
			# Launch darwintrace.dylib.
			
			set tracelib_path [file join ${portutil::autoconf::prefix} share macports Tcl darwintrace1.0 darwintrace.dylib]

			if {[info exists env(DYLD_INSERT_LIBRARIES)] && [string length "$env(DYLD_INSERT_LIBRARIES)"] > 0} {
				set env(DYLD_INSERT_LIBRARIES) "${env(DYLD_INSERT_LIBRARIES)}:${tracelib_path}"
			} else {
				set env(DYLD_INSERT_LIBRARIES) ${tracelib_path}
			}
			set env(DYLD_FORCE_FLAT_NAMESPACE) 1
			set env(DARWINTRACE_LOG) "$trace_fifo"
			# The sandbox is limited to:
			# workpath
			# /tmp
			# /private/tmp
			# /var/tmp
			# /private/var/tmp
			# $TMPDIR
			# /dev/null
			# /dev/tty
			# /Library/Caches/com.apple.Xcode
 			# $CCACHE_DIR
 			# $HOMEDIR/.ccache
			set trace_sandboxbounds "/tmp:/private/tmp:/var/tmp:/private/var/tmp:/dev/:/etc/passwd:/etc/groups:/etc/localtime:/Library/Caches/com.apple.Xcode:$env(HOME)/.ccache:${workpath}:$portpath"
			if {[info exists env(TMPDIR)]} {
				set trace_sandboxbounds "${trace_sandboxbounds}:$env(TMPDIR)"
			}
 			if {[info exists env(CCACHE_DIR)]} {
 				set trace_sandboxbounds "${trace_sandboxbounds}:$env(CCACHE_DIR)"
 			}
			tracelib setsandbox $trace_sandboxbounds
		}
	}
}

# Enable the fence.
# Only done for targets that should only happen in the sandbox.
proc trace_enable_fence {} {
	global env trace_sandboxbounds
	set env(DARWINTRACE_SANDBOX_BOUNDS) $trace_sandboxbounds
	tracelib enablefence
}

# Disable the fence.
# Unused yet.
proc trace_disable_fence {} {
	global env
	if [info exists env(DARWINTRACE_SANDBOX_BOUNDS)] {
		unset env(DARWINTRACE_SANDBOX_BOUNDS)
	}
}

# Check the list of ports.
# Output a warning for every port the trace revealed a dependency on
# that isn't included in portslist
# This method must be called after trace_start
proc trace_check_deps {target portslist} {
	# Get the list of ports.
	set ports [slave_send slave_get_ports]
	
	# Compare with portslist
	set portslist [lsort $portslist]
	foreach port $ports {
		if {[lsearch -sorted -exact $portslist $port] == -1} {
			ui_warn "Target $target has an undeclared dependency on $port"
		}
	}
	foreach port $portslist {
		if {[lsearch -sorted -exact $ports $port] == -1} {
			ui_debug "Target $target has no traceable dependency on $port"
		}
	}	
}

# Check that no violation happened.
# Output a warning for every sandbox violation the trace revealed.
# This method must be called after trace_start
proc trace_check_violations {} {
	# Get the list of violations.
	set violations [slave_send slave_get_sandbox_violations]
	
	foreach violation [lsort $violations] {
		ui_warn "An activity was attempted outside sandbox: $violation"
	}
}

# Stop the trace and return the list of ports the port depends on.
# This method must be called after trace_start
proc trace_stop {} {
	global os.platform
	if {${os.platform} == "darwin"} {
		global env trace_fifo
		unset env(DYLD_INSERT_LIBRARIES)
		unset env(DYLD_FORCE_FLAT_NAMESPACE)
		unset env(DARWINTRACE_LOG)
		if [info exists env(DARWINTRACE_SANDBOX_BOUNDS)] {
			unset env(DARWINTRACE_SANDBOX_BOUNDS)
		}
		
		#kill socket
		tracelib clean

		# Clean up.
		slave_send slave_stop

		# Delete the slave.
		delete_slave

		file delete -force $trace_fifo
	}
}

# Private
# Create the slave thread.
proc create_slave {workpath trace_fifo} {
	global trace_thread
	# Create the thread.
	set trace_thread [macports_create_thread]
	
	# The slave thread requires the registry package.
	thread::send -async $trace_thread "package require registry 1.0"
	# and this file as well.
	thread::send -async $trace_thread "package require porttrace 1.0"

	# Start the slave work.
	thread::send -async $trace_thread "slave_start $trace_fifo $workpath"
}

# Private
# Send a command to the thread without waiting for the result.
proc slave_send_async {command} {
	global trace_thread

	thread::send -async $trace_thread "$command"
}

# Private
# Send a command to the thread.
proc slave_send {command} {
	global trace_thread

	# ui_warn "slave send $command ?"

	thread::send $trace_thread "$command" result
	return $result
}

# Private
# Destroy the thread.
proc delete_slave {} {
	global trace_thread

	# Destroy the thread.
	thread::release $trace_thread
}

# Private.
# Slave method to read a line from the trace.
proc slave_read_line {chan} {
	global ports_list trace_filemap sandbox_violation_list workpath
	global env

	while 1 {
		# We should never get EOF, actually.
		if {[eof $chan]} {
			break
		}
		
		# The line is of the form: verb\tpath
		# Get the path by chopping it.
		set theline [gets $chan]
		
		if {[fblocked $chan]} {
			# Exit the loop.
			break
		}

		set line_length [string length $theline]
		
		# Skip empty lines.
		if {$line_length > 0} {
			set path_start [expr [string first "\t" $theline] + 1]
			set op [string range $theline 0 [expr $path_start - 2]]
			set path [string range $theline $path_start [expr $line_length - 1]]
			
			# open/execve
			if {$op == "open" || $op == "execve"} {
				# Only work on files.
				if {[file isfile $path]} {
					# Did we process the file yet?
					if {![filemap exists trace_filemap $path]} {
						# Obtain information about this file.
						set port [registry::file_registered $path]
						if { $port != 0 } {
							# Add the port to the list.
							if {[lsearch -sorted -exact $ports_list $port] == -1} {
								lappend ports_list $port
								set ports_list [lsort $ports_list]
								# Maybe fill trace_filemap for efficiency?
							}
						}
			
						# Add the file to the tree with port information.
						# Ignore errors. Errors can occur if a directory was
						# created where a file once lived.
						# This doesn't affect existing ports and we just
						# add this information to speed up port detection.
						catch {filemap set trace_filemap $path $port}
					}
				}
			} elseif {$op == "sandbox_violation"} {
				lappend sandbox_violation_list $path
			}
		}
	}
}

# Private.
# Slave init method.
proc slave_start {fifo p_workpath} {
	global ports_list trace_filemap sandbox_violation_list 
	# Save the workpath.
	set workpath $p_workpath
	# Create a virtual filemap.
	filemap create trace_filemap
	set ports_list {}
	set sandbox_violation_list {}
	tracelib setname $fifo
	tracelib run
}

# Private.
# Slave cleanup method.
proc slave_stop {} {
	global trace_filemap trace_fifo_r_chan trace_fifo_w_chan
	# Close the virtual filemap.
	filemap close trace_filemap
	# Close the pipe (both ends).
}

# Private.
# Slave ports export method.
proc slave_get_ports {} {
	global ports_list
	return $ports_list
}

# Private.
# Slave sandbox violations export method.
proc slave_get_sandbox_violations {} {
	global sandbox_violation_list
	return $sandbox_violation_list
}

proc slave_add_sandbox_violation {path} {
	global sandbox_violation_list
	lappend sandbox_violation_list $path
}
