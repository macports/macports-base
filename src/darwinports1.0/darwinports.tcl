#!/usr/bin/env tclsh8.3
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
	variable bootstrap_options "portdbpath libpath auto_path sources_conf"
	variable portinterp_options "portdbpath portpath auto_path portconf portdefaultconf"
	variable uniqid 0
}

proc dportinit {args} {
    global auto_path env darwinports::portdbpath darwinports::bootstrap_options darwinports::uniqid darwinports::portinterp_options darwinports::portconf darwinports::portdefaultconf darwinports::sources darwinports::sources_conf

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

    if {![info exists portconf] && [file isfile /etc/ports/ports.conf]} {
	set portconf /etc/ports/ports.conf
	lappend conf_files /etc/ports/ports.conf
    }
    if [info exists conf_files] {
	foreach file $conf_files {
	    set fd [open $file r]
	    while {[gets $fd line] >= 0} {
		foreach option $bootstrap_options {
		    if {[regexp "^$option\[ \t\]+(\[A-Za-z0-9\./\]+$)" $line match val] == 1} {
			set $option $val
		    }
		}
	    }
        }
    }

    if {![info exists sources_conf]} {
        return -code error "sources_conf must be set in /etc/ports/ports.conf or in your .portsrc"
    }
    if {[catch {set fd [open $sources_conf r]} result]} {
        return -code error "$result"
    }
    while {[gets $fd line] >= 0} {
        if ![regexp {[\ \t]*#.+} $line] {
            lappend sources $line
	}
    }
    if ![info exists sources] {
        return -code error "No sources defined in $sources_conf"
    }

    if ![info exists portdbpath] {
	return -code error "portdbpath must be set in /etc/ports/ports.conf or in your ~/.portsrc"
    }
    if ![file isdirectory $portdbpath] {
	if ![file exists $portdbpath] {
	    if {[catch {file mkdir $portdbpath} result]} {
		return -code error "portdbpath $portdbpath does not exist and could not be created: $result"
	    }
	}
    }
    if ![file isdirectory $portdbpath] {
	return -code error "$portdbpath is not a directory. Please create the directory $portdbpath and try again"
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
    global darwinports::uniqid darwinports::portinterp_options darwinports::portdbpath darwinports::portconf darwinports::portdefaultconf auto_path
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

    # Create package require abstraction procedure
    $workername eval "proc PortSystem \{version\} \{ \n\
			package require port \$version \}"

    foreach proc {dportexec dportopen dportclose dportsearch dportmatch} {
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

proc darwinports::fetch_port {url} {
    global darwinports::portdbpath os.name
    set fetchdir [file join $portdbpath portdirs]
    set fetchfile [file tail $url]
    if {[catch {file mkdir $fetchdir} result]} {
        return -code error $result
    }
    if {![file writable $fetchdir]} {
    	return -code error "Port remote fetch failed: You do not have permission to write to $fetchdir"
    }
    if {${os.name} == "darwin"} {
	if {[catch {exec curl -s -S -o [file join $fetchdir $fetchfile] $url} result]} {
	    return -code error "Port remote fetch failed: $result"
	}
    } else {
	if {[catch {exec fetch -o [file join $fetchdir $fetchfile] $url} result]} {
	    return -code error "Port remote fetch failed: $result"
	}
    }
    if {[catch {cd $fetchdir} result]} {
	return -code error $result
    }
    if {[catch {exec tar -zxf $fetchfile} result]} {
	return -code error "Port extract failed: $result"
    }
    if {[regexp {(.+).tgz} $fetchfile match portdir] != 1} {
        return -code error "Can't decipher portdir from $fetchfile"
    }
    return [file join $fetchdir $portdir]
}

proc darwinports::getprotocol {url} {
    if {[regexp {(?x)([^:]+)://.+} $url match protocol] == 1} {
        return ${protocol}
    } else {
        return -code error "Can't parse url $url"
    }
}

proc darwinports::getportdir {url} {
    if {[regexp {(?x)([^:]+)://(.+)} $url match protocol string] == 1} {
        switch -regexp -- ${protocol} {
            {^file$} { return $string}
	    {http|ftp} { return [darwinports::fetch_port $url] }
            default { return -code error "Unsupported protocol $protocol" }
        }
    } else {
        return -code error "Can't parse url $url"
    }
}

proc dportopen {porturl {options ""} {variations ""}} {
    global darwinports::uniqid darwinports::portinterp_options darwinports::portdbpath darwinports::portconf darwinports::portdefaultconf auto_path

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
    set portdir [darwinports::getportdir $porturl]
    cd $portdir
    set portpath [pwd]
    set workername workername[incr uniqid]
    interp create $workername
    darwinports::worker_init $workername $portpath upoptions upvariations
    if ![file isfile Portfile] {
        return -code error "Could not find Portfile in $portdir"
    }
    $workername eval source Portfile

    # initialize the UI for the new port
    $workername eval ui_init

    return $workername
}

proc dportexec {workername target} {
    global darwinports::portinterp_options darwinports::uniqid

    $workername eval eval_variants variations
    return [$workername eval eval_targets $target]
}

proc darwinports::getindex {source} {
    global darwinports::portdbpath
    # Special case file:// sources
    if {[darwinports::getprotocol $source] == "file"} {
        return [file join [darwinports::getportdir $source] PortIndex]
    }
    regsub {://} $source {.} source_dir
    regsub -all {/} $source_dir {_} source_dir
    return [file join $portdbpath sources $source_dir PortIndex]
}

proc dportsync {args} {
    global darwinports::sources darwinports::portdbpath os.name

    foreach source $sources {
        # Special case file:// sources
        if {[darwinports::getprotocol $source] == "file"} {
            continue
        }
        set indexfile [darwinports::getindex $source]
	if {[catch {file mkdir [file dirname $indexfile]} result]} {
            return -code error $result
        }
	if {![file writable [file dirname $indexfile]]} {
	    return -code error "You do not have permission to write to [file dirname $indexfile]"
	}
	if {${os.name} == "darwin"} {
	    exec curl -s -S -o $indexfile $source/PortIndex
	} else {
	    exec fetch -o $indexfile $source/PortIndex
	}
    }
}

proc dportsearch {regexp} {
    global darwinports::portdbpath darwinports::sources
    set matches [list]

    foreach source $sources {
        if {[catch {set fd [open [darwinports::getindex $source] r]} result]} {
            return -code error "Can't open index file for source $source. Have you synced your source indexes?"
        }
        while {[gets $fd line] >= 0} {
            set name [lindex $line 0]
            if {[regexp -- $regexp $name] == 1} {
                gets $fd line
                array set portinfo $line
                if [info exists portinfo(portarchive)] {
		    set portinfo(porturl) ${source}/$portinfo(portarchive)
                } elseif [info exists portinfo(portdir)] {
                    set portinfo(porturl) ${source}/$portinfo(portdir)
                }
                lappend matches $name
                lappend matches $line
		set match 1
            } else {
                set len [lindex $line 1]
                seek $fd $len current
            }
        }
        close $fd
	if {[info exists match] && $match == 1} {
	    break
	}
    }
    return $matches
}

proc dportmatch {regexp} {
    global darwinports::portdbpath darwinports::sources
    foreach source $sources {
        if {[catch {set fd [open [darwinports::getindex $source] r]} result]} {
            return -code error "Can't open index file for source $source. Have you synced your source indexes?"
        }
        while {[gets $fd line] >= 0} {
            set name [lindex $line 0]
            if {[regexp -- $regexp $name] == 1} {
                gets $fd line
                array set portinfo $line
                if [info exists portinfo(portarchive)] {
                	set portinfo(porturl) ${source}/$portinfo(portarchive)
                } elseif [info exists portinfo(portdir)] {
                    set portinfo(porturl) ${source}/$portinfo(portdir)
                }
                close $fd
                return [array get portinfo]
            } else {
                set len [lindex $line 1]
                seek $fd $len current
            }
        }
        close $fd
    }
}

proc dportinfo {workername} {
    return [$workername eval array get PortInfo]
}

proc dportclose {workername} {
    interp delete $workername
}
