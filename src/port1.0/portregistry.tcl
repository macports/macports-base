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

register com.apple.registry target registry_main registry_init
register com.apple.registry provides registry
register com.apple.registry requires main fetch extract checksum patch configure build install depends_run depends_lib

# define options
options contents description registry.nochecksum registry.path

default registry.path /Library/Receipts/darwinports

set UI_PREFIX "---> "

# For now, just write stuff to a file for debugging.

proc registry_new {portname {portversion 1.0}} {
    global _registry_name registry.path

    system "mkdir -p ${registry.path}"
    set _registry_name [file join ${registry.path} $portname-$portversion]
    return [open $_registry_name w 0644]
}

proc registry_exists {portname {portversion 1.0}} {
    global registry.path

    if [file exists [file join ${registry.path} $portname-$portversion]] {
	return [file join ${registry.path} $portname-$portversion]
    }
    if [file exists [file join ${registry.path} $portname-$portversion].bz2] {
	return [file join ${registry.path} $portname-$portversion].bz2
    }
    return ""
}

proc registry_store {rhandle data} {
    puts $rhandle "\# Format: {{var value} {contents {filename uid gid mode size {md5}} ... }}"
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

    close $rhandle
    if {[file exists $_registry_name] && [file exists /usr/bin/bzip2]} {
	system "rm -f ${_registry_name}.bz2"
	system "/usr/bin/bzip2 $_registry_name"
    }
}

proc registry_delete {portname {portversion 1.0}} {
    global registry.path

    # Try both versions, just to be sure.
    system "rm -f [file join ${registry.path} $portname-$portversion]"
    system "rm -f [file join ${registry.path} $portname-$portversion].bz2"
}

proc fileinfo_for_file {fname} {
    global registry.nochecksum

    if ![catch {file stat $fname statvar}] {
	if ![tbool registry.nochecksum] {
	    set md5regex "^(MD5)\[ \]\\(($fname)\\)\[ \]=\[ \](\[A-Za-z0-9\]+)\n$"
	    set pipe [open "|md5 $fname" r]
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
		fileinfo_for_file $subpath
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

proc registry_init {args} {
    return 0
}

proc registry_main {args} {
    global portname portversion portpath categories description depends_run contents pkg_install pkg_deinstall workdir worksrcdir prefix UI_PREFIX

    # Package installed successfully, so now we must register it
    set rhandle [registry_new $portname $portversion]
    ui_msg "$UI_PREFIX Adding $portname to registry, this may take a moment..."
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
    return 0
}
