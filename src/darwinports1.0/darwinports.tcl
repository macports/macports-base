# darwinports.tcl
#
# Copyright (c) 2002 Apple Computer, Inc.
# Copyright (c) 2004 Paul Guyot, Darwinports Team.
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
package require darwinports_index 1.0

namespace eval darwinports {
    namespace export bootstrap_options portinterp_options open_dports
    variable bootstrap_options "portdbpath libpath auto_path sources_conf prefix portdbformat portinstalltype"
    variable portinterp_options "portdbpath portpath auto_path prefix portsharepath registry.path registry.format registry.installtype"
	
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
    global auto_path env darwinports::portdbpath darwinports::bootstrap_options darwinports::portinterp_options darwinports::portconf darwinports::sources darwinports::sources_conf darwinports::portsharepath darwinports::registry.path darwinports::autoconf::dports_conf_path darwinports::registry.format darwinports::registry.installtype

    # first look at PORTSRC for testing/debugging
    if {[llength [array names env PORTSRC]] > 0} {
	set PORTSRC [lindex [array get env PORTSRC] 1]
	if {[file isfile ${PORTSRC}]} {
	    set portconf ${PORTSRC}
	    lappend conf_files ${portconf}
	}
    }

    # then look in ~/.portsrc
    if {![info exists portconf]} {
	if {[llength [array names env HOME]] > 0} {
	    set HOME [lindex [array get env HOME] 1]
	    if {[file isfile [file join ${HOME} .portsrc]]} {
		set portconf [file join ${HOME} .portsrc]
		lappend conf_files ${portconf}
	    }
	}
    }

    # finally /etc/ports/ports.conf, or whatever path was configured
    if {![info exists portconf]} {
	if {[file isfile $dports_conf_path/ports.conf]} {
	    set portconf $dports_conf_path/ports.conf
	    lappend conf_files $dports_conf_path/ports.conf
	}
    }
    if {[info exists conf_files]} {
	foreach file $conf_files {
	    set fd [open $file r]
	    while {[gets $fd line] >= 0} {
		foreach option $bootstrap_options {
		    if {[regexp "^$option\[ \t\]+(\[A-Za-z0-9_:\./-\]+$)" $line match val] == 1} {
			set darwinports::$option $val
			global darwinports::$option
		    }
		}
	    }
        }
    }

    if {![info exists sources_conf]} {
        return -code error "sources_conf must be set in $dports_conf_path/ports.conf or in your ~/.portsrc"
    }
    if {[catch {set fd [open $sources_conf r]} result]} {
        return -code error "$result"
    }
    while {[gets $fd line] >= 0} {
        set line [string trimright $line]
        if {![regexp {[\ \t]*#.*|^$} $line]} {
            lappend sources $line
	}
    }
    if {![info exists sources]} {
	if {[file isdirectory dports]} {
	    set sources "file://[pwd]/dports"
	} else {
	    return -code error "No sources defined in $sources_conf"
	}
    }

    if {![info exists portdbpath]} {
	return -code error "portdbpath must be set in $dports_conf_path/ports.conf or in your ~/.portsrc"
    }
    if {![file isdirectory $portdbpath]} {
	if {![file exists $portdbpath]} {
	    if {[catch {file mkdir $portdbpath} result]} {
		return -code error "portdbpath $portdbpath does not exist and could not be created: $result"
	    }
	}
    }
    if {![file isdirectory $portdbpath]} {
	return -code error "$portdbpath is not a directory. Please create the directory $portdbpath and try again"
    }

    set registry.path $portdbpath
    if {![file isdirectory ${registry.path}]} {
	if {![file exists ${registry.path}]} {
	    if {[catch {file mkdir ${registry.path}} result]} {
		return -code error "portdbpath ${registry.path} does not exist and could not be created: $result"
	    }
	}
    }
    if {![file isdirectory ${darwinports::registry.path}]} {
	return -code error "${darwinports::registry.path} is not a directory. Please create the directory $portdbpath and try again"
    }

	# Format for receipts, can currently be either "flat" or "sqlite"
	if {[info exists portdbformat]} {
		if { $portdbformat == "sqlite" } {
			return -code error "SQLite is not yet supported for registry storage."
		} 
		set registry.format receipt_${portdbformat}
	} else {
		set registry.format receipt_flat
	}

	# Installation type, whether to use port "images" or install "direct"
	if {[info exists portinstalltype]} {
		set registry.installtype $portinstalltype
	} else {
		set registry.installtype image
	}
    
    set portsharepath ${prefix}/share/darwinports
    if {![file isdirectory $portsharepath]} {
	return -code error "Data files directory '$portsharepath' must exist"
    }
    
    if {![info exists libpath]} {
	set libpath "${prefix}/share/darwinports/Tcl"
    }

    if {![info exists binpath]} {
	global env
	set env(PATH) "${prefix}/bin:${prefix}/sbin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin"
    } else {
	global env
	set env(PATH) "$binpath"
    }

    if {[info exists master_site_local] && ![info exists env(MASTER_SITE_LOCAL)]} {
	global env
	set env(MASTER_SITE_LOCAL) "$master_site_local"
    }

    if {[file isdirectory $libpath]} {
		lappend auto_path $libpath
		set darwinports::auto_path $auto_path

		# XXX: not sure if this the best place, but it needs to happen
		# early, and after auto_path has been set.  Or maybe Pextlib
		# should ship with darwinports1.0 API?
		package require Pextlib 1.0
		package require registry 1.0
    } else {
		return -code error "Library directory '$libpath' must exist"
    }
}

proc darwinports::worker_init {workername portpath options variations} {
    global darwinports::portinterp_options auto_path registry.installtype

	# Tell the sub interpreter about all the Tcl packages we already
	# know about so it won't glob for packages.
	foreach pkgName [package names] {
		foreach pkgVers [package versions $pkgName] {
			set pkgLoadScript [package ifneeded $pkgName $pkgVers]
			$workername eval "package ifneeded $pkgName $pkgVers {$pkgLoadScript}"
		}
	}

    # Create package require abstraction procedure
    $workername eval "proc PortSystem \{version\} \{ \n\
			package require port \$version \}"

    foreach proc {dportexec dportopen dportclose dportsearch} {
        $workername alias $proc $proc
    }

    # instantiate the UI call-back
    $workername alias ui_event darwinports::ui_event $workername

	# New Registry/Receipts stuff
	$workername alias registry_new registry::new_entry
	$workername alias registry_open registry::open_entry
	$workername alias registry_write registry::write_entry
	$workername alias registry_prop_store registry::property_store
	$workername alias registry_prop_retr registry::property_retrieve
	$workername alias registry_delete registry::delete_entry
	$workername alias registry_exists registry::entry_exists
	$workername alias registry_activate portimage::activate
	$workername alias registry_deactivate portimage::deactivate
	$workername alias registry_register_deps registry::register_dependencies
	$workername alias registry_fileinfo_for_index registry::fileinfo_for_index
	$workername alias registry_bulk_register_files registry::register_bulk_files
	$workername alias registry_installed registry::installed

    foreach opt $portinterp_options {
	if {![info exists $opt]} {
	    global darwinports::$opt
	}
        if {[info exists $opt]} {
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

    if { [info exists registry.installtype] } {
	    $workername eval set installtype ${registry.installtype}
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
    if {[catch {exec curl -L -s -S -o [file join $fetchdir $fetchfile] $url} result]} {
        return -code error "Port remote fetch failed: $result"
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

# XXX: this really needs to be rethought in light of the remote index
# I've added the destdir parameter.  This is the location a remotely
# fetched port will be downloaded to (currently only applies to
# dports:// sources).
proc darwinports::getportdir {url {destdir "."}} {
    if {[regexp {(?x)([^:]+)://(.+)} $url match protocol string] == 1} {
        switch -regexp -- ${protocol} {
            {^file$} { return $string}
        {dports} { return [darwinports::index::fetch_port $url $destdir] }
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

proc dportopen {porturl {options ""} {variations ""} {nocache ""}} {
    global darwinports::portinterp_options darwinports::portdbpath darwinports::portconf darwinports::open_dports auto_path

	# Look for an already-open DPort with the same URL.
	# XXX: should compare options and variations here too.
	# if found, return the existing reference and bump the refcount.
	if {$nocache != ""} {
		set dport {}
	} else {
		set dport [dlist_search $darwinports::open_dports porturl $porturl]
	}
	if {$dport != {}} {
		set refcnt [ditem_key $dport refcnt]
		incr refcnt
		ditem_key $dport refcnt $refcnt
		return $dport
	}

	array set options_array $options
	if {[info exists options_array(portdir)]} {
		set portdir $options_array(portdir)
	} else {
		set portdir ""
	}

	set portdir [darwinports::getportdir $porturl $portdir]
	ui_debug "Changing to port directory: $portdir"
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
    if {![file isfile Portfile]} {
        return -code error "Could not find Portfile in $portdir"
    }

    $workername eval source Portfile
	
    ditem_key $dport provides [$workername eval return \$portname]

    return $dport
}

# Traverse a directory with ports, calling a function on the path of ports
# (at the second depth).
# I.e. the structure of dir shall be:
# category/port/
# with a Portfile file in category/port/
#
# func:		function to call on every port directory (it is passed
#			category/port/ as its parameter)
# root:		the directory with all the categories directories.
proc dporttraverse {func {root .}} {
	# Save the current directory
	set pwd [pwd]
	
	# Join the root.
	set pathToRoot [file join $pwd $root]

	# Go to root because some callers expects us to be there.
	cd $pathToRoot

    foreach category [readdir $root] {
    	set pathToCategory [file join $root $category]
        if {[file isdirectory $pathToCategory]} {
        	# Iterate on port directories.
			foreach port [readdir $pathToCategory] {
				set pathToPort [file join $pathToCategory $port]
				if {[file isdirectory $pathToPort] &&
					[file exists [file join $pathToPort "Portfile"]]} {
					# Call the function.
					$func [file join $category $port]
					
					# Restore the current directory because some
					# functions changes it.
					cd $pathToRoot
				}
			}
        }
	}
	
	# Restore the current directory.
	cd $pwd
}

### _dportsearchpath is private; subject to change without notice

proc _dportsearchpath {depregex search_path} {
    set found 0
    foreach path $search_path {
	if {![file isdirectory $path]} {
	    continue
	}

	if {[catch {set filelist [readdir $path]} result]} {
		return -code error "$result ($path)"
		set filelist ""
	}

	foreach filename $filelist {
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
#   -- Since /usr/local is bad, using /lib:/usr/lib only.
# Environment variables DYLD_FRAMEWORK_PATH, DYLD_LIBRARY_PATH,
# DYLD_FALLBACK_FRAMEWORK_PATH, and DYLD_FALLBACK_LIBRARY_PATH take precedence

proc _libtest {dport depspec} {
    global env tcl_platform
	set depline [lindex [split $depspec :] 1]
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
	}
	lappend search_path /lib /usr/lib /usr/X11R6/lib ${prefix}/lib
	if {[info exists env(DYLD_FALLBACK_LIBRARY_PATH)]} {
	    lappend search_path $env(DYLD_LIBRARY_PATH)
	}

	set i [string first . $depline]
	set depname [string range $depline 0 [expr $i - 1]]
	set depversion [string range $depline $i end]
	regsub {\.} $depversion {\.} depversion
	if {$tcl_platform(os) == "Darwin"} {
		set depregex \^${depname}${depversion}\\.dylib\$
	} else {
		set depregex \^${depname}\\.so${depversion}\$
	}

	return [_dportsearchpath $depregex $search_path]
}

### _bintest is private; subject to change without notice

proc _bintest {dport depspec} {
    global env
	set depregex [lindex [split $depspec :] 1]
	set prefix [_dportkey $dport prefix] 
	
	set search_path [split $env(PATH) :]
	
	set depregex \^$depregex\$
	
	return [_dportsearchpath $depregex $search_path]
}

### _pathtest is private; subject to change without notice

proc _pathtest {dport depspec} {
    global env
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

### _dportinstalled is private; may change without notice

# Determine if a port is already *installed*, as in "in the registry".
proc _dportinstalled {dport} {
	# Check for the presense of the port in the registry
	set workername [ditem_key $dport workername]
	set res [$workername eval registry_exists \${portname} \${portversion}]
	if {$res != 0} {
		ui_debug "[ditem_key $dport provides] is installed"
		return 1
	} else {
		return 0
	}
}

### _dporispresent is private; may change without notice

# Determine if some depspec is satisfied or if the given port is installed.
# We actually start with the registry (faster?)
#
# dport		the port to test (to figure out if it's present)
# depspec	the dependency test specification (path, bin, lib, etc.)
proc _dportispresent {dport depspec} {
	# Check for the presense of the port in the registry
	set workername [ditem_key $dport workername]
	ui_debug "Searching for dependency: [ditem_key $dport provides]"
	if {[catch {set reslist [$workername eval registry_installed \${portname}]} res]} {
		set res 0
	} else {
		set res [llength $reslist]
	}
	if {$res != 0} {
		ui_debug "Found Dependency: receipt exists for [ditem_key $dport provides]"
		return 1
	} else {
		# The receipt test failed, use one of the depspec regex mechanisms
		ui_debug "Didn't find receipt, going to depspec regex for: [ditem_key $dport provides]"
		set type [lindex [split $depspec :] 0]
		switch $type {
			lib { return [_libtest $dport $depspec] }
			bin { return [_bintest $dport $depspec] }
			path { return [_pathtest $dport $depspec] }
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
    global darwinports::portinterp_options darwinports::registry.installtype

	set workername [ditem_key $dport workername]

	# XXX: move this into dportopen?
	if {[$workername eval eval_variants variations $target] != 0} {
		return 1
	}
	
	# Before we build the port, we must build its dependencies.
	# XXX: need a more general way of comparing against targets
	set dlist {}
	if {$target == "package"} {
		ui_warn "package target replaced by pkg target, please use the pkg target in the future."
		set target "pkg"
	}
	if {$target == "configure" || $target == "build"
		|| $target == "destroot" || $target == "install"
		|| $target == "pkg" || $target == "mpkg"
		|| $target == "rpmpackage" || $target == "dpkg" } {

		if {[dportdepends $dport 1 1] != 0} {
			return 1
		}
		
		# Select out the dependents along the critical path,
		# but exclude this dport, we might not be installing it.
		set dlist [dlist_append_dependents $darwinports::open_dports $dport {}]
		
		dlist_delete dlist $dport

		# install them
		# xxx: as with below, this is ugly.  and deps need to be fixed to
		# understand Port Images before this can get prettier
		if { [string equal ${darwinports::registry.installtype} "image"] } {
			set result [dlist_eval $dlist _dportinstalled [list _dportexec "activate"]]
		} else {
			set result [dlist_eval $dlist _dportinstalled [list _dportexec "install"]]
		}
		
		if {$result != {}} {
			set errstring "The following dependencies failed to build:"
			foreach ditem $result {
				append errstring " [ditem_key $ditem provides]"
			}
			ui_error $errstring
			return 1
		}
		
		# Close the dependencies, we're done installing them.
		foreach ditem $dlist {
			dportclose $ditem
		}
	}

	# If we're doing image installs, then we should activate after install
	# xxx: This isn't pretty
	if { [string equal ${darwinports::registry.installtype} "image"] && [string equal $target "install"] } {
		set target activate
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
        } elseif {[darwinports::getprotocol $source] == "dports"} {
			darwinports::index::sync $darwinports::portdbpath $source
        } else {
			set indexfile [darwinports::getindex $source]
			if {[catch {file mkdir [file dirname $indexfile]} result]} {
				return -code error $result
			}
			if {![file writable [file dirname $indexfile]]} {
				return -code error "You do not have permission to write to [file dirname $indexfile]"
			}
			exec curl -L -s -S -o $indexfile $source/PortIndex
		}
	}
}

proc dportsearch {regexp {case_sensitive "yes"}} {
    global darwinports::portdbpath darwinports::sources
    set matches [list]

    # XXX This should not happen, but does with the tk port when searching for tcl.
    if {![info exists sources]} { return $matches }
    foreach source $sources {
    	if {[darwinports::getprotocol $source] == "dports"} {
    		array set attrs [list name $regexp]
			set res [darwinports::index::search $darwinports::portdbpath $source [array get attrs]]
			eval lappend matches $res
		} else {
        	if {[catch {set fd [open [darwinports::getindex $source] r]} result]} {
        	    return -code error "Can't open index file for source $source. Have you synced your source indexes?"
			}
	        while {[gets $fd line] >= 0} {
	            set name [lindex $line 0]
				if {$case_sensitive == "yes"} {
					set rxres [regexp -- $regexp $name]
				} else {
					set rxres [regexp -nocase -- $regexp $name]
				}
	            if {$rxres == 1} {
	                gets $fd line
	                array set portinfo $line
	                if {[info exists portinfo(portarchive)]} {
	                    lappend line porturl ${source}/$portinfo(portarchive)
	                } elseif {[info exists portinfo(portdir)]} {
	                    lappend line porturl ${source}/$portinfo(portdir)
	                }
	                lappend matches $name
	                lappend matches $line
	            } else {
	                set len [lindex $line 1]
					catch {seek $fd $len current}
	            }
	        }
	        close $fd
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

# dportdepends builds the list of dports which the given port depends on.
# This list is added to $dport.
# - optionally includes the build dependencies in the list.
# - optionally recurses through the dependencies, looking for dependencies
#	of dependencies.

proc dportdepends {dport includeBuildDeps recurseDeps {accDeps {}}} {
	array set portinfo [dportinfo $dport]
	set depends {}
	if {[info exists portinfo(depends_run)]} { eval "lappend depends $portinfo(depends_run)" }
	if {[info exists portinfo(depends_lib)]} { eval "lappend depends $portinfo(depends_lib)" }
	if {$includeBuildDeps != "" && [info exists portinfo(depends_build)]} {
		eval "lappend depends $portinfo(depends_build)"
	}

	set subPorts {}
	
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

		# Figure out the subport.	
		set subport [dportopen $porturl $options $variations]

		# Is that dependency satisfied or this port installed?
		# If not, add it to the list. Otherwise, don't.
		if {![_dportispresent $subport $depspec]} {
			# Append the sub-port's provides to the port's requirements list.
			ditem_append_unique $dport requires "[ditem_key $subport provides]"
	
			if {$recurseDeps != ""} {
				# Skip the port if it's already in the accumulated list.
				if {[lsearch $accDeps $portname] == -1} {
					# Add it to the list
					lappend accDeps $portname
				
					# We'll recursively iterate on it.
					lappend subPorts $subport
				}
			}
		}
	}

	# Loop on the subports.
	if {$recurseDeps != ""} {
		foreach subport $subPorts {
			set res [dportdepends $subport $includeBuildDeps $recurseDeps $accDeps]
			if {$res != 0} {
				return $res
			}
		}
	}
	
	return 0
}
