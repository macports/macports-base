# plugin.tcl --
#
#	Generic plugin management.
#
# Copyright (c) 2005 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pluginmgr.tcl,v 1.8 2009/03/31 02:14:40 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Description

# Each instance of the plugin manager can be configured with data
# which specifies where to find plugins, and how to validate
# them. With that it can then be configured to load and provide access
# to a specific plugin, doing all required checks and
# initialization. Users for specific plugin types simply have to
# encapsulate the generic class, providing all the specifics, leaving
# their users only the task of naming the requested actual plugin.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4
package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type ::pluginmgr {

    # ### ### ### ######### ######### #########
    ## Public API - Options

    # - Pattern to match package name. Exactly one '*'. No default.
    # - List of commands the plugin has to provide. Empty list default.
    # - Callback for additional checking after the API presence has
    #   been verified. Empty list default.
    # - Dictionary of commands to put into the plugin interpreter.
    #   Key: cmds for plugin, value is cmds to invoke for them.
    # - Interpreter to use for the -cmds (invoked commands). Default
    #   is current interp.
    # - Callback for additional setup actions on the plugin
    #   interpreter after its creation, but before plugin is loaded into
    #   it. Empty list default.

    option -pattern {}
    option -api     {}
    option -check   {}
    option -cmds    {}
    option -cmdip   {}
    option -setup   {}

    # ### ### ### ######### ######### #########
    ## Public API - Methods

    method do {args} {
	if {$plugin eq ""} {
	    return -code error "No plugin defined"
	}
	return [$sip eval $args]
    }

    method interpreter {} {
	return $sip
    }

    method plugin {} {
	return $plugin
    }

    method load {name} {
	if {$name eq $plugin} return

	if {$options(-pattern) eq ""} {
	    return -code error "Translation pattern is not configured"
	}

	set save $sip

	$self SetupIp
	if {![$self LoadPlugin $name]} {
	    set sip $save
	    return -code error "Unable to locate or load plugin \"$name\" ($myloaderror)"
	}

	if {![$self CheckAPI missing]} {
	    set sip $save
	    return -code error \
		    "Cannot use plugin \"$name\", API incomplete: \"$missing\" missing"
	}

	set savedname $plugin
	set plugin    $name
	if {![$self CheckExternal]} {
	    set sip    $save
	    set plugin $savedname
	    return -code error \
		    "Cannot use plugin \"$name\", API bad"
	}
	$self SetupExternalCmds

	if {$save ne ""} {interp delete $save}
	return
    }

    method unload {} {
	if {$sip eq ""} return
	interp delete $sip
	set sip    ""
	set plugin ""
	return
    }

    method list {} {
	if {$options(-pattern) eq ""} {
	    return -code error "Translation pattern is not configured"
	}

	set save $sip
	$self SetupIp

	set result {}
	set pattern [string map [list \
		+  \\+  ?  \\?    \
		\[ \\\[ \] \\\]   \
		(  \\(  )  \\)    \
		. \\. \*  {(.*)} \
		] $options(-pattern)]

	# @mdgen NODEP: bogus-package
	$sip eval {catch {package require bogus-package}}
	foreach p [$sip eval {package names}] {
	    if {![regexp $pattern $p -> plugin]} continue
	    lappend result $plugin
	}

	interp delete $sip
	set sip $save
	return $result
    }

    method path {path} {
	set path [file join [pwd] $path]
	if {[lsearch -exact $paths $path] < 0} {
	    lappend paths $path
	}
	return
    }

    method paths {} {
	return $paths
    }

    method clone {} {
	set o [$type create %AUTO% \
		-pattern $options(-pattern) \
		-api     $options(-api)    \
		-check   $options(-check) \
		-cmds    $options(-cmds) \
		-cmdip   $options(-cmdip) \
		-setup   $options(-setup)]

	$o __clone__ $paths $sip $plugin

	# Clone has become owner of the interp.
	set sip    {}
	set plugin {}

	return $o
    }

    method __clone__ {_paths _sip _plugin} {
	set paths  $_paths
	set sip    $_sip
	set plugin $_plugin
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal - Configuration and state

    variable paths  {} ; # List of paths to provide the sip with.
    variable sip    {} ; # Safe interp used for plugin execution.
    variable plugin {} ; # Name of currently loaded plugin.
    variable myloaderror {} ; # Last error reported by the Safe base

    # ### ### ### ######### ######### #########
    ## Internal - Object construction and descruction.

    constructor {args} {
	$self configurelist $args
	return
    }

    destructor {
	if {$sip ne ""} {interp delete $sip}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal - Option management

    onconfigure -pattern {newvalue} {
	set current $options(-pattern)
	if {$newvalue eq $current} return

	set n [regexp -all "\\*" $newvalue]
	if {$n < 1} {
	    return -code error "Invalid pattern, * missing"
	} elseif {$n > 1} {
	    return -code error "Invalid pattern, too many *'s"
	}

	set options(-pattern) $newvalue
	return
    }

    onconfigure -api {newvalue} {
	set current $options(-api)
	if {$newvalue eq $current} return
	set options(-api) $newvalue
	return
    }

    onconfigure -cmds {newvalue} {
	set current $options(-cmds)
	if {$newvalue eq $current} return
	set options(-cmds) $newvalue
	return
    }

    onconfigure -cmdip {newvalue} {
	set current $options(-cmdip)
	if {$newvalue eq $current} return
	set options(-cmdip) $newvalue
	return
    }


    # ### ### ### ######### ######### #########
    ## Internal - Helper commands

    method SetupIp {} {
	set sip [::safe::interpCreate]
	foreach p $paths {
	    ::safe::interpAddToAccessPath $sip $p
	}

	if {![llength $options(-setup)]} return
	uplevel \#0 [linsert $options(-setup) end $self $sip]
	return
    }

    method LoadPlugin {name} {
	if {[file exists $name]} {
	    # Plugin files are loaded directly.

	    $sip invokehidden source $name
	    return 1
	}

	# Otherwise the name is transformed into a package name
	# and loaded thorugh the package management.

	set pluginpackage [string map \
		[list * $name] $options(-pattern)]

	::safe::setLogCmd [mymethod PluginError]
	if {[catch {
	    $sip eval [list package require $pluginpackage]
	} res]} {
	    ::safe::setLogCmd {}
	    return 0
	}
	::safe::setLogCmd {}
	return 1
    }

    method CheckAPI {mv} {
	upvar 1 $mv missing
	if {![llength $options(-api)]} {return 1}

	# Check the plugin for useability.

	foreach p $options(-api) {
	    if {[llength [$sip eval [list info commands $p]]] == 1} continue
	    interp delete $sip
	    set missing $p
	    return 0
	}
	return 1
    }

    method CheckExternal {} {
	if {![llength $options(-check)]} {return 1}
	return [uplevel \#0 [linsert $options(-check) end $self]]
    }


    method SetupExternalCmds {} {
	if {![llength $options(-cmds)]} return

	set cip $options(-cmdip)
	foreach {pcmd ecmd} $options(-cmds) {
	    eval [linsert $ecmd 0 interp alias $sip $pcmd $cip]
	    #interp alias $sip $pcmd $cip {*}$ecmd
	}
	return
    }

    method PluginError {message} {
	if {[string match {*script error*} $message]} return
	set myloaderror $message
	return
    }

    # ### ### ### ######### ######### #########

    proc paths {pmgr args} {
	if {[llength $args] == 0} {
	    return -code error "wrong#args: Expect \"[info level 0] object name...\""
	}
	foreach name $args {
	    AddPaths $pmgr $name
	}
	return
    }

    proc AddPaths {pmgr name} {
	global env tcl_platform

	if {$tcl_platform(platform) eq "windows"} {
	    set sep \;
	} else {
	    set sep :
	}

	#puts "$pmgr += ($name) $sep"

	regsub -all {::+} [string trim $name :] \000 name
	set name [split $name \000]

	# Environment variables

	set prefix {}
	foreach part $name {
	    lappend prefix $part
	    set ev [string toupper [join $prefix _]]_PLUGINS

	    #puts "+? env($ev)"

	    if {[info exists env($ev)]} {
		foreach path [split $env($ev) $sep] {
		    $pmgr path $path
		}
	    }
	}

	# Windows registry

	if {
	    ($tcl_platform(platform) eq "windows") &&
	    ![catch {package require registry}]
	} {
	    foreach root {
		HKEY_LOCAL_MACHINE
		HKEY_CURRENT_USER
	    } {
		set prefix {}
		foreach part $name {
		    lappend prefix $part
		    set rk $root\\SOFTWARE\\[join $prefix \\]PLUGINS

		    #puts "+? registry($rk)"

		    if {![catch {set data [registry get $rk {}]}]} {
			foreach path [split $data $sep] {
			    $pmgr path $path
			}
		    }
		}
	    }
	}

	# Home directory dot path

	set prefix {}
	foreach part $name {
	    lappend prefix $part
	    set pd [file join ~ .[join $prefix /] plugin]

	    #puts "+? path($pd)"

	    if {[file exists $pd]} {
		$pmgr path $pd
	    }

	    # Cover for the goof in the example found in the docs.
	    # Note that supporting the directory name 'plugins' is
	    # also more consistent with the environment variables
	    # above, where we also use plugins, plural.

	    set pd [file join ~ .[join $prefix /] plugins]

	    #puts "+? path($pd)"

	    if {[file exists $pd]} {
		$pmgr path $pd
	    }
	}
	return
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide pluginmgr 0.3
