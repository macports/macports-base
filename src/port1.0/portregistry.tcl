# ex:ts=4
# portregistry.tcl
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

package provide portregistry 1.0
package require portutil 1.0

set com.apple.registry [target_new com.apple.registry registry_main]
${com.apple.registry} provides registry
${com.apple.registry} requires main fetch extract checksum patch configure build install 
${com.apple.registry} deplist depends_run depends_lib
${com.apple.registry} set prerun registry_start

# define options
options contents long_description description registry.nochecksum registry.path registry.nobzip registry.contents_recurse

# Export options via PortInfo
options_export description long_description

default registry.path {[file join ${portdbpath} receipts]}

set UI_PREFIX "---> "

proc registry_start {args} {
    global UI_PREFIX portname

    ui_msg "$UI_PREFIX Adding $portname to registry, this may take a moment..."
}

# For now, just write stuff to a file for debugging.

proc registry_new {portname {portversion 1.0}} {
    global _registry_name registry.path

    file mkdir ${registry.path}
    set _registry_name [file join ${registry.path} $portname-$portversion]
    system "rm -f ${_registry_name}.tmp"
    set rhandle [open ${_registry_name}.tmp w 0644]
    puts $rhandle "\# Format: var value ... {contents {filename uid gid mode size {md5}} ... }"
    return $rhandle
}

proc registry_exists {portname {portversion 0}} {
    global registry.path

    # regex match case
    if {$portversion == 0} {
	set x [glob -nocomplain [file join ${registry.path} ${portname}-*]]
	if [string length $x] {
	    set matchfile [lindex $x 0]
	} else {
	    set matchfile ""
	}
    } else {
	set matchfile [file join ${registry.path} ${portname}-${portversion}]
    }

    # Might as well bail out early if no file to match
    if ![string length $matchfile] {
	return ""
    }

    if [file exists $matchfile] {
	return $matchfile
    }
    if [file exists ${matchfile}.bz2] {
	return ${matchfile}.bz2
    }
    return ""
}

proc registry_store {rhandle data} {
    puts $rhandle $data
}

proc registry_fetch {rhandle} {
    return -1
}

proc registry_traverse {func} {
    return -1
}

proc registry_close {rhandle} {
    global _registry_name
    global registry.nobzip

    close $rhandle
    system "mv ${_registry_name}.tmp ${_registry_name}"
    if {[file exists ${_registry_name}] && [file exists /usr/bin/bzip2] && ![info exists registry.nobzip]} {
	system "/usr/bin/bzip2 -f ${_registry_name}"
    }
}

proc registry_delete {portname {portversion 1.0}} {
    global registry.path

    # Try both versions, just to be sure.
    exec rm -f [file join ${registry.path} ${portname}-${portversion}]
    exec rm -f [file join ${registry.path} ${portname}-${portversion}].bz2
}

proc fileinfo_for_file {fname} {
    global registry.nochecksum

    if ![catch {file stat $fname statvar}] {
	if {![tbool registry.nochecksum] && [file isfile $fname]} {
	    set md5regex "^(MD5)\[ \]\\((.+)\\)\[ \]=\[ \](\[A-Za-z0-9\]+)\n$"
	    set pipe [open "|md5 \"$fname\"" r]
	    set line [read $pipe]
	    if {[regexp $md5regex $line match type filename sum] == 1} {
		close $pipe
		set line [string trimright $line "\n"]
		return [list $fname $statvar(uid) $statvar(gid) $statvar(mode) $statvar(size) $line]
	    }
	    close $pipe
	} else {
	    return  [list $fname $statvar(uid) $statvar(gid) $statvar(mode) $statvar(size) "MD5 ($fname) NONE"]
	}
    }
    return {}
}

proc fileinfo_for_entry {rval dir entry} {
    global registry.contents_recurse UI_PREFIX

    upvar $rval myrval
    set path [file join $dir $entry]
    if {[file isdirectory $path] && [tbool registry.contents_recurse]} {
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
    }
    lappend myrval [fileinfo_for_file $path]
    return $myrval
}

proc fileinfo_for_index {flist} {
    global prefix registry.contents_recurse UI_PREFIX

    set rval {}
    foreach file $flist {
	if [string match /* $file] {
	    set fname $file
	    set dir /
	} else {
	    set fname [file join $prefix $file]
	    set dir $prefix
	}
	if {[file isdirectory $fname] && [tbool registry.contents_recurse]} {
	    ui_msg "$UI_PREFIX Warning: Registry adding contents of directory $fname"
	}
	fileinfo_for_entry rval $dir $file
    }
    return $rval
}

proc proc_disasm {pname} {
    set p "proc "
    append p $pname " {"
    set space ""
    foreach arg [info args $pname] {
	if [info default $pname $arg value] {
	    append p "$space{" [list $arg $value] "}"
	} else {
	    append p $space $arg
	}
	set space " "
    }
    append p "} {" [info body $pname] "}"
    return $p
}

proc registry_main {args} {
    global portname portversion portpath categories description long_description depends_run contents package-install uninstall workdir worksrcdir prefix UI_PREFIX

    # Package installed successfully, so now we must register it
    set rhandle [registry_new $portname $portversion]

    registry_store $rhandle [list prefix $prefix]
    registry_store $rhandle [list categories $categories]
    if [info exists description] {
	registry_store $rhandle [concat description $description]
    }
    if [info exists long_description] {
	registry_store $rhandle [concat long_description ${long_description}]
    }
    if [info exists depends_run] {
	registry_store $rhandle [list run_depends $depends_run]
    }
    if [info exists package-install] {
	registry_store $rhandle [concat package-install ${package-install}]
    }
    if [info exists contents] {
	# If it's a list, try and split it up.
	if {[llength $contents] == 1} {
	    set x [list contents [eval fileinfo_for_index $contents]]
	} else {
	    set x [list contents [fileinfo_for_index $contents]]
	}
	registry_store $rhandle $x
    }
    if {[info proc pkg_uninstall] == "pkg_uninstall"} {
	registry_store $rhandle [list uninstall [proc_disasm pkg_uninstall]]
    }
    registry_close $rhandle
    return 0
}
