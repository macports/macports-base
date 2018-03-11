# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::chan::fifo2 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta as::notes   This fifo2 command does not have to
# Meta as::notes   deal with the pesky details of
# Meta as::notes   threading for cross-thread
# Meta as::notes   communication. That is hidden in the
# Meta as::notes   implementation of reflected
# Meta as::notes   channels. It is less optimal as the
# Meta as::notes   command provided by Memchan as this
# Meta as::notes   fifo2 may involve three threads when
# Meta as::notes   sending data around: The threads the
# Meta as::notes   two endpoints are in, and the thread
# Meta as::notes   holding this code. Memchan's C
# Meta as::notes   implementation does not need this last
# Meta as::notes   intermediary thread.
# Meta description Re-implementation of Memchan's fifo2
# Meta description channel. Based on Tcl 8.5's channel
# Meta description reflection support. Exports a single
# Meta description command for the creation of new
# Meta description channels. No arguments. Result are the
# Meta description handles of the two new channels.
# Meta platform tcl
# Meta require TclOO
# Meta require tcl::chan::halfpipe
# Meta require {Tcl 8.5}
# @@ Meta End
# # ## ### ##### ######## #############

package require Tcl 8.5
package require TclOO
package require tcl::chan::halfpipe

# # ## ### ##### ######## #############

namespace eval ::tcl::chan {}

proc ::tcl::chan::fifo2 {} {

    set coordinator [fifo2::implementation new]

    lassign [halfpipe \
	       -write-command [list $coordinator froma] \
	       -close-command [list $coordinator closeda]] \
	a ha

    lassign [halfpipe \
	       -write-command [list $coordinator fromb] \
	       -close-command [list $coordinator closedb]] \
	b hb

    $coordinator connect $a $ha $b $hb

    return [list $a $b]
}

oo::class create ::tcl::chan::fifo2::implementation {
    method connect {thea theha theb thehb} {
	set a $thea
	set b $theb
	set ha $theha
	set hb $thehb
	return
    }

    method closeda {c} {
	set a {}
	if {$b ne {}} {
	    close $b
	    set b {}
	}
	my destroy
	return
    }

    method closedb {c} {
	set b {}
	if {$a ne {}} {
	    close $a
	    set a {}
	}
	my destroy
	return
    }

    method froma {c bytes} {
	$hb put $bytes
	return
    }

    method fromb {c bytes} {
	$ha put $bytes
	return
    }

    # # ## ### ##### ######## #############

    variable a b ha hb

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## #############
package provide tcl::chan::fifo2 1
return
