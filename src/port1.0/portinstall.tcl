# et:ts=4
# portinstall.tcl
#
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

package provide portinstall 1.0
package require portutil 1.0

set com.apple.install [target_new com.apple.install install_main]
${com.apple.install} set runtype always
${com.apple.install} provides install
${com.apple.install} requires main fetch extract checksum patch configure build 
${com.apple.install} deplist depends_run depends_lib
${com.apple.install} set prerun install_start
${com.apple.install} set postrun install_registry

# define options
options install.target build.target.install
commands install

# Set defaults
default install.dir {${build.dir}}
default install.cmd {${build.cmd}}
default install.pre_args {${install.target}}
default install.target install
option_deprecate build.target.install install.target

# XXX nasty kludges to support contents lists AND destdir
option_proc contents install_useContents

proc install_useContents {option action args} {
    global install_useContents
    if {${action} == "set" || ${action} == "append"} {
    	set install_useContents yes
    }
}

set UI_PREFIX "---> "

proc install_start {args} {
    global UI_PREFIX portname destpath

    ui_msg "$UI_PREFIX [format [msgcat::mc "Installing %s"] ${portname}]"
	
	file mkdir ${destpath}
}

proc install_element {src_element dst_element} {
	# don't recursively copy directories
	if {[file isdirectory $src_element]} {
		file mkdir $dst_element
	} else {
		file copy -force $src_element $dst_element
	}

	set attributes [file attributes $src_element]	
	for {set i 0} {$i < [llength $attributes]} {incr i} {
		set opt [lindex $attributes $i]
		incr i
		set arg [lindex $attributes $i]
		file attributes $dst_element $opt $arg
	}
}

proc directory_dig {rootdir workdir {cwd ""}} {
    global installPlist
    set pwd [pwd]
    if [catch {cd $workdir} err] {
	puts $err
	return
    }

    foreach name [readdir .] {
	if {[string match $name "."] || [string match $name ".."]} {
	    continue
	}
	set element [file join $cwd $name]

	# XXX jpm's cross-platform code to find file separator
	# replace with [file seperator] with tcl 8.4
	if {![info exists root]} {
	    if {[string match [file tail "/monkey"] "monkey"]} {
		set root "/"
	    } elseif {[string match [file tail ":monkey"] "monkey"]} {
		set root ":" 
	    } else {
		set root "\\"		
	    }
	}

	set dst_element [file join $root $element]
	set src_element [file join $rootdir $element]
	# overwrites files but not directories
	if {![file exists $dst_element] || ![file isdirectory $dst_element]} {
	    ui_debug "installing file: $dst_element"
	    install_element $src_element $dst_element
	    lappend installPlist $dst_element
	}
	if {[file isdirectory $name] && [file type $name] != "link"} {
	    directory_dig $rootdir $name [file join $cwd $name]
	}
    }
    cd $pwd
}

proc install_main {args} {
    global install_useContents destpath
    system "[command install]"
    if {![tbool install_useContents]} {
        directory_dig ${destpath} ${destpath}
    }
    return 0
}

proc install_registry {args} {
    global portname portversion portpath categories description long_description homepage depends_run installPlist package-install uninstall workdir worksrcdir prefix UI_PREFIX contents install_useContents
    if {![tbool install_useContents]} {
        set _installPlist $installPlist
    } else {
        set _installPlist $contents
    }

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
    if [info exists homepage] {
	registry_store $rhandle [concat homepage ${homepage}]
    }
    if [info exists depends_run] {
	registry_store $rhandle [list run_depends $depends_run]
    }
    if [info exists package-install] {
	registry_store $rhandle [concat package-install ${package-install}]
    }
    if [info exists _installPlist] {
	registry_store $rhandle [list contents [fileinfo_for_index $_installPlist]]
    }
    if {[info proc pkg_uninstall] == "pkg_uninstall"} {
	registry_store $rhandle [list uninstall [proc_disasm pkg_uninstall]]
    }
    registry_close $rhandle
    return 0
}
