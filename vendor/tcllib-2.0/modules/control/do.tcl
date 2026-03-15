# do.tcl --
#
#        Tcl implementation of a "do ... while|until" loop.
#
# Originally written for the "Texas Tcl Shootout" programming contest
# at the 2000 Tcl Conference in Austin/Texas.
#
# Copyright (c) 2001 by Reinhard Max <Reinhard.Max@gmx.de>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: do.tcl,v 1.6 2004/01/15 06:36:12 andreas_kupries Exp $
#
namespace eval ::control {

    proc do {body args} {

	#
	# Implements a "do body while|until test" loop
	# 
	# It is almost as fast as builtin "while" command for loops with
	# more than just a few iterations.
	#

	set len [llength $args]
	if {$len !=2 && $len != 0} {
	    set proc [namespace current]::[lindex [info level 0] 0]
	    return -code error "wrong # args: should be \"$proc body\" or \"$proc body \[until|while\] test\""
	}
	set test 0
	foreach {whileOrUntil test} $args {
	    switch -exact -- $whileOrUntil {
		"while" {}
		"until" { set test !($test) }
		default {
		    return -code error \
			"bad option \"$whileOrUntil\": must be until, or while"
		}
	    }
	    break
	}

	# the first invocation of the body
	set code [catch { uplevel 1 $body } result]

	# decide what to do upon the return code:
	#
	#               0 - the body executed successfully
	#               1 - the body raised an error
	#               2 - the body invoked [return]
	#               3 - the body invoked [break]
	#               4 - the body invoked [continue]
	# everything else - return and pass on the results
	#
	switch -exact -- $code {
	    0 {}
	    1 {
		return -errorinfo [ErrorInfoAsCaller uplevel do]  \
		    -errorcode $::errorCode -code error $result
	    }
	    3 {
		# FRINK: nocheck
		return
	    }
	    4 {}
	    default {
		return -code $code $result
	    }
	}
	# the rest of the loop
	set code [catch {uplevel 1 [list while $test $body]} result]
	if {$code == 1} {
	    return -errorinfo [ErrorInfoAsCaller while do] \
		-errorcode $::errorCode -code error $result
	}
	return -code $code $result
	
    }

}
