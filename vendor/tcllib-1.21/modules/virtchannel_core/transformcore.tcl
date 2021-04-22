# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::transform::core 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Support package handling a core
# Meta description aspect of reflected transform channels
# Meta description (initialization, finalization).
# Meta description It is expected that this class
# Meta description is used as either one superclass of the
# Meta description class C for a specific channel, or is
# Meta description mixed into C.
# Meta platform tcl
# Meta require TclOO
# Meta require {Tcl 8.6}
# @@ Meta End

# # ## ### ##### ######## #############

package require Tcl 8.6

# # ## ### ##### ######## #############

oo::class create ::tcl::transform::core {
    destructor {
	if {$channel eq {}} return
	close $channel
	return
    }

    # # ## ### ##### ######## #############

    method initialize {thechannel mode} {
	set methods [info object methods [self] -all]

	# Note: Checking of the mode against the supported methods is
	#       done by the caller.

	set channel $thechannel
	set supported {}
	foreach m {
	    initialize finalize read write drain flush limit?
	} {
	    if {$m in $methods} {
		lappend supported $m
	    }
	}
	return $supported
    }

    method finalize {c} {
	set channel {} ; # Prevent destroctor from calling close.
	my destroy
	return
    }

    # # ## ### ##### ######## #############

    variable channel

    # channel The channel the handler belongs to.
    # # ## ### ##### ######## #############
}

# # ## ### #####
package provide tcl::transform::core 1
return
