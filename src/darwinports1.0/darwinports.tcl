#!/usr/bin/tclsh
# darwinports.tcl
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
package provide darwinports 1.0
package require darwinportsui 1.0 

namespace eval darwinports {
	namespace export bootstrap_options portinterp_options uniqid 0
	variable bootstrap_options "sysportpath libpath auto_path"
	variable portinterp_options "sysportpath portpath auto_path portconf portdefaultconf"
	variable uniqid 0
}

proc dportinit {args} {
    global auto_path env darwinports::sysportpath darwinports::bootstrap_options darwinports::uniqid darwinports::portinterp_options darwinports::portconf darwinports::portdefaultconf

    if [file isfile /etc/defaults/ports.conf] {
    	set portdefaultconf /etc/defaults/ports.conf
	lappend conf_files /etc/defaults/ports.conf
    }

    if {[llength [array names env HOME]] > 0} {
	set HOME [lindex [array get env HOME] 1]
	if [file isfile [file join ${HOME} .portsrc]] {
	    set portconf [file join ${HOME} .portsrc]
	    lappend conf_files ${portconf}
	}
    }
    if {![info exists portconf] && [file isfile /etc/ports.conf]} {
	set portconf /etc/ports.conf
	lappend conf_files /etc/ports.conf
    }
    if [info exists conf_files] {
	foreach file $conf_files {
	    set fd [open $file r]
	    while {[gets $fd line] >= 0} {
		foreach option $bootstrap_options {
		    if {[regexp "^$option\[ \t\]+(\[A-Za-z0-9/\]+$)" $line match val] == 1} {
			set $option $val
		    }
		}
	    }
        }
    }

    if ![info exists sysportpath] {
	return -code error "sysportpath must be set in /etc/ports.conf or in your ~/.portsrc"
    }
    if ![file isdirectory $sysportpath] {
	return -code error "/etc/ports.conf or ~/.portsrc must contain a valid sysportpath directive"
    }
	
    if ![info exists libpath] {
	set libpath /opt/local/share/darwinports/Tcl
    }

    if [file isdirectory $libpath] {
	lappend auto_path $libpath
    } else {
	return -code error "Library directory '$libpath' must exist"
    }
}

proc darwinports::worker_init {workername portpath options variations} {
    global darwinports::uniqid darwinports::portinterp_options darwinports::sysportpath darwinports::portconf darwinports::portdefaultconf auto_path
    if {$options == ""} {
        set upoptions ""
    } else {
	upvar $options upoptions
    }

    if {$variations == ""} {
	set upvariations ""
    } else {
	upvar $variations upvariations
    }

    foreach proc {dportexec dportopen dportclose} {
		$workername alias $proc $proc
    }

    # instantiate the UI functions
    foreach proc {ui_init ui_enable ui_disable ui_enabled ui_puts ui_debug ui_info ui_msg ui_error ui_gets ui_yesno ui_confirm ui_display} {
        $workername alias $proc $proc
    }

    foreach proc {ports_verbose ports_quiet ports_debug} {
        $workername alias $proc $proc
    }

    foreach opt $portinterp_options {
        if [info exists $opt] {
            $workername eval set system_options($opt) \"[set $opt]\"
            $workername eval set $opt \"[set $opt]\"
        }
    }

    foreach opt [array names upoptions] {
        $workername eval set user_options($opt) $upoptions($opt)
        $workername eval set $opt $upoptions($opt)
    }

    foreach var [array names upvariations] {
        $workername eval set variations($var) $upvariations($var)
    }
}

proc darwinports::parse_url {url} {
    if {[regexp {(?x)([^:]+)://(.+)} $url match protocol string] == 1} {
        switch -exact -- ${protocol} {
            file { return $string}
            default { return -code error "Unsupported protocol $protocol" }
        }
    } else {
        return -code error "Can't parse url $url"
    }
}

proc dportopen {porturl {options ""} {variations ""}} {
    global darwinports::uniqid darwinports::portinterp_options darwinports::sysportpath darwinports::portconf darwinports::portdefaultconf auto_path

    if {$options == ""} {
	set upoptions ""
    } else {
	upvar $options upoptions
    }

    if {$variations == ""} {
	set upvariations ""
    } else {
	upvar $variations upvariations
    }
    set portdir [darwinports::parse_url $porturl]
    cd $portdir
    set portpath [pwd]
    set workername workername[incr uniqid]
    interp create $workername
    darwinports::worker_init $workername $portpath upoptions upvariations
    $workername eval source Portfile

    # initialize the UI for the new port
    $workername eval ui_init

    return $workername
}

proc dportexec {workername target} {
    global darwinports::portinterp_options darwinports::uniqid

    $workername eval eval_variants variants variations
    return [$workername eval eval_targets targets $target]
}

proc dportsearch {regexp} {
    global darwinports::sysportpath
    set matches [list]

    set fd [open $sysportpath/PortIndex r]
    while {[gets $fd line] >= 0} {
        set name [lindex $line 0]
        if {[regexp -- $regexp $name] == 1} {
                gets $fd line
                array set portinfo $line
		set portinfo(porturl) "file://${sysportpath}${portinfo(portdir)}"
		lappend matches $name
		lappend matches $line
        } else {
                set len [lindex $line 1]
                seek $fd $len current
        }
    }
    close $fd
    return $matches
}

proc dportmatch {regexp} {
    global darwinports::sysportpath
    set fd [open $sysportpath/PortIndex r]
    while {[gets $fd line] >= 0} {
    	set name [lindex $line 0]
	if {[regexp -- $regexp $name] == 1} {
		gets $fd line
		array set portinfo $line
		set portinfo(porturl) "file://${sysportpath}${portinfo(portdir)}"
		close $fd
		return [array get portinfo]
	} else {
		set len [lindex $line 1]
		seek $fd $len current
	}
    }
    close $fd
}

proc dportinfo {workername} {
    return [$workername eval array get PortInfo]
}

proc dportclose {workername} {
    interp delete $workername
}
