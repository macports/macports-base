# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::chan::events 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Support package handling a core
# Meta description aspect of reflected base channels
# Meta description (timer
# Meta description driven file event support). Controls a
# Meta description timer generating the expected read/write
# Meta description events. It is expected that this class
# Meta description is used as either one superclass of the
# Meta description class C for a specific channel, or is
# Meta description mixed into C.
# Meta platform tcl
# Meta require tcl::chan::core
# Meta require TclOO
# Meta require {Tcl 8.5}
# @@ Meta End

# TODO :: set/get accessor methods for the timer delay

# # ## ### ##### ######## #############

package require Tcl 8.5
package require TclOO
package require tcl::chan::core

# # ## ### ##### ######## #############

oo::class create ::tcl::chan::events {
    superclass ::tcl::chan::core ; # -> initialize, finalize, destructor

    constructor {} {
	array set allowed {
	    read  0
	    write 0
	}
	set requested {}
	set delay     10
	return
    }

    # # ## ### ##### ######## #############

    method finalize {c} {
	my disallow read write
	next $c
    }

    # Allow/disallow the posting of events based on the
    # events requested by Tcl's IO system, and the mask of
    # events the instance's channel can handle, per all
    # preceding calls of allow and disallow.

    method watch {c requestmask} {
	if {$requestmask eq $requested} return
	set requested $requestmask
	my Update
	return
    }

    # # ## ### ##### ######## #############

    # Declare that the named events are handled by the
    # channel. This may start a timer to periodically post
    # these events to the instance's channel.

    method allow {args} {
	my Allowance $args yes
	return
    }

    # Declare that the named events are not handled by the
    # channel. This may stop the periodic posting of events
    # to the instance's channel.

    method disallow {args} {
	my Allowance $args no
	return
    }

    # # ## ### ##### ######## #############

    # Event System State - Timer driven

    variable timer allowed requested posting delay    

    # channel   = The channel to post events to - provided by superclass
    # timer     = Timer controlling the posting.
    # allowed   = Set of events allowed to post.
    # requested = Set of events requested by core.
    # posting   = Set of events we are posting.
    # delay     = Millisec interval between posts.

    # 'allowed' is an Array (event name -> boolean). The
    # value is true if the named event is allowed to be
    # posted.

    # Common code used by both allow and disallow to enter
    # the state change.

    method Allowance {events enable} {
	set changed no
	foreach event $events {
	    if {$allowed($event) == $enable} continue
	    set allowed($event) $enable
	    set changed yes
	}
	if {!$changed} return
	my Update
	return
    }

    # Merge the current event allowance and the set of
    # requested events into one datum, the set of events to
    # post. From that then derive whether we need a timer or
    # not and act accordingly.

    method Update {} {
	catch { after cancel $timer }
	set posting {}
	foreach event $requested {
	    if {!$allowed($event)} continue
	    lappend posting $event
	}
	if {[llength $posting]} {
	    set timer [after $delay \
			   [namespace code [list my Post]]]
	} else {
	    catch { unset timer }
	}
	return
    }

    # Post the current set of events, then reschedule to
    # make this periodic.

    method Post {} {
	my variable channel
	set timer [after $delay \
		       [namespace code [list my Post]]]
	chan postevent $channel $posting
	return
    }
}

# # ## ### #####
package provide tcl::chan::events 1
return
