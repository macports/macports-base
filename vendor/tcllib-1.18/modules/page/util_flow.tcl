# -*- tcl -*-
# General tree iterative walking for dataflow algorithms.

# ### ### ### ######### ######### #########
## Requisites

package require snit

# ### ### ### ######### ######### #########
## API

namespace eval ::page::util::flow {}

proc ::page::util::flow {start fvar nvar script} {
    set f [uplevel 1 [list ::page::util::flow::iter %AUTO% $start $fvar $nvar $script]]
    $f destroy
    return
}

# ### ### ### ######### ######### #########
## Internals

snit::type ::page::util::flow::iter {
    constructor {startset fvar nvar script} {
	$self visitl $startset

	# Export the object for use by the flow script
	upvar 3 $fvar flow ; set flow $self
	upvar 3 $nvar current

	while {[array size visit]} {
	    set nodes [array names visit]
	    array unset visit *

	    foreach n $nodes {
		set current $n
		set code [catch {uplevel 3 $script} result]

		# decide what to do upon the return code:
		#
		#               0 - the body executed successfully
		#               1 - the body raised an error
		#               2 - the body invoked [return]
		#               3 - the body invoked [break]
		#               4 - the body invoked [continue]
		# everything else - return and pass on the results

		switch -exact -- $code {
		    0 {}
		    1 {
			return -errorinfo $::errorInfo  \
				-errorcode $::errorCode -code error $result
		    }
		    3 {
			# FRINK: nocheck
			return -code break
		    }
		    4 {}
		    default {
			# This includes code 2 (return).
			return -code $code $result
		    }
		}
	    }
	}
	return
    }

    method visit {n} {
	set visit($n) .
	return
    }

    method visitl {nodelist} {
	foreach n $nodelist {set visit($n) .}
	return
    }

    method visita {args} {
	foreach n $args {set visit($n) .}
	return
    }

    variable visit -array {}
}

# ### ### ### ######### ######### #########
## Ready

package provide page::util::flow 0.1
