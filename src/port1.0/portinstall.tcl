# ex:ts=4
# portinstall.tcl
#
# Copyright (c) 2002 Apple Computer, Inc.
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

package provide portinstall 1.0
package require portutil 1.0
package require portregistry 1.0

register com.apple.install target install_main install_init
register com.apple.install provides install
register com.apple.install requires main fetch extract checksum patch configure build depends_run depends_lib

# define options
options make.cmd make.type make.target.install contents description

set UI_PREFIX "---> "

proc fileinfo_for_file {fname} {
    if ![catch {file stat $fname statvar}] {
	set md5regex "^(MD5)\[ \]\\(($fname)\\)\[ \]=\[ \](\[A-Za-z0-9\]+)\n$"
	set pipe [open "|md5 $fname" r]
	set line [read $pipe]
	if {[regexp $md5regex $line match type filename sum] == 1} {
	    close $pipe
	    return [list $fname $statvar(uid) $statvar(gid) $statvar(mode) $statvar(size) $line]
	}
	close $pipe
    }
    return {}
}

proc fileinfo_for_entry {rval dir entry} {
    upvar $rval myrval
    set path [file join $dir $entry]
    if [file isdirectory $path] {
	foreach name [readdir $path] {
	    if {[string match $name .] || [string match $name ..]} {
		continue
	    }
	    set subpath [file join $path $name]
	    if [file isdirectory $subpath] {
		fileinfo_for_entry myrval $subpath ""
	    } elseif [file readable $subpath] {
		lappend myrval [fileinfo_for_file $subpath]
	    }
	}
    } elseif [file readable $path] {
	lappend myrval [fileinfo_for_file $path]
    }
    return $myrval
}

proc fileinfo_for_index {flist} {
    global prefix
    set rval {}
    foreach file $flist {
	if [string match /* $file] {
	    fileinfo_for_entry rval / $file
	} else {
	    fileinfo_for_entry rval $prefix $file
	}
    }
    return $rval
}

proc proc_disasm {pname} {
    return [list proc $pname [list [info args $pname]] [info body $pname]]
}

proc install_init {args} {
    global make.target.install
    default make.target.install install
}

proc install_main {args} {
    global portname portversion portpath categories description depends_run contents pkg_install pkg_deinstall workdir worksrcdir prefix make.type make.cmd make.worksrcdir make.target.install UI_PREFIX

    if [info exists make.worksrcdir] {
	set configpath ${portpath}/${workdir}/${worksrcdir}/${make.worksrcdir}
    } else {
	set configpath ${portpath}/${workdir}/${worksrcdir}
    }

    cd $configpath
    ui_msg "$UI_PREFIX Installing $portname with target ${make.target.install}"
    if ![catch {system "env PREFIX=${prefix} ${make.cmd} ${make.target.install}"}] {
	# it installed successfully, so now we must register it
	set rhandle [registry_new $portname $portversion]
	ui_msg "$UI_PREFIX Registering $portname"
	set data {}
	lappend data [list prefix $prefix]
	lappend data [list categories $categories]
	if [info exists description] {
	    lappend data [list description $description]
	}
	if [info exists depends_run] {
	    lappend data [list run_depends $depends_run]
	}
	if [info exists contents] {
	    set plist [fileinfo_for_index $contents]
	    lappend data [list contents $plist]
	}
	if {[info proc pkg_install] == "pkg_install"} {
	    lappend data [list pkg_install [proc_disasm pkg_install]]
	}
	if {[info proc pkg_deinstall] == "pkg_deinstall"} {
	    lappend data [list pkg_deinstall [proc_disasm pkg_deinstall]]
	}
	registry_store $rhandle $data
	registry_close $rhandle
    } else {
	ui_error "Installation failed."
	return -1
    }
    return 0
}
