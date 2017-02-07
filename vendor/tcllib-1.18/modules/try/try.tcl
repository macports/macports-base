# # ## ### ##### ######## ############# ####################
## -*- tcl -*-
## (C) 2008-2011 Donal K. Fellows, Andreas Kupries, BSD licensed.

# The code here is a forward-compatibility implementation of Tcl 8.6's
# try/finally command (TIP 329), for Tcl 8.5. It was directly pulled
# from Tcl 8.6 revision ?, when try/finally was implemented as Tcl
# procedure instead of in C.

# It makes use of the following Tcl 8.5 features:
# lassign, dict, {*}.

# # ## ### ##### ######## ############# ####################

package provide try 1
package require Tcl 8.5
# Do nothing if the "try" command exists already (8.6 and higher).
if {[llength [info commands try]]} return

# # ## ### ##### ######## ############# ####################

namespace eval ::tcl::control {
    # These are not local, since this allows us to [uplevel] a [catch] rather
    # than [catch] the [uplevel]ing of something, resulting in a cleaner
    # -errorinfo:
    variable em {}
    variable opts {}

    variable magicCodes { ok 0 error 1 return 2 break 3 continue 4 }

    namespace export try

    # ::tcl::control::try --
    #
    #	Advanced error handling construct.
    #
    # Arguments:
    #	See try(n) for details
    proc try {args} {
	variable magicCodes

	# ----- Parse arguments -----

	set trybody [lindex $args 0]
	set finallybody {}
	set handlers [list]
	set i 1

	while {$i < [llength $args]} {
	    switch -- [lindex $args $i] {
		"on" {
		    incr i
		    set code [lindex $args $i]
		    if {[dict exists $magicCodes $code]} {
			set code [dict get $magicCodes $code]
		    } elseif {![string is integer -strict $code]} {
			set msgPart [join [dict keys $magicCodes] {", "}]
			error "bad code '[lindex $args $i]': must be\
			    integer or \"$msgPart\""
		    }
		    lappend handlers [lrange $args $i $i] \
			[format %d $code] {} {*}[lrange $args $i+1 $i+2]
		    incr i 3
		}
		"trap" {
		    incr i
		    if {![string is list [lindex $args $i]]} {
			error "bad prefix '[lindex $args $i]':\
			    must be a list"
		    }
		    lappend handlers [lrange $args $i $i] 1 \
			{*}[lrange $args $i $i+2]
		    incr i 3
		}
		"finally" {
		    incr i
		    set finallybody [lindex $args $i]
		    incr i
		    break
		}
		default {
		    error "bad handler '[lindex $args $i]': must be\
			\"on code varlist body\", or\
			\"trap prefix varlist body\""
		}
	    }
	}

	if {($i != [llength $args]) || ([lindex $handlers end] eq "-")} {
	    error "wrong # args: should be\
		\"try body ?handler ...? ?finally body?\""
	}

	# ----- Execute 'try' body -----

	variable em
	variable opts
	set EMVAR  [namespace which -variable em]
	set OPTVAR [namespace which -variable opts]
	set code [uplevel 1 [list ::catch $trybody $EMVAR $OPTVAR]]

	if {$code == 1} {
	    set line [dict get $opts -errorline]
	    dict append opts -errorinfo \
		"\n    (\"[lindex [info level 0] 0]\" body line $line)"
	}

	# Keep track of the original error message & options
	set _em $em
	set _opts $opts

	# ----- Find and execute handler -----

	set errorcode {}
	if {[dict exists $opts -errorcode]} {
	    set errorcode [dict get $opts -errorcode]
	}
	set found false
	foreach {descrip oncode pattern varlist body} $handlers {
	    if {!$found} {
		if {
		    ($code != $oncode) || ([lrange $pattern 0 end] ne
					   [lrange $errorcode 0 [llength $pattern]-1] )
		} then {
		    continue
		}
	    }
	    set found true
	    if {$body eq "-"} {
		continue
	    }

	    # Handler found ...

	    # Assign trybody results into variables
	    lassign $varlist resultsVarName optionsVarName
	    if {[llength $varlist] >= 1} {
		upvar 1 $resultsVarName resultsvar
		set resultsvar $em
	    }
	    if {[llength $varlist] >= 2} {
		upvar 1 $optionsVarName optsvar
		set optsvar $opts
	    }

	    # Execute the handler
	    set code [uplevel 1 [list ::catch $body $EMVAR $OPTVAR]]

	    if {$code == 1} {
		set line [dict get $opts -errorline]
		dict append opts -errorinfo \
		    "\n    (\"[lindex [info level 0] 0] ... $descrip\"\
		    body line $line)"
		# On error chain to original outcome
		dict set opts -during $_opts
	    }

	    # Handler result replaces the original result (whether success or
	    # failure); capture context of original exception for reference.
	    set _em $em
	    set _opts $opts

	    # Handler has been executed - stop looking for more
	    break
	}

	# No catch handler found -- error falls through to caller
	# OR catch handler executed -- result falls through to caller

	# ----- If we have a finally block then execute it -----

	if {$finallybody ne {}} {
	    set code [uplevel 1 [list ::catch $finallybody $EMVAR $OPTVAR]]

	    # Finally result takes precedence except on success

	    if {$code == 1} {
		set line [dict get $opts -errorline]
		dict append opts -errorinfo \
		    "\n    (\"[lindex [info level 0] 0] ... finally\"\
		    body line $line)"
		# On error chain to original outcome
		dict set opts -during $_opts
	    }
	    if {$code != 0} {
		set _em $em
		set _opts $opts
	    }

	    # Otherwise our result is not affected
	}

	# Propagate the error or the result of the executed catch body to the
	# caller.
	dict incr _opts -level
	return -options $_opts $_em
    }
}

# # ## ### ##### ######## ############# ####################

namespace import ::tcl::control::try

# # ## ### ##### ######## ############# ####################
## Ready
