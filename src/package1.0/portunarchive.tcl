# vim:ts=4 sw=4 fo=croq
# portunarchive.tcl
#
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

package provide portunarchive 1.0
package require portutil 1.0

set com.apple.unarchive [target_new com.apple.unarchive unarchive_main]
target_init ${com.apple.unarchive} unarchive_init
target_provides ${com.apple.unarchive} unarchive
target_requires ${com.apple.unarchive} main
target_prerun ${com.apple.unarchive} unarchive_start
target_postrun ${com.apple.unarchive} unarchive_finish

# defaults
default unarchive.dir {${destpath}}
default unarchive.env {}
default unarchive.cmd {}
default unarchive.pre_args {}
default unarchive.args {}
default unarchive.post_args {}

default unarchive.srcpath {${portarchivepath}}
default unarchive.type {}
default unarchive.file {}
default unarchive.path {}

set_ui_prefix

proc unarchive_init {args} {
	global UI_PREFIX target_state_fd variations workpath
	global ports_force ports_source_only ports_binary_only
	global portname portversion portrevision portvariants portpath
	global unarchive.srcpath unarchive.type unarchive.file unarchive.path

	# Check mode in case archive called directly by user
	if {[option portarchivemode] != "yes"} {
		return -code error "Archive mode is not enabled!"
	}

	# Define port variants if not already defined
	if { ![info exists portvariants] } {
		set portvariants ""
		set vlist [lsort -ascii [array names variations]]
		# Put together variants in the form +foo+bar for the archive name
		foreach v $vlist {
			if { ![string equal $v [option os.platform]] && ![string equal $v [option os.arch]] } {
				set portvariants "${portvariants}+${v}"
			}
		}
	}

	# Define archive directory, file, and path
	if {![string equal ${unarchive.srcpath} ${workpath}] && ![string equal ${unarchive.srcpath} ""]} {
		set unarchive.srcpath [file join ${unarchive.srcpath} [option os.platform] [option os.arch]]
	}

	# Determine if unarchive should be skipped
	set skipped 0
	if {[check_statefile target com.apple.unarchive $target_state_fd]} {
		return 0
	} elseif {[info exists ports_source_only] && $ports_source_only == "yes"} {
		ui_debug "Skipping unarchive ($portname) since source-only is set"
		set skipped 1
	} elseif {[check_statefile target com.apple.destroot $target_state_fd]} {
		ui_debug "Skipping unarchive ($portname) since destroot completed"
		set skipped 1
	} elseif {[info exists ports_force] && $ports_force == "yes"} {
		ui_debug "Skipping unarchive ($portname) since force is set"
		set skipped 1
	} else {
		set found 0
		set unsupported 0
		foreach unarchive.type [option portarchivetype] {
			if {[catch {archiveTypeIsSupported ${unarchive.type}} errmsg] == 0} {
				set unarchive.file "${portname}-${portversion}_${portrevision}${portvariants}.[option os.arch].${unarchive.type}"
				set unarchive.path "[file join ${unarchive.srcpath} ${unarchive.file}]"
				if {[file exist ${unarchive.path}]} {
					set found 1
					break
				} else {
					ui_debug "No [string toupper ${unarchive.type}] archive: ${unarchive.path}"
				}
			} else {
				ui_debug "Skipping [string toupper ${unarchive.type}] archive: $errmsg"
				set unsupported [expr $unsupported + 1]
			}
		}
		if {$found == 1} {
			ui_debug "Found [string toupper ${unarchive.type}] archive: ${unarchive.path}"
			if {[file mtime ${unarchive.path}] < [file mtime [file join $portpath Portfile]]} {
				ui_debug "Skipping unarchive ($portname) since archive ${unarchive.file} is out-of-date"
				set skipped 1
				ui_msg "Portfile changed since last archive; rebuilding archive."
			}
		} else {
			if {[info exists ports_binary_only] && $ports_binary_only == "yes"} {
				return -code error "Archive for ${portname} ${portversion}_${portrevision}${portvariants} not found, required when binary-only is set!"
			} else {
				if {[llength [option portarchivetype]] == $unsupported} {
					ui_debug "Skipping unarchive ($portname) since specified archive types not supported"
				} else {
					ui_debug "Skipping unarchive ($portname) since no archive found"
				}
				set skipped 1
			}
		}
	}
	# Skip unarchive target by setting state
	if {$skipped == 1} {
		write_statefile target "com.apple.unarchive" $target_state_fd
	}

	return 0
}

proc unarchive_start {args} {
	global UI_PREFIX portname portversion portrevision portvariants

	ui_msg "$UI_PREFIX [format [msgcat::mc "Unpacking archive for %s %s_%s%s"] $portname $portversion $portrevision $portvariants]"

	return 0
}

proc unarchive_command_setup {args} {
	global unarchive.env unarchive.cmd
	global unarchive.pre_args unarchive.args unarchive.post_args
	global unarchive.type unarchive.path
	global os.platform os.version

	# Define appropriate unarchive command and options
	switch -regex ${unarchive.type} {
		cp(io|gz) {
			# don't use ditto on non-darwin OS's or on Jaguar
			if {${os.platform} != "darwin" || \
				(${os.platform} == "darwin" && [regexp {^6[.]} ${os.version}])} {
				set cpio "cpio"
				if {[catch {set cpio [binaryInPath $cpio]} errmsg] == 0} {
					ui_debug "Using $cpio"
					set unarchive.cmd "$cpio"
					set unarchive.pre_args {-i -v -c -H cpio}
					set unarchive.args "-I ${unarchive.path}"
				} else {
					ui_debug $errmsg
					return -code error "No '$cpio' was found on this system!"
				}
			} else {
				set ditto "ditto"
				if {[catch {set ditto [binaryInPath $ditto]} errmsg] == 0} {
					ui_debug "Using $ditto"
					set unarchive.cmd "$ditto"
					set unarchive.pre_args {-x -v -V --rsrc}
					set unarchive.args "${unarchive.path} ."
				} else {
					ui_debug $errmsg
					set cpio "cpio"
					if {[catch {set cpio [binaryInPath $cpio]} errmsg] == 0} {
						ui_debug "Using $cpio"
						set unarchive.cmd "$cpio"
						set unarchive.pre_args {-i -v -c -H cpio}
						set unarchive.args "-I ${unarchive.path}"
					} else {
						ui_debug $errmsg
						return -code error "Neither '$ditto' or '$cpio' were found on this system!"
					}
				}
			}
			if {[regexp {z$} ${unarchive.type}]} {
				set unarchive.pre_args "${unarchive.pre_args} -z"
			}
		}
		xar {
			set xar "xar"
			if {[catch {set xar [binaryInPath $xar]} errmsg] == 0} {
				ui_debug "Using $xar"
				set unarchive.cmd "$xar"
				set unarchive.pre_args {-xvpf}
				set unarchive.args "${unarchive.path} ."
			} else {
				ui_debug $errmsg
				return -code error "No '$xar' was found on this system!"
			}
		}
		t(ar|gz) {
			set gnutar "gnutar"
			if {[catch {set gnutar [binaryInPath $gnutar]} errmsg] == 0} {
				ui_debug "Using $gnutar"
				set unarchive.cmd "$gnutar"
				if {[regexp {z$} ${unarchive.type}]} {
					set unarchive.pre_args {-zxvf}
				} else {
					set unarchive.pre_args {-xvf}
				}
				set unarchive.args "${unarchive.path} ."
			} else {
				ui_debug $errmsg
				set gtar "gtar"
				if {[catch {set gtar [binaryInPath $gtar]} errmsg] == 0} {
					ui_debug "Using $gtar"
					set unarchive.cmd "$gtar"
					if {[regexp {z$} ${unarchive.type}]} {
						set unarchive.pre_args {-zxvf}
					} else {
						set unarchive.pre_args {-xvf}
					}
					set unarchive.args "${unarchive.path} ."
				} else {
					ui_debug $errmsg
					set tar "tar"
					if {[catch {set tar [binaryInPath $tar]} errmsg] == 0} {
						ui_debug "Using $tar"
						set unarchive.cmd "$tar"
						set unarchive.pre_args {-xvf}
						if {[regexp {z$} ${unarchive.type}]} {
							set unarchive.args {-}
							set gzip "gzip"
							if {[catch {set gzip [binaryInPath $gzip]} errmsg] == 0} {
								ui_debug "Using $gzip"
								set unarchive.env "$gzip -d -c ${unarchive.path} |"
							} else {
								ui_debug $errmsg
								return -code error "No '$gzip' was found on this system!"
							}
						} else {
							set unarchive.args "${unarchive.path}"
						}
					} else {
						ui_debug $errmsg
						return -code error "None of '$gnutar', '$gtar', or '$tar' were found on this system!"
					}
				}
			}
		}
		default {
			return -code error "Invalid port archive type '${unarchive.type}' specified!"
		}
	}

	return 0
}

proc unarchive_main {args} {
	global UI_PREFIX
	global portname portversion portrevision portvariants
	global unarchive.dir unarchive.file

	# Setup unarchive command
	unarchive_command_setup

	# Create destination directory for unpacking
	if {![file isdirectory ${unarchive.dir}]} {
		file mkdir ${unarchive.dir}
	}

	# Unpack the archive
	ui_info "$UI_PREFIX [format [msgcat::mc "Extracting %s"] ${unarchive.file}]"
	system "[command unarchive]"

	return 0
}

proc unarchive_finish {args} {
	global UI_PREFIX target_state_fd unarchive.file portname workpath destpath

	# Reset state file with archive version
    set statefile [file join $workpath .darwinports.${portname}.state]
	file copy -force [file join $destpath "+STATE"] $statefile
	exec touch $statefile

    # Update the state from unpacked archive version
    set target_state_fd [open_statefile]

	# Archive unpacked, skip archive target
	write_statefile target "com.apple.archive" $target_state_fd
    
	# Cleanup all control files when finished
	set control_files [glob -nocomplain -types f [file join $destpath +*]]
	foreach file $control_files {
		ui_debug "Removing $file"
		file delete -force $file
	}

	ui_info "$UI_PREFIX [format [msgcat::mc "Archive %s unpacked"] ${unarchive.file}]"
	return 0
}

proc unarchive_main {args} {
	global UI_PREFIX
	global portname portversion portrevision portvariants
	global unarchive.dir unarchive.file

	# Setup unarchive command
	unarchive_command_setup

	# Create destination directory for unpacking
	if {![file isdirectory ${unarchive.dir}]} {
		file mkdir ${unarchive.dir}
	}

	# Unpack the archive
	ui_info "$UI_PREFIX [format [msgcat::mc "Extracting %s"] ${unarchive.file}]"
	system "[command unarchive]"

	return 0
}

proc unarchive_finish {args} {
	global UI_PREFIX target_state_fd unarchive.file portname workpath destpath

	# Reset state file with archive version
    set statefile [file join $workpath .darwinports.${portname}.state]
	file copy -force [file join $destpath "+STATE"] $statefile
	exec touch $statefile

    # Update the state from unpacked archive version
    set target_state_fd [open_statefile]

	# Archive unpacked, skip archive target
	write_statefile target "com.apple.archive" $target_state_fd
    
	# Cleanup all control files when finished
	set control_files [glob -nocomplain -types f [file join $destpath +*]]
	foreach file $control_files {
		ui_debug "Removing $file"
		file delete -force $file
	}

	ui_info "$UI_PREFIX [format [msgcat::mc "Archive %s unpacked"] ${unarchive.file}]"
	return 0
}

