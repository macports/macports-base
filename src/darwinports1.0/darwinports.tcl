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
package require darwinports_dlist 1.0

namespace eval darwinports {
    namespace export bootstrap_options portinterp_options open_dports
    variable bootstrap_options "portdbpath libpath auto_path sources_conf prefix"
    variable portinterp_options "portdbpath portpath auto_path prefix portsharepath registry.path"
	
    variable open_dports {}
}

# Provided UI instantiations
# For standard messages, the following priorities are defined
#     debug, info, msg, warn, error
# Clients of the library are expected to provide ui_puts with the following prototype.
#     proc ui_puts {message}
# message is a tcl list of array element pairs, defined as such:
#     version   - ui protocol version
#     priority  - message priority
#     data      - message data
# ui_puts should handle the above defined priorities

foreach priority "debug info msg error warn" {
    eval "proc ui_$priority {str} \{ \n\
	set message(priority) $priority \n\
	set message(data) \$str \n\
	ui_puts \[array get message\] \n\
    \}"
}

proc darwinports::ui_event {context message} {
    array set postmessage $message
    set postmessage(context) $context
    ui_puts [array get postmessage]
}

proc dportinit {args} {
    global auto_path env darwinports::portdbpath darwinports::bootstrap_options darwinports::portinterp_options darwinports::portconf darwinports::sources darwinports::sources_conf darwinports::portsharepath

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
			set darwinports::$option $val
			global darwinports::$option
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
        if ![regexp {[\ \t]*#.*|^$} $line] {
            lappend sources $line
	}
    }
    if ![info exists sources] {
	if [file isdirectory dports] {
	    set sources "file://[pwd]/dports"
	} else {
	    return -code error "No sources defined in $sources_conf"
	}
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

    set portsharepath ${prefix}/share/darwinports
    if ![file isdirectory $portsharepath] {
	return -code error "Data files directory '$portsharepath' must exist"
    }
    
    if ![info exists libpath] {
	set libpath "${prefix}/share/darwinports/Tcl"
    }

    if [file isdirectory $libpath] {
		lappend auto_path $libpath
		set darwinports::auto_path $auto_path

		# XXX: not sure if this the best place, but it needs to happen
		# early, and after auto_path has been set.  Or maybe Pextlib
		# should ship with darwinports1.0 API?
		package require Pextlib 1.0
    } else {
		return -code error "Library directory '$libpath' must exist"
    }
}

proc darwinports::worker_init {workername portpath options variations} {
    global darwinports::portinterp_options auto_path

    # Create package require abstraction procedure
    $workername eval "proc PortSystem \{version\} \{ \n\
			package require port \$version \}"

    foreach proc {dportexec dportopen dportclose dportsearch} {
        $workername alias $proc $proc
    }

    # instantiate the UI call-back
    $workername alias ui_event darwinports::ui_event $workername

	# xxx: find a better home for this registry cruft--like six feet under.
	global darwinports::portdbpath darwinports::registry.path
	if {[info exists darwinports::portdbpath] && ![info exists darwinports::registry.path]} {
		set darwinports::registry.path [file join ${darwinports::portdbpath} receipts]
	}
	$workername alias registry_new dportregistry::new $workername
	$workername alias registry_store dportregistry::store
	$workername alias registry_delete dportregistry::delete
	$workername alias registry_exists dportregistry::exists
	$workername alias registry_close dportregistry::close
	$workername alias fileinfo_for_index dportregistry::fileinfo_for_index
	$workername alias fileinfo_for_file dportregistry::fileinfo_for_file
	$workername alias fileinfo_for_entry dportregistry::fileinfo_for_entry

    foreach opt $portinterp_options {
	if ![info exists $opt] {
	    global darwinports::$opt
	}
        if [info exists $opt] {
            $workername eval set system_options($opt) \"[set $opt]\"
            $workername eval set $opt \"[set $opt]\"
        } #"
    }

    foreach {opt val} $options {
        $workername eval set user_options($opt) $val
        $workername eval set $opt $val
    }

    foreach {var val} $variations {
        $workername eval set variations($var) $val
    }
}

proc darwinports::fetch_port {url} {
    global darwinports::portdbpath tcl_platform
    set fetchdir [file join $portdbpath portdirs]
    set fetchfile [file tail $url]
    if {[catch {file mkdir $fetchdir} result]} {
        return -code error $result
    }
    if {![file writable $fetchdir]} {
    	return -code error "Port remote fetch failed: You do not have permission to write to $fetchdir"
    }
    if {${tcl_platform(os)} == "Darwin"} {
	if {[catch {exec curl -L -s -S -o [file join $fetchdir $fetchfile] $url} result]} {
	    return -code error "Port remote fetch failed: $result"
	}
    } else {
	if {[catch {exec fetch -q -o [file join $fetchdir $fetchfile] $url} result]} {
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

# dportopen
# Opens a DarwinPorts portfile specified by a URL.  The portfile is
# opened with the given list of options and variations.  The result
# of this function should be treated as an opaque handle to a
# DarwinPorts Portfile.

proc dportopen {porturl {options ""} {variations ""}} {
    global darwinports::portinterp_options darwinports::portdbpath darwinports::portconf darwinports::open_dports auto_path

	# Look for an already-open DPort with the same URL.
	# XXX: should compare options and variations here too.
	# if found, return the existing reference and bump the refcount.
	set dport [dlist_search $darwinports::open_dports porturl $porturl]
	if {$dport != {}} {
		set refcnt [ditem_key $dport refcnt]
		incr refcnt
		ditem_key $dport refcnt $refcnt
		return $dport
	}

	set portdir [darwinports::getportdir $porturl]
	cd $portdir
	set portpath [pwd]
	set workername [interp create]

	set dport [ditem_create]
	lappend darwinports::open_dports $dport
	ditem_key $dport porturl $porturl
	ditem_key $dport portpath $portpath
	ditem_key $dport workername $workername
	ditem_key $dport options $options
	ditem_key $dport variations $variations
	ditem_key $dport refcnt 1

    darwinports::worker_init $workername $portpath $options $variations
    if ![file isfile Portfile] {
        return -code error "Could not find Portfile in $portdir"
    }

    $workername eval source Portfile
	
    ditem_key $dport provides [$workername eval return \$portname]

    return $dport
}

### _dportsearchpath is private; subject to change without notice

proc _dportsearchpath {depregex search_path} {
    set found 0
    foreach path $search_path {
	if {![file isdirectory $path]} {
	    continue
	}
	foreach filename [readdir $path] {
	    if {[regexp $depregex $filename] == 1} {
		ui_debug "Found Dependency: path: $path filename: $filename regex: $depregex"
		set found 1
		break
	    }
	}
    }
    return $found
}

### _libtest is private; subject to change without notice
# XXX - Architecture specific
# XXX - Rely on information from internal defines in cctools/dyld:
# define DEFAULT_FALLBACK_FRAMEWORK_PATH
# /Library/Frameworks:/Library/Frameworks:/Network/Library/Frameworks:/System/Library/Frameworks
# define DEFAULT_FALLBACK_LIBRARY_PATH /lib:/usr/local/lib:/lib:/usr/lib
# Environment variables DYLD_FRAMEWORK_PATH, DYLD_LIBRARY_PATH,
# DYLD_FALLBACK_FRAMEWORK_PATH, and DYLD_FALLBACK_LIBRARY_PATH take precedence

proc _libtest {dport} {
    global env
    set depspec [ditem_key $dport depspec]
	set depregex [lindex [split $depspec :] 1]
	set prefix [_dportkey $dport prefix]
	
	if {[info exists env(DYLD_FRAMEWORK_PATH)]} {
	    lappend search_path $env(DYLD_FRAMEWORK_PATH)
	} else {
	    lappend search_path /Library/Frameworks /Network/Library/Frameworks /System/Library/Frameworks
	}
	if {[info exists env(DYLD_FALLBACK_FRAMEWORK_PATH)]} {
	    lappend search_path $env(DYLD_FALLBACK_FRAMEWORK_PATH)
	}
	if {[info exists env(DYLD_LIBRARY_PATH)]} {
	    lappend search_path $env(DYLD_LIBRARY_PATH)
	} else {
	    lappend search_path /lib /usr/local/lib /lib /usr/lib /usr/X11R6/lib ${prefix}/lib
	}
	if {[info exists env(DYLD_FALLBACK_LIBRARY_PATH)]} {
	    lappend search_path $env(DYLD_LIBRARY_PATH)
	}
	regsub {\.} $depregex {\.} depregex
	set depregex \^${depregex}\\.dylib\$
	
	return [_dportsearchpath $depregex $search_path]
}

### _bintest is private; subject to change without notice

proc _bintest {dport} {
    global env
    set depspec [ditem_key $dport depspec]
	set depregex [lindex [split $depspec :] 1]
	set prefix [_dportkey $dport prefix] 
	
	set search_path [split $env(PATH) :]
	
	set depregex \^$depregex\$
	
	return [_dportsearchpath $depregex $search_path]
}

### _pathtest is private; subject to change without notice

proc _pathtest {dport} {
    global env
    set depspec [ditem_key $dport depspec]
	set depregex [lindex [split $depspec :] 1]
	set prefix [_dportkey $dport prefix] 
    
	# separate directory from regex
	set fullname $depregex

	regexp {^(.*)/(.*?)$} "$fullname" match search_path depregex

	if {[string index $search_path 0] != "/"} {
		# Prepend prefix if not an absolute path
		set search_path "${prefix}/${search_path}"
	}
		
	set depregex \^$depregex\$
	
	return [_dportsearchpath $depregex $search_path]
}

### _dportest is private; may change without notice

proc _dporttest {dport} {
	# Check for the presense of the port in the registry
	set workername [ditem_key $dport workername]
	set res [$workername eval registry_exists \${portname} \${portversion}]
	if {$res != ""} {
		ui_debug "Found Dependency: receipt: $res"
		return 1
	} else {
		# The receipt test failed, use one of the depspec regex mechanisms
		set depspec [ditem_key $dport depspec]
		set type [lindex [split $depspec :] 0]
		switch $type {
			lib { return [_libtest $dport] }
			bin { return [_bintest $dport] }
			path { return [_pathtest $dport] }
			default {return -code error "unknown depspec type: $type"}
		}
		return 0
	}
}

### _dportexec is private; may change without notice

proc _dportexec {target dport} {
	# xxx: set the work path?
	set workername [ditem_key $dport workername]
	if {![catch {$workername eval eval_variants variations $target} result] && $result == 0 &&
		![catch {$workername eval eval_targets $target} result] && $result == 0} {
		# xxx: clean after installing?
		#$workername eval eval_targets clean
		return 0
	} else {
		# An error occurred.
		return 1
	}
}

# dportexec
# Execute the specified target of the given dport.

proc dportexec {dport target} {
    global darwinports::portinterp_options

	set workername [ditem_key $dport workername]

	# XXX: move this into dportopen?
	if {[$workername eval eval_variants variations $target] != 0} {
		return 1
	}
	
	# Before we build the port, we must build its dependencies.
	# XXX: need a more general way of comparing against targets
	set dlist {}
	if {$target == "configure" || $target == "build" || $target == "install" ||
		$target == "package" || $target == "mpkg" || $target == "rpmpackage" } {

		if {[dportdepends $dport 1 1] != 0} {
			return 1
		}
		
		# Select out the dependents along the critical path,
		# but exclude this dport, we might not be installing it.
		set dlist [dlist_append_dependents $darwinports::open_dports $dport {}]
		
		dlist_delete dlist $dport

		# install them
		set dlist [dlist_eval $dlist _dporttest [list _dportexec "install"]]
		
		if {$dlist != {}} {
			set errstring "The following dependencies failed to build:"
			foreach ditem $dlist {
				append errstring " [ditem_key $ditem provides]"
			}
			ui_error $errstring
			return 1
		}
	}
	
	# Build this port with the specified target
	return [$workername eval eval_targets $target]
	
	return 0
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
    global darwinports::sources darwinports::portdbpath tcl_platform

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
	if {${tcl_platform(os)} == "Darwin"} {
	    exec curl -L -s -S -o $indexfile $source/PortIndex
	} else {
	    exec fetch -q -o $indexfile $source/PortIndex
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
                    lappend line porturl ${source}/$portinfo(portarchive)
                } elseif [info exists portinfo(portdir)] {
                    lappend line porturl ${source}/$portinfo(portdir)
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

proc dportinfo {dport} {
	set workername [ditem_key $dport workername]
    return [$workername eval array get PortInfo]
}

proc dportclose {dport} {
	global darwinports::open_dports
	set refcnt [ditem_key $dport refcnt]
	incr refcnt -1
	ditem_key $dport refcnt $refcnt
	if {$refcnt == 0} {
		dlist_delete darwinports::open_dports $dport
		set workername [ditem_key $dport workername]
		interp delete $workername
	}
}

##### Private Depspec API #####
# This API should be considered work in progress and subject to change without notice.
##### "

# _dportkey
# - returns a variable from the port's interpreter

proc _dportkey {dport key} {
	set workername [ditem_key $dport workername]
	return [$workername eval "return \$${key}"]
}

# dportdepends returns a list of dports which the given port depends on.
# - optionally includes the build dependencies in the list.
# - optionally recurses through the dependencies, looking for dependencies
#	of dependencies.

proc dportdepends {dport includeBuildDeps recurseDeps} {
	array set portinfo [dportinfo $dport]
	set depends {}
	if {[info exists portinfo(depends_run)]} { eval "lappend depends $portinfo(depends_run)" }
	if {[info exists portinfo(depends_lib)]} { eval "lappend depends $portinfo(depends_lib)" }
	if {$includeBuildDeps != "" && [info exists portinfo(depends_build)]} {
		eval "lappend depends $portinfo(depends_build)"
	}

	foreach depspec $depends {
		# grab the portname portion of the depspec
		set portname [lindex [split $depspec :] 2]
		
		# Find the porturl
		if {[catch {set res [dportsearch "^$portname\$"]} error]} {
			ui_error "Internal error: port search failed: $error"
			return 1
		}
		foreach {name array} $res {
			array set portinfo $array
			if {[info exists portinfo(porturl)]} {
				set porturl $portinfo(porturl)
				break
			}
		}

		if {![info exists porturl]} {
			ui_error "Dependency '$portname' not found."
			return 1
		}

		set options [ditem_key $dport options]
		set variations [ditem_key $dport variations]
		
		# XXX: This should use the depspec flavor of dportopen,
		# but for now, simply set the key directly.
		set subport [dportopen $porturl $options $variations]
		ditem_key $subport depspec $depspec

		# Append the sub-port's provides to the port's requirements list.
		ditem_append $dport requires "[ditem_key $subport provides]"

		if {$recurseDeps != ""} {
			set res [dportdepends $subport $includeBuildDeps $recurseDeps]
			if {$res != 0} {
				return $res
			}
		}
	}
	
	return 0
}

# Snarfed from portregistry.tcl
# For now, just write stuff to a file for debugging.

namespace eval dportregistry {}

proc dportregistry::new {workername portname {portversion 1.0}} {
    global _registry_name darwinports::registry.path

    file mkdir ${darwinports::registry.path}
    set _registry_name [file join ${darwinports::registry.path} $portname-$portversion]
    system "rm -f ${_registry_name}.tmp"
    set rhandle [open ${_registry_name}.tmp w 0644]
    puts $rhandle "\# Format: var value ... {contents {filename uid gid mode size {md5}} ... }"
	#interp share {} $rhandle $workername 
    return $rhandle
}

proc dportregistry::exists {portname {portversion 0}} {
    global darwinports::registry.path

    # regex match case
    if {$portversion == 0} {
	set x [glob -nocomplain [file join ${darwinports::registry.path} ${portname}-*]]
	if [string length $x] {
	    set matchfile [lindex $x 0]
	} else {
	    set matchfile ""
	}
    } else {
	set matchfile [file join ${darwinports::registry.path} ${portname}-${portversion}]
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

proc dportregistry::store {rhandle data} {
    puts $rhandle $data
}

proc dportregistry::fetch {rhandle} {
    return -1
}

proc dportregistry::traverse {func} {
    return -1
}

proc dportregistry::close {rhandle} {
    global _registry_name
    global registry.nobzip

    ::close $rhandle
    system "mv ${_registry_name}.tmp ${_registry_name}"
    if {[file exists ${_registry_name}] && [file exists /usr/bin/bzip2] && ![info exists registry.nobzip]} {
	system "/usr/bin/bzip2 -f ${_registry_name}"
    }
}

proc dportregistry::delete {portname {portversion 1.0}} {
    global darwinports::registry.path

    # Try both versions, just to be sure.
    exec rm -f [file join ${darwinports::registry.path} ${portname}-${portversion}]
    exec rm -f [file join ${darwinports::registry.path} ${portname}-${portversion}].bz2
}

proc dportregistry::fileinfo_for_file {fname} {
    if ![catch {file stat $fname statvar}] {
	if {[file isfile $fname]} {
	    set md5regex "^(MD5)\[ \]\\((.+)\\)\[ \]=\[ \](\[A-Za-z0-9\]+)\n$"
	    set pipe [open "|md5 \"$fname\"" r]
	    set line [read $pipe]
	    if {[regexp $md5regex $line match type filename sum] == 1} {
		::close $pipe
		set line [string trimright $line "\n"]
		return [list $fname $statvar(uid) $statvar(gid) $statvar(mode) $statvar(size) $line]
	    }
	    ::close $pipe
	} else {
	    return  [list $fname $statvar(uid) $statvar(gid) $statvar(mode) $statvar(size) "MD5 ($fname) NONE"]
	}
    }
    return {}
}

proc dportregistry::fileinfo_for_entry {rval dir entry} {
    upvar $rval myrval
    set path [file join $dir $entry]
    lappend myrval [dportregistry::fileinfo_for_file $path]
    return $myrval
}

proc dportregistry::fileinfo_for_index {flist} {
    global prefix

    set rval {}
    foreach file $flist {
	if [string match /* $file] {
	    set fname $file
	    set dir /
	} else {
	    set fname [file join $prefix $file]
	    set dir $prefix
	}
	dportregistry::fileinfo_for_entry rval $dir $file
    }
    return $rval
}

