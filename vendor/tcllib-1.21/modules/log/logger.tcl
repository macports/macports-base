# logger.tcl --
#
#   Tcl implementation of a general logging facility.
#
# Copyright (c) 2003      by David N. Welton <davidw@dedasys.com>
# Copyright (c) 2004-2011 by Michael Schlenker <mic42@users.sourceforge.net>
# Copyright (c) 2006,2015 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file license.terms.

# The logger package provides an 'object oriented' log facility that
# lets you have trees of services, that inherit from one another.
# This is accomplished through the use of Tcl namespaces.


package require Tcl 8.2
package provide logger 0.9.4

namespace eval ::logger {
    namespace eval tree {}
    namespace export init enable disable services servicecmd import

    # The active services.
    variable services {}

    # The log 'levels'.
    variable levels [list debug info notice warn error critical alert emergency]

    # The default global log level used for new logging services
    variable enabled "debug"

    # Tcl return codes (in numeric order)
    variable RETURN_CODES   [list "ok" "error" "return" "break" "continue"]
}

# Try to load msgcat and fall back to format if it fails
if {[catch {package require msgcat}]} {
  interp alias {} ::logger::mc {} ::format
} else {
  namespace eval ::logger {
    namespace import ::msgcat::mc
  }
}

# ::logger::_nsExists --
#
#   Workaround for missing namespace exists in Tcl 8.2 and 8.3.
#

if {[package vcompare [package provide Tcl] 8.4] < 0} {
    proc ::logger::_nsExists {ns} {
        expr {![catch {namespace parent $ns}]}
    }
} else {
    proc ::logger::_nsExists {ns} {
        namespace exists $ns
    }
}

# ::logger::_cmdPrefixExists --
#
# Utility function to check if a given callback prefix exists,
# this should catch all oddities in prefix names, including spaces,
# glob patterns, non normalized namespaces etc.
#
# Arguments:
#   prefix - The command prefix to check
#
# Results:
#   1 or 0 for yes or no
#
proc ::logger::_cmdPrefixExists {prefix} {
    set cmd [lindex $prefix 0]
    set full [namespace eval :: namespace which [list $cmd]]
    if {[string equal $full ""]} {return 0} else {return 1}
    # normalize namespaces
    set ns [namespace qualifiers $cmd]
    set cmd ${ns}::[namespace tail $cmd]
    set matches [::info commands ${ns}::*]
    if {[lsearch -exact $matches $cmd] != -1} {return 1}
    return 0
}

# ::logger::walk --
#
#   Walk namespaces, starting in 'start', and evaluate 'code' in
#   them.
#
# Arguments:
#   start - namespace to start in.
#   code - code to execute in namespaces walked.
#
# Side Effects:
#   Side effects of code executed.
#
# Results:
#   None.

proc ::logger::walk { start code } {
    set children [namespace children $start]
    foreach c $children {
    logger::walk $c $code
    namespace eval $c $code
    }
}

proc ::logger::init {service} {
    variable levels
    variable services
    variable enabled

    if {[string length [string trim $service {:}]] == 0} {
        return -code error \
               -errorcode [list LOGGER EMPTY_SERVICENAME] \
               [::logger::mc "Service name invalid. May not consist only of : or be empty"]
    }
    # We create a 'tree' namespace to house all the services, so
    # they are in a 'safe' namespace sandbox, and won't overwrite
    # any commands.
    namespace eval tree::${service} {
        variable service
        variable levels
        variable oldname
        variable enabled
    }

    lappend services $service

    set [namespace current]::tree::${service}::service $service
    set [namespace current]::tree::${service}::levels $levels
    set [namespace current]::tree::${service}::oldname $service
    set [namespace current]::tree::${service}::enabled $enabled

    namespace eval tree::${service} {
	# Callback to use when the service in question is shut down.
	variable delcallback [namespace current]::no-op

	# Callback when the loglevel is changed
	variable levelchangecallback [namespace current]::no-op

	# State variable to decide when to call levelcallback
	variable inSetLevel 0

	# The currently configured levelcommands
	variable lvlcmds
	array set lvlcmds {}

	# List of procedures registered via the trace command
	variable traceList ""

	# Flag indicating whether or not tracing is currently enabled
	variable tracingEnabled 0

	# We use this to disable a service completely.  In Tcl 8.4
	# or greater, by using this, disabled log calls are a
	# no-op!

	proc no-op args {}

	proc stdoutcmd {level text} {
	    variable service
	    puts "\[[clock format [clock seconds]]\] \[$service\] \[$level\] \'$text\'"
	}

	proc stderrcmd {level text} {
	    variable service
	    puts stderr "\[[clock format [clock seconds]]\] \[$service\] \[$level\] \'$text\'"
	}


	# setlevel --
	#
	#   This command differs from enable and disable in that
	#   it disables all the levels below that selected, and
	#   then enables all levels above it, which enable/disable
	#   do not do.
	#
	# Arguments:
	#   lv - the level, as defined in $levels.
	#
	# Side Effects:
	#   Runs disable for the level, and then enable, in order
	#   to ensure that all levels are set correctly.
	#
	# Results:
	#   None.


	proc setlevel {lv} {
	    variable inSetLevel 1
	    set oldlvl [currentloglevel]

	    # do not allow enable and disable to do recursion
	    if {[catch {
		disable $lv 0
		set newlvl [enable $lv 0]
	    } msg] == 1} {
		return -code error -errorcode $::errorCode $msg
	    }
	    # do the recursion here
	    logger::walk [namespace current] [list setlevel $lv]

	    set inSetLevel 0
	    lvlchangewrapper $oldlvl $newlvl
	    return
	}

	# enable --
	#
	#   Enable a particular 'level', and above, for the
	#   service, and its 'children'.
	#
	# Arguments:
	#   lv - the level, as defined in $levels.
	#
	# Side Effects:
	#   Enables logging for the particular level, and all
	#   above it (those more important).  It also walks
	#   through all services that are 'children' and enables
	#   them at the same level or above.
	#
	# Results:
	#   None.

	proc enable {lv {recursion 1}} {
	    variable levels
	    set lvnum [lsearch -exact $levels $lv]
	    if { $lvnum == -1 } {
		return -code error \
		    -errorcode [list LOGGER INVALID_LEVEL] \
		    [::logger::mc "Invalid level '%s' - levels are %s" $lv $levels]
	    }

	    variable enabled
	    set newlevel $enabled
	    set elnum [lsearch -exact $levels $enabled]
	    if {($elnum == -1) || ($elnum > $lvnum)} {
		set newlevel $lv
	    }

	    variable service
	    while { $lvnum <  [llength $levels] } {
		interp alias {} [namespace current]::[lindex $levels $lvnum] \
		    {} [namespace current]::[lindex $levels $lvnum]cmd
		incr lvnum
	    }

	    if {$recursion} {
		logger::walk [namespace current] [list enable $lv]
	    }
	    lvlchangewrapper $enabled $newlevel
	    set enabled $newlevel
	}

	# disable --
	#
	#   Disable a particular 'level', and below, for the
	#   service, and its 'children'.
	#
	# Arguments:
	#   lv - the level, as defined in $levels.
	#
	# Side Effects:
	#   Disables logging for the particular level, and all
	#   below it (those less important).  It also walks
	#   through all services that are 'children' and disables
	#   them at the same level or below.
	#
	# Results:
	#   None.

	proc disable {lv {recursion 1}} {
	    variable levels
	    set lvnum [lsearch -exact $levels $lv]
	    if { $lvnum == -1 } {
		return -code error \
		    -errorcode [list LOGGER INVALID_LEVEL] \
		    [::logger::mc "Invalid level '%s' - levels are %s" $lv $levels]
	    }

	    variable enabled
	    set newlevel $enabled
	    set elnum [lsearch -exact $levels $enabled]
	    if {($elnum > -1) && ($elnum <= $lvnum)} {
		if {$lvnum+1 >= [llength $levels]} {
		    set newlevel "none"
		} else {
		    set newlevel [lindex $levels [expr {$lvnum+1}]]
		}
	    }

	    while { $lvnum >= 0 } {

		interp alias {} [namespace current]::[lindex $levels $lvnum] {} \
		    [namespace current]::no-op
		incr lvnum -1
	    }
	    if {$recursion} {
		logger::walk [namespace current] [list disable $lv]
	    }
	    lvlchangewrapper $enabled $newlevel
	    set enabled $newlevel
	}

	# currentloglevel --
	#
	#   Get the currently enabled log level for this service.
	#
	# Arguments:
	#   none
	#
	# Side Effects:
	#   none
	#
	# Results:
	#   current log level
	#

	proc currentloglevel {} {
	    variable enabled
	    return $enabled
	}

	# lvlchangeproc --
	#
	#   Set or introspect a callback for when the logger instance
	#   changes its loglevel.
	#
	# Arguments:
	#   cmd - the Tcl command to call, it is called with two parameters, old and new log level.
	#   or none for introspection
	#
	# Side Effects:
	#   None.
	#
	# Results:
	#   If no arguments are given return the current callback cmd.

	proc lvlchangeproc {args} {
	    variable levelchangecallback

	    switch -exact -- [llength [::info level 0]] {
                1   {return $levelchangecallback}
                2   {
		    if {[::logger::_cmdPrefixExists [lindex $args 0]]} {
                        set levelchangecallback [lindex $args 0]
		    } else {
                        return -code error \
			    -errorcode [list LOGGER INVALID_CMD] \
			    [::logger::mc "Invalid cmd '%s' - does not exist" [lindex $args 0]]
		    }
		}
                default {
                    return -code error \
			-errorcode [list LOGGER WRONG_NUM_ARGS] \
			[::logger::mc "Wrong # of arguments. Usage: \${log}::lvlchangeproc ?cmd?"]
                }
	    }
	}

	proc lvlchangewrapper {old new} {
	    variable inSetLevel

	    # we are called after disable and enable are finished
	    if {$inSetLevel} {return}

	    # no action if level does not change
	    if {[string equal $old $new]} {return}

	    variable levelchangecallback
	    # no action if levelchangecallback isn't a valid command
	    if {[::logger::_cmdPrefixExists $levelchangecallback]} {
		catch {
		    uplevel \#0 [linsert $levelchangecallback end $old $new]
		}
	    }
	}

	# logproc --
	#
	#   Command used to create a procedure that is executed to
	#   perform the logging.  This could write to disk, out to
	#   the network, or something else.
	#   If two arguments are given, use an existing command.
	#   If three arguments are given, create a proc.
	#
	# Arguments:
	#   lv - the level to log, which must be one of $levels.
	#   args - either zero, one or two arguments.
	#          if zero this returns the current command registered
	#          if one, this is a cmd name that is called for this level
	#          if two, these are an argument and proc body
	#
	# Side Effects:
	#   Creates a logging command to take care of the details
	#   of logging an event.
	#
	# Results:
	#   If called with zero length args, returns the name of the currently
	#   configured logging procedure.
	#
	#

	proc logproc {lv args} {
	    variable levels
	    variable lvlcmds

	    set lvnum [lsearch -exact $levels $lv]
	    if { ($lvnum == -1) && ($lv != "trace") } {
		return -code error \
		    -errorcode [list LOGGER INVALID_LEVEL] \
		    [::logger::mc "Invalid level '%s' - levels are %s" $lv $levels]
	    }
	    switch -exact -- [llength $args] {
		0  {
		    return $lvlcmds($lv)
		}
		1  {
		    set cmd [lindex $args 0]
		    if {[string equal "[namespace current]::${lv}cmd" $cmd]} {return}
		    if {[llength [::info commands $cmd]]} {
			proc ${lv}cmd args [format {
			    uplevel 1 [list %s [expr {[llength $args]==1 ? [lindex $args end] : $args}]]
			} $cmd]
		    } else {
			return -code error \
			    -errorcode [list LOGGER INVALID_CMD] \
			    [::logger::mc "Invalid cmd '%s' - does not exist" $cmd]
		    }
		    set lvlcmds($lv) $cmd
		}
		2  {
		    foreach {arg body} $args {break}
		    proc ${lv}cmd args [format {\
						    _setservicename args
			set val [%s [expr {[llength $args]==1 ? [lindex $args end] : $args}]]
			_restoreservice
			set val} ${lv}customcmd]
		    proc ${lv}customcmd $arg $body
		    set lvlcmds($lv) [namespace current]::${lv}customcmd
		}
		default {
		    return -code error \
			-errorcode [list LOGGER WRONG_USAGE] \
			[::logger::mc \
			     "Usage: \${log}::logproc level ?cmd?\nor \${log}::logproc level argname body" ]
		}
	    }
	}


	# delproc --
	#
	#   Set or introspect a callback for when the logger instance
	#   is deleted.
	#
	# Arguments:
	#   cmd - the Tcl command to call.
	#   or none for introspection
	#
	# Side Effects:
	#   None.
	#
	# Results:
	#   If no arguments are given return the current callback cmd.

	proc delproc {args} {
	    variable delcallback

	    switch -exact -- [llength [::info level 0]] {
                1   {return $delcallback}
                2   { if {[::logger::_cmdPrefixExists [lindex $args 0]]} {
		    set delcallback [lindex $args 0]
		} else {
		    return -code error \
			-errorcode [list LOGGER INVALID_CMD] \
			[::logger::mc "Invalid cmd '%s' - does not exist" [lindex $args 0]]
		}
		}
                default {
                    return -code error \
			-errorcode [list LOGGER WRONG_NUM_ARGS] \
			[::logger::mc "Wrong # of arguments. Usage: \${log}::delproc ?cmd?"]
                }
	    }
	}


	# delete --
	#
	#   Delete the namespace and its children.

	proc delete {} {
	    variable delcallback
	    variable service

	    logger::walk [namespace current] delete
	    if {[::logger::_cmdPrefixExists $delcallback]} {
		uplevel \#0 [lrange $delcallback 0 end]
	    }
	    # clean up the global services list
	    set idx [lsearch -exact [logger::services] $service]
	    if {$idx !=-1} {
		set ::logger::services [lreplace [logger::services] $idx $idx]
	    }

	    namespace delete [namespace current]

	}

	# services --
	#
	#   Return all child services

	proc services {} {
	    variable service

	    set children [list]
	    foreach srv [logger::services] {
		if {[string match "${service}::*" $srv]} {
		    lappend children $srv
		}
	    }
	    return $children
	}

	# servicename --
	#
	#   Return the name of the service

	proc servicename {} {
	    variable service
	    return $service
	}

	proc _setservicename {argname} {
	    variable service
	    variable oldname
	    upvar 1 $argname arg
	    if {[llength $arg] <= 1} {
		return
	    }

	    set count -1
	    set newname ""
	    while {[string equal [lindex $arg [expr {$count+1}]] "-_logger::service"]} {
		incr count 2
		set newname [lindex $arg $count]
	    }
	    if {[string equal $newname ""]} {
		return
	    }
	    set oldname $service
	    set service $newname
	    # Pop off "-_logger::service <service>" from argument list
	    set arg [lreplace $arg 0 $count]
	}

	proc _restoreservice {} {
	    variable service
	    variable oldname
	    set service $oldname
	    return
	}

	proc trace { action args } {
	    variable service

	    # Allow other boolean values (true, false, yes, no, 0, 1) to be used
	    # as synonymns for "on" and "off".

	    if {[string is boolean $action]} {
		set xaction [expr {($action && 1) ? "on" : "off"}]
	    } else {
		set xaction $action
	    }

	    # Check for required arguments for actions/subcommands and dispatch
	    # to the appropriate procedure.

	    switch -- $xaction {
		"status" {
		    return [uplevel 1 [list logger::_trace_status $service $args]]
		}
		"on" {
		    if {[llength $args]} {
			return -code error \
			    -errorcode [list LOGGER WRONG_NUM_ARGS] \
                            [::logger::mc "wrong # args: should be \"trace on\""]
		    }
		    return [logger::_trace_on $service]
		}
		"off" {
		    if {[llength $args]} {
			return -code error \
			    -errorcode [list LOGGER WRONG_NUM_ARGS] \
                            [::logger::mc "wrong # args: should be \"trace off\""]
		    }
		    return [logger::_trace_off $service]
		}
		"add" {
		    if {![llength $args]} {
			return -code error \
			    -errorcode [list LOGGER WRONG_NUM_ARGS] \
			    [::logger::mc "wrong # args: should be \"trace add ?-ns? <proc> ...\""]
		    }
		    return [uplevel 1 [list ::logger::_trace_add $service $args]]
		}
		"remove" {
		    if {![llength $args]} {
			return -code error \
			    -errorcode [list LOGGER WRONG_NUM_ARGS] \
                            [::logger::mc "wrong # args: should be \"trace remove ?-ns? <proc> ...\""]
		    }
		    return [uplevel 1 [list ::logger::_trace_remove $service $args]]
		}

		default {
		    return -code error \
			-errorcode [list LOGGER INVALID_ARG] \
			[::logger::mc "Invalid action \"%s\": must be status, add, remove,\
                    on, or off" $action]
		}
	    }
	}

	# Walk the parent service namespaces to see first, if they
	# exist, and if any are enabled, and then, as a
	# consequence, enable this one
	# too.

	enable $enabled
	variable parent [namespace parent]
	while {[string compare $parent "::logger::tree"]} {
	    # If the 'enabled' variable doesn't exist, create the
	    # whole thing.
	    if { ! [::info exists ${parent}::enabled] } {
		logger::init [string range $parent 16 end]
	    }
	    set enabled [set ${parent}::enabled]
	    enable $enabled
	    set parent [namespace parent $parent]
	}
    }

    # Now create the commands for different levels.

    namespace eval tree::${service} {
	set parent [namespace parent]

	# We 'inherit' the commands from the parents.  This
	# means that, if you want to share the same methods with
	# children, they should be instantiated after the parent's
	# methods have been defined.

	variable lvl ; # prevent creative writing to the global scope
	if {[string compare $parent "::logger::tree"]} {
	    foreach lvl [::logger::levels] {
		# OPTIMIZE: do not allow multiple aliases in the hierarchy
		#           they can always be replaced by more efficient
		#           direct aliases to the target procs.
		interp alias {} [namespace current]::${lvl}cmd \
		    {} ${parent}::${lvl}cmd -_logger::service $service
	    }
	    # inherit the starting loglevel of the parent service
	    setlevel [${parent}::currentloglevel]
	} else {
	    foreach lvl [concat [::logger::levels] "trace"] {
		proc ${lvl}cmd args [format {\
						 _setservicename args
		    set val [stdoutcmd %s [expr {[llength $args]==1 ? [lindex $args end] : $args}]]
		    _restoreservice
		    set val } $lvl]

		set lvlcmds($lvl) [namespace current]::${lvl}cmd
	    }
	    setlevel $::logger::enabled
	}
	unset lvl ; # drop the temp iteration variable
    }

    return ::logger::tree::${service}
}

# ::logger::services --
#
#   Returns a list of all active services.
#
# Arguments:
#   None.
#
# Side Effects:
#   None.
#
# Results:
#   List of active services.

proc ::logger::services {} {
    variable services
    return $services
}

# ::logger::enable --
#
#   Global enable for a certain level.  NOTE - this implementation
#   isn't terribly effective at the moment, because it might hit
#   children before their parents, who will then walk down the
#   tree attempting to disable the children again.
#
# Arguments:
#   lv - level above which to enable logging.
#
# Side Effects:
#   Enables logging in a given level, and all higher levels.
#
# Results:
#   None.

proc ::logger::enable {lv} {
    variable services
    if {[catch {
        foreach sv $services {
        ::logger::tree::${sv}::enable $lv
        }
    } msg] == 1} {
        return -code error -errorcode $::errorCode $msg
    }
}

proc ::logger::disable {lv} {
    variable services
    if {[catch {
        foreach sv $services {
        ::logger::tree::${sv}::disable $lv
        }
    } msg] == 1} {
        return -code error -errorcode $::errorCode $msg
    }
}

proc ::logger::setlevel {lv} {
    variable services
    variable enabled
    variable levels
    if {[lsearch -exact $levels $lv] == -1} {
        return -code error \
               -errorcode [list LOGGER INVALID_LEVEL] \
               [::logger::mc "Invalid level '%s' - levels are %s" $lv $levels]
    }
    set enabled $lv
    if {[catch {
        foreach sv $services {
        ::logger::tree::${sv}::setlevel $lv
        }
    } msg] == 1} {
        return -code error -errorcode $::errorCode $msg
    }
}

# ::logger::levels --
#
#   Introspect the available log levels.  Provided so a caller does
#   not need to know implementation details or code the list
#   himself.
#
# Arguments:
#   None.
#
# Side Effects:
#   None.
#
# Results:
#   levels - The list of valid log levels accepted by enable and disable

proc ::logger::levels {} {
    variable levels
    return $levels
}

# ::logger::servicecmd --
#
#   Get the command token for a given service name.
#
# Arguments:
#   service - name of the service.
#
# Side Effects:
#   none
#
# Results:
#   log - namespace token for this service

proc ::logger::servicecmd {service} {
    variable services
    if {[lsearch -exact $services $service] == -1} {
        return -code error \
               -errorcode [list LOGGER NO_SUCH_SERVICE] \
               [::logger::mc "Service \"%s\" does not exist." $service]
    }
    return "::logger::tree::${service}"
}

# ::logger::import --
#
#   Import the logging commands.
#
# Arguments:
#   service - name of the service.
#
# Side Effects:
#   creates aliases in the target namespace
#
# Results:
#   none

proc ::logger::import {args} {
    variable services

    if {[llength $args] == 0 || [llength $args] > 7} {
    return -code error \
           -errorcode [list LOGGER WRONG_NUM_ARGS] \
           [::logger::mc \
                       "Wrong # of arguments: \"logger::import ?-all?\
                        ?-force?\
                        ?-prefix prefix? ?-namespace namespace? service\""]
    }

    # process options
    #
    set import_all 0
    set force 0
    set prefix ""
    set ns [uplevel 1 namespace current]
    while {[llength $args] > 1} {
        set opt [lindex $args 0]
        set args [lrange $args 1 end]
        switch  -exact -- $opt {
            -all    { set import_all 1}
            -prefix { set prefix [lindex $args 0]
                      set args [lrange $args 1 end]
                    }
            -namespace {
                      set ns [lindex $args 0]
                      set args [lrange $args 1 end]
            }
            -force {
                     set force 1
            }
            default {
                return -code error \
                       -errorcode [list LOGGER UNKNOWN_ARG] \
                       [::logger::mc \
                       "Unknown argument: \"%s\" :\nUsage:\
                      \"logger::import ?-all? ?-force?\
                        ?-prefix prefix? ?-namespace namespace? service\"" $opt]
            }
        }
    }

    #
    # build the list of commands to import
    #

    set cmds [logger::levels]
    lappend cmds "trace"
    if {$import_all} {
        lappend cmds setlevel enable disable logproc delproc services
        lappend cmds servicename currentloglevel delete
    }

    #
    # check the service argument
    #

    set service [lindex $args 0]
    if {[lsearch -exact $services $service] == -1} {
            return -code error \
                   -errorcode [list LOGGER NO_SUCH_SERVICE] \
                   [::logger::mc "Service \"%s\" does not exist." $service]
    }

    #
    # setup the namespace for the import
    #

    set sourcens [logger::servicecmd $service]
    set localns  [uplevel 1 namespace current]

    if {[string match ::* $ns]} {
        set importns $ns
    } else {
        set importns ${localns}::$ns
    }

    # fake namespace exists for Tcl 8.2 - 8.3
    if {![_nsExists $importns]} {
        namespace eval $importns {}
    }


    #
    # prepare the import
    #

    set imports ""
    foreach cmd $cmds {
        set cmdname ${importns}::${prefix}$cmd
        set collision [llength [info commands $cmdname]]
        if {$collision && !$force} {
            return -code error \
                   -errorcode [list LOGGER IMPORT_NAME_EXISTS] \
                   [::logger::mc "can't import command \"%s\": already exists" $cmdname]
        }
        lappend imports ${importns}::${prefix}$cmd ${sourcens}::${cmd}
    }

    #
    # and execute the aliasing after checking all is well
    #

    foreach {target source} $imports {
        proc $target {args} "uplevel 1 \[linsert \$args 0 $source \]"
    }
}

# ::logger::initNamespace --
#
#   Creates a logger for the specified namespace and makes the log
#   commands available to said namespace as well. Allows the initial
#   setting of a default log level.
#
# Arguments:
#   ns    - Namespace to initialize, is also the service name, modulo a ::-prefix
#   level - Initial log level, optional, defaults to 'warn'.
#
# Side Effects:
#   creates aliases in the target namespace
#
# Results:
#   none

proc ::logger::initNamespace {ns {level {}}} {
    set service [string trimleft $ns :]
    if {$level == ""} {
	# No user-specified level. Figure something out.
	# - If the parent service exists then the 'logger::init'
	#   below will automatically inherit its level. Good enough.
	# - Without a parent service go and use a default level of 'warn'.
	set parent    [string trimleft [namespace qualifiers $service] :]
	set hasparent [expr {($parent != {}) && [_nsExists ::logger::tree::${parent}]}]
	if {!$hasparent} {
	    set level warn
	}
    }

    namespace eval $ns [list ::logger::init $service]
    namespace eval $ns [list ::logger::import -force -all -namespace log $service]
    if {$level != ""} {
	namespace eval $ns [list log::setlevel $level]
    }
    return
}

# This procedure handles the "logger::trace status" command.  Given no
# arguments, returns a list of all procedures that have been registered
# via "logger::trace add".  Given one or more procedure names, it will
# return 1 if all were registered, or 0 if any were not.

proc ::logger::_trace_status { service procList } {
    upvar #0 ::logger::tree::${service}::traceList traceList

    # If no procedure names were given, just return the registered list

    if {![llength $procList]} {
        return $traceList
    }

    # Get caller's namespace for qualifying unqualified procedure names

    set caller_ns [uplevel 1 namespace current]
    set caller_ns [string trimright $caller_ns ":"]

    # Search for any specified proc names that are *not* registered

    foreach procName $procList {
        # Make sure the procedure namespace is qualified

        if {![string match "::*" $procName]} {
            set procName ${caller_ns}::$procName
        }

        # Check if the procedure has been registered for tracing

        if {[lsearch -exact $traceList $procName] == -1} {
	    return 0
        }
    }

    return 1
}

# This procedure handles the "logger::trace on" command.  If tracing
# is turned off, it will enable Tcl trace handlers for all of the procedures
# registered via "logger::trace add".  Does nothing if tracing is already
# turned on.

proc ::logger::_trace_on { service } {
    set tcl_version [package provide Tcl]

    if {[package vcompare $tcl_version "8.4"] < 0} {
        return -code error \
               -errorcode [list LOGGER TRACE_NOT_AVAILABLE] \
              [::logger::mc "execution tracing is not available in Tcl %s" $tcl_version]
    }

    namespace eval ::logger::tree::${service} {
        if {!$tracingEnabled} {
            set tracingEnabled 1
            ::logger::_enable_traces $service $traceList
        }
    }

    return 1
}

# This procedure handles the "logger::trace off" command.  If tracing
# is turned on, it will disable Tcl trace handlers for all of the procedures
# registered via "logger::trace add", leaving them in the list so they
# tracing on all of them can be enabled again with "logger::trace on".
# Does nothing if tracing is already turned off.

proc ::logger::_trace_off { service } {
    namespace eval ::logger::tree::${service} {
        if {$tracingEnabled} {
            ::logger::_disable_traces $service $traceList
            set tracingEnabled 0
        }
    }

    return 1
}

# This procedure is used by the logger::trace add and remove commands to
# process the arguments in a common fashion.  If the -ns switch is given
# first, this procedure will return a list of all existing procedures in
# all of the namespaces given in remaining arguments.  Otherwise, each
# argument is taken to be either a pattern for a glob-style search of
# procedure names or, failing that, a namespace, in which case this
# procedure returns a list of all the procedures matching the given
# pattern (or all in the named namespace, if no procedures match).

proc ::logger::_trace_get_proclist { inputList } {
    set procList ""

    if {[string equal [lindex $inputList 0] "-ns"]} {
	# Verify that at least one target namespace was supplied

	set inputList [lrange $inputList 1 end]
	if {![llength $inputList]} {
	    return -code error \
                   -errorcode [list LOGGER TARGET_MISSING] \
                   [::logger::mc "Must specify at least one namespace target"]
	}

	# Rebuild the argument list to contain namespace procedures

	foreach namespace $inputList {
            # Don't allow tracing of the logger (or child) namespaces

	    if {![string match "::logger::*" $namespace]} {
		set nsProcList  [::info procs ${namespace}::*]
                set procList    [concat $procList $nsProcList]
            }
	}
    } else {
        # Search for procs or namespaces matching each of the specified
        # patterns.

        foreach pattern $inputList {
	    set matches [uplevel 1 ::info proc $pattern]

	    if {![llength $matches]} {
	        if {[uplevel 1 namespace exists $pattern]} {
		    set matches [::info procs ${pattern}::*]
	        }

                # Matched procs will be qualified due to above pattern

                set procList [concat $procList $matches]
            } elseif {[string match "::*" $pattern]} {
                # Patterns were pre-qualified - add them directly

                set procList [concat $procList $matches]
            } else {
                # Qualify each proc with the namespace it was in

                set ns [uplevel 1 namespace current]
                if {$ns == "::"} {
                    set ns ""
                }
                foreach proc $matches {
                    lappend procList ${ns}::$proc
                }
            }
        }
    }

    return $procList
}

# This procedure handles the "logger::trace add" command.  If the tracing
# feature is enabled, it will enable the Tcl entry and leave trace handlers
# for each procedure specified that isn't already being traced.  Each
# procedure is added to the list of procedures that the logger trace feature
# should log when tracing is enabled.

proc ::logger::_trace_add { service procList } {
    upvar #0 ::logger::tree::${service}::traceList traceList

    # Handle -ns switch and glob search patterns for procedure names

    set procList [uplevel 1 [list logger::_trace_get_proclist $procList]]

    # Enable tracing for each procedure that has not previously been
    # specified via logger::trace add.  If tracing is off, this will just
    # store the name of the procedure for later when tracing is turned on.

    foreach procName $procList {
        if {[lsearch -exact $traceList $procName] == -1} {
            lappend traceList $procName
            ::logger::_enable_traces $service [list $procName]
        }
    }
}

# This procedure handles the "logger::trace remove" command.  If the tracing
# feature is enabled, it will remove the Tcl entry and leave trace handlers
# for each procedure specified.  Each procedure is removed from the list
# of procedures that the logger trace feature should log when tracing is
# enabled.

proc ::logger::_trace_remove { service procList } {
    upvar #0 ::logger::tree::${service}::traceList traceList

    # Handle -ns switch and glob search patterns for procedure names

    set procList [uplevel 1 [list logger::_trace_get_proclist $procList]]

    # Disable tracing for each proc that previously had been specified
    # via logger::trace add.  If tracing is off, this will just
    # remove the name of the procedure from the trace list so that it
    # will be excluded when tracing is turned on.

    foreach procName $procList {
        set index [lsearch -exact $traceList $procName]
        if {$index != -1} {
            set traceList [lreplace $traceList $index $index]
            ::logger::_disable_traces $service [list $procName]
        }
    }
}

# This procedure enables Tcl trace handlers for all procedures specified.
# It is used both to enable Tcl's tracing for a single procedure when
# removed via "logger::trace add", as well as to enable all traces
# via "logger::trace on".

proc ::logger::_enable_traces { service procList } {
    upvar #0 ::logger::tree::${service}::tracingEnabled tracingEnabled

    if {$tracingEnabled} {
        foreach procName $procList {
            ::trace add execution $procName enter \
                [list ::logger::_trace_enter $service]
            ::trace add execution $procName leave \
                [list ::logger::_trace_leave $service]
        }
    }
}

# This procedure disables Tcl trace handlers for all procedures specified.
# It is used both to disable Tcl's tracing for a single procedure when
# removed via "logger::trace remove", as well as to disable all traces
# via "logger::trace off".

proc ::logger::_disable_traces { service procList } {
    upvar #0 ::logger::tree::${service}::tracingEnabled tracingEnabled

    if {$tracingEnabled} {
        foreach procName $procList {
            ::trace remove execution $procName enter \
                [list ::logger::_trace_enter $service]
            ::trace remove execution $procName leave \
                [list ::logger::_trace_leave $service]
        }
    }
}

########################################################################
# Trace Handlers
########################################################################

# This procedure is invoked upon entry into a procedure being traced
# via "logger::trace add" when tracing is enabled via "logger::trace on"
# to log information about how the procedure was called.

proc ::logger::_trace_enter { service cmd op } {
    # Parse the command
    set procName [uplevel 1 namespace origin [lindex $cmd 0]]
    set args     [lrange $cmd 1 end]

    # Display the message prefix
    set callerLvl [expr {[::info level] - 1}]
    set calledLvl [::info level]

    lappend message "proc" $procName
    lappend message "level" $calledLvl
    lappend message "script" [uplevel ::info script]

    # Display the caller information
    set caller ""
    if {$callerLvl >= 1} {
	# Display the name of the caller proc w/prepended namespace
	catch {
	    set callerProcName [lindex [::info level $callerLvl] 0]
	    set caller [uplevel 2 namespace origin $callerProcName]
	}
    }

    lappend message "caller" $caller

    # Display the argument names and values
    set argSpec [uplevel 1 ::info args $procName]
    set argList ""
    if {[llength $argSpec]} {
	foreach argName $argSpec {
            lappend argList $argName

	    if {$argName == "args"} {
                lappend argList $args
                break
	    } else {
	        lappend argList [lindex $args 0]
	        set args [lrange $args 1 end]
            }
	}
    }

    lappend message "procargs" $argList
    set message [list $op $message]

    ::logger::tree::${service}::tracecmd $message
}

# This procedure is invoked upon leaving into a procedure being traced
# via "logger::trace add" when tracing is enabled via "logger::trace on"
# to log information about the result of the procedure call.

proc ::logger::_trace_leave { service cmd status rc op } {
    variable RETURN_CODES

    # Parse the command
    set procName [uplevel 1 namespace origin [lindex $cmd 0]]

    # Gather the caller information
    set callerLvl [expr {[::info level] - 1}]
    set calledLvl [::info level]

    lappend message "proc" $procName "level" $calledLvl
    lappend message "script" [uplevel ::info script]

    # Get the name of the proc being returned to w/prepended namespace
    set caller ""
    catch {
        set callerProcName [lindex [::info level $callerLvl] 0]
        set caller [uplevel 2 namespace origin $callerProcName]
    }

    lappend message "caller" $caller

    # Convert the return code from numeric to verbal

    if {$status < [llength $RETURN_CODES]} {
        set status [lindex $RETURN_CODES $status]
    }

    lappend message "status" $status
    lappend message "result" $rc

    # Display the leave message

    set message [list $op $message]
    ::logger::tree::${service}::tracecmd $message

    return 1
}

