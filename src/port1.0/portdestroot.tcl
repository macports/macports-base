# et:ts=4
# portdestroot.tcl
# $Id$
#
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
# Copyright (c) 2004 - 2005 Robert Shaw <rshaw@opendarwin.org>
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

package provide portdestroot 1.0
package require portutil 1.0

set com.apple.destroot [target_new com.apple.destroot destroot_main]
target_provides ${com.apple.destroot} destroot
target_requires ${com.apple.destroot} main fetch extract checksum patch configure build
target_prerun ${com.apple.destroot} destroot_start
target_postrun ${com.apple.destroot} destroot_finish

# define options
options destroot.target destroot.destdir destroot.clean destroot.keepdirs destroot.umask
options startupitem.create startupitem.requires startupitem.init
options startupitem.name startupitem.start startupitem.stop startupitem.restart
options startupitem.type startupitem.executable
options startupitem.pidfile startupitem.logfile startupitem.logevents
commands destroot

# Set defaults
default destroot.dir {${build.dir}}
default destroot.cmd {${build.cmd}}
default destroot.pre_args {${destroot.target}}
default destroot.target install
default destroot.post_args {${destroot.destdir}}
default destroot.destdir {DESTDIR=${destroot}}
default destroot.umask {$system_options(destroot_umask)}
default destroot.clean no
default destroot.keepdirs ""

default startupitem.name		{${portname}}
default startupitem.init		""
default startupitem.start		""
default startupitem.stop		""
default startupitem.restart		""
default startupitem.requires	""
default startupitem.executable	""
default startupitem.type		{$system_options(startupitem_type)}
default startupitem.pidfile		""
default startupitem.logfile		""
default startupitem.logevents	no

set_ui_prefix

namespace eval destroot {
	# Save old umask
	variable oldmask
}

proc destroot_start {args} {
    global UI_PREFIX prefix portname destroot portresourcepath os.platform destroot.clean
    global destroot::oldmask destroot.umask
    
    ui_msg "$UI_PREFIX [format [msgcat::mc "Staging %s into destroot"] ${portname}]"

    set oldmask [umask ${destroot.umask}]
    
    if { ${destroot.clean} == "yes" } {
	system "rm -Rf \"${destroot}\""
    }
    
    file mkdir "${destroot}"
    if { ${os.platform} == "darwin" } {
	system "cd \"${destroot}\" && mtree -e -U -f ${portresourcepath}/install/macosx.mtree"
    }
    file mkdir "${destroot}/${prefix}"
    system "cd \"${destroot}/${prefix}\" && mtree -e -U -f ${portresourcepath}/install/prefix.mtree"
}

proc destroot_main {args} {
    command_exec destroot
    return 0
}

proc destroot_finish {args} {
    global UI_PREFIX destroot prefix portname startupitem.create destroot::oldmask
	global os.platform os.version

    # Create startup-scripts/items
    if {[tbool startupitem.create]} {
        package require portstartupitem 1.0
        startupitem_create
    }

    # Prune empty directories in ${destroot}
    set exclude_dirs [list]
    set exclude_phrase ""
    foreach path [option destroot.keepdirs] {
		if {![file isdirectory ${path}]} {
			xinstall -m 0755 -d ${path}
		}
		if {![file exists ${path}/.turd_${portname}]} {
			xinstall -c -m 0644 /dev/null ${path}/.turd_${portname}
		}
    	lappend exclude_dirs "-path \"${path}\""
    }
    if { [llength ${exclude_dirs}] > 0 } {
    	set exclude_phrase "! \\( [join ${exclude_dirs} " -or "] \\)"
    }
    catch {system "find \"${destroot}\" -depth -type d ${exclude_phrase} -exec rmdir -- \{\} \\; 2>/dev/null"}

    # Compress all manpages with gzip (instead)
	# but NOT on Jaguar (Darwin 6.x)
	if {![regexp {darwin6} "${os.platform}${os.version}"]} {
    set manpath "${destroot}${prefix}/share/man"
    if {[file isdirectory ${manpath}] && [file type ${manpath}] == "directory"} {
	ui_info "$UI_PREFIX [format [msgcat::mc "Compressing man pages for %s"] ${portname}]"
	set found 0
	set manlinks [list]
	foreach mandir [readdir "${manpath}"] {
	    if {![regexp {^(cat|man)(.)$} ${mandir} match ignore manindex]} { continue }
	    set mandirpath [file join ${manpath} ${mandir}]
	    if {[file isdirectory ${mandirpath}] && [file type ${mandirpath}] == "directory"} {
		ui_debug "Scanning ${mandir}"
		foreach manfile [readdir ${mandirpath}] {
		    set manfilepath [file join ${mandirpath} ${manfile}]
		    if {[file isfile ${manfilepath}] && [file type ${manfilepath}] == "file"} {
			if {[regexp "^(.*\[.\]${manindex}\[a-z\]*)\[.\]gz\$" ${manfile} gzfile manfile]} {
			    set found 1
			    system "cd ${manpath} && \
								gunzip -f [file join ${mandir} ${gzfile}] && \
								gzip -9vf [file join ${mandir} ${manfile}]"
			} elseif {[regexp "^(.*\[.\]${manindex}\[a-z\]*)\[.\]bz2\$" ${manfile} bz2file manfile]} {
			    set found 1
			    system "cd ${manpath} && \
								bunzip2 -f [file join ${mandir} ${bz2file}] && \
								gzip -9vf [file join ${mandir} ${manfile}]"
			} elseif {[regexp "\[.\]${manindex}\[a-z\]*\$" ${manfile}]} {
			    set found 1
			    system "cd ${manpath} && \
								gzip -9vf [file join ${mandir} ${manfile}]"
			}
			set gzmanfile ${manfile}.gz
			set gzmanfilepath [file join ${mandirpath} ${gzmanfile}]
			if {[file exists ${gzmanfilepath}]} {
			    set desired 00444
			    set current [file attributes ${gzmanfilepath} -permissions]
			    if {$current != $desired} {
				ui_info "[file join ${mandir} ${gzmanfile}]: changing permissions from $current to $desired"
				file attributes ${gzmanfilepath} -permissions $desired
			    }
			}
		    } elseif {[file type ${manfilepath}] == "link"} {
			lappend manlinks [file join ${mandir} ${manfile}]
		    }
		}
	    }
	}
	if {$found == 1} {
	    # check man page links and rename/repoint them if necessary
	    foreach manlink $manlinks {
		set manlinkpath [file join $manpath $manlink]
		# if link destination is not gzipped, check it
		set manlinksrc [file readlink $manlinkpath]
		if {![regexp "\[.\]gz\$" ${manlinksrc}]} {
		    set mandir [file dirname $manlink]
		    set mandirpath [file join $manpath $mandir]
		    set pwd [pwd]
		    if {[catch {cd $mandirpath} err]} {
			puts $err
			return
		    }
		    # if gzipped destination exists, fix link
		    if {[file isfile ${manlinksrc}.gz]} {
			# if actual link name does not end with gz, rename it
			if {![regexp "\[.\]gz\$" ${manlink}]} {
			    ui_debug "renaming link: $manlink to ${manlink}.gz"
			    file rename $manlinkpath ${manlinkpath}.gz
			    set manlink ${manlink}.gz
			    set manlinkpath [file join $manpath $manlink]
			}
			# repoint the link
			ui_debug "repointing link: $manlink from $manlinksrc to ${manlinksrc}.gz"
			file delete $manlinkpath
			system "ln -s \"${manlinksrc}.gz\" \"$manlinkpath\""
		    }
		    cd $pwd
		}
	    }
	} else {
	    ui_debug "No man pages found to compress."
	}
    }
	} else {
	    ui_debug "No man page compression on ${os.platform}${os.version}."
    }

	if [file exists "${destroot}${prefix}/share/info/dir"] {
		ui_debug "Deleting stray info/dir file."
	    file delete "${destroot}${prefix}/share/info/dir"
	}
    # Restore umask
    umask $oldmask

    return 0
}
