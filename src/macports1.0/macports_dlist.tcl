# macports1.0/macports_dlist.tcl
#
# Copyright (c) 2004-2005, 2007, 2009, 2011 The MacPorts Project
# Copyright (c) 2003 Kevin Van Vechten <kevin@opendarwin.org>
# Copyright (c) 2002 Apple Inc.
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
# 3. Neither the name of Apple Inc. nor the names of its contributors
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

package provide macports_dlist 1.0

# dependency dependency list evaluation package
#
# This package provides a generic mechanism for managing a list of
# dependencies.  The basic model is that each dependency item
# contains a list of tokens it Requires and tokens it Provides.
# A dependency is selected once all of the tokens it Requires have
# been provided by another dependency, or if a dependency has no
# requirements.

# Conceptually a dlist is an ordered list of ditem elements.
# The order perserves the dependency hierarchy.

# A dlist is an ordinary TCL list.
# A ditem should be created with the [ditem_create] procedure,
# and treated as an opaque reference.
# A statusdict is an ordinary TCL array, though macports_dlist
# should be given complete domain over its contents.
# XXX: should statusdict and dlist be part of a ditem tuple?
# Values in the status dict will be {-1, 0, 1} for {failure,
# pending, success} respectively.

# dlist_match_multi
# Returns all dependency entries for which the entry's value for 'key' exactly matches the given 'value'.
#   dlist - the dependency list to search
#   criteria - the key/value pairs to compare

proc dlist_match_multi {dlist criteria} {
	set result [list]
	foreach ditem $dlist {
		set match 1
		foreach {key value} $criteria {
			if {[ditem_key $ditem $key] ne $value} {
				set match 0
				break
			}
		}
		if {$match} {
			lappend result $ditem
		}
	}
	return $result
}

# dlist_search
# Returns all dependency entries whose 'key' contains 'value'.
#   dlist - the dependency list to search
#   key   - the key to compare: Requires, Provides, et al.
#   value - the value to compare

proc dlist_search {dlist key value} {
	set result [list]
	foreach ditem $dlist {
		if {[ditem_contains $ditem $key $value]} {
			lappend result $ditem
		}
	}
	return $result
}

# dlist_delete
# Deletes the specified ditem from the dlist.
#   dlist - the list to search
#   ditem - the item to delete
proc dlist_delete {dlist ditem} {
	upvar $dlist uplist
	set ix [lsearch -exact $uplist $ditem]
	if {$ix >= 0} {
		set uplist [lreplace $uplist $ix $ix]
	}
}

# dlist_has_pending
# Returns true if the dlist contains ditems
# which will provide one of the specified names,
# and thus are still "pending".
#   dlist  - the dependency list to search
#   tokens - the list of pending tokens to check for

proc dlist_has_pending {dlist tokens} {
	foreach token $tokens {
		if {[llength [dlist_search $dlist provides $token]] > 0} {
			return 1
		}
	}
	return 0
}

# dlist_count_unmet
# Returns the total number of unmet dependencies in
# the list of tokens.  If the tokens are in the status
# dictionary with a successful result code, they are 
# considered met.
proc dlist_count_unmet {dlist statusdict tokens} {
	upvar $statusdict upstatus
	set result 0
	foreach token $tokens {
		if {[info exists upstatus($token)] &&
			$upstatus($token) == 1} {
			continue
		} else {
			incr result
		}
	}
	return $result
}

# ditem_create
# Create a new array in the macports_dlist namespace
# returns the name of the array.  This should be used as
# the ditem handle.

proc ditem_create {} {
	return [macports_dlist::ditem_create]
}

proc ditem_delete {ditem} {
	macports_dlist::ditem_delete $ditem
}

# ditem_key
# Sets and returns the given key of the dependency item.
#   ditem - the dependency item to operate on
#   key   - the key to set
#   value - optional value to set the key to

proc ditem_key {ditem args} {
	return [macports_dlist::ditem_key $ditem {*}$args]
}

# ditem_append
# Appends the value to the given key of the dependency item.
#   ditem - the dependency item to operate on
#   key   - the key to append to
#   value - the value to append to the key

proc ditem_append {ditem key args} {
	return [macports_dlist::ditem_append $ditem $key {*}$args]
}

# ditem_append_unique
# Appends the value to the given key of the dependency item if
# they were not there yet.
#   ditem - the dependency item to operate on
#   key   - the key to append to
#   value - the value to append to the key

proc ditem_append_unique {ditem key args} {
	return [macports_dlist::ditem_append_unique $ditem $key {*}$args]
}

# ditem_contains
# Tests whether the ditem key contains the specified value;
# or if the value is omitted, tests whether the key exists.
#   ditem - the dependency item to test
#   key   - the key to examine
#   value - optional value to search for in the key
proc ditem_contains {ditem key args} {
	return [macports_dlist::ditem_contains $ditem $key {*}$args]
}

# dlist_append_dependents
# Returns the ditems which are dependents of the ditem specified.
#   dlist - the dependency list to search
#   ditem - the item which itself, and its dependents should be selected
#   result - used for recursing, pass empty initially.

proc dlist_append_dependents {dlist ditem result} {
	# Only append things if the root item is not in the list.
	# (otherwise, it means we already did this sub-graph)
	if {$ditem ni $result} {
		lappend result $ditem

		# Recursively append any hard dependencies.
		foreach token [ditem_key $ditem requires] {
			foreach provider [dlist_search $dlist provides $token] {
				set result [dlist_append_dependents $dlist $provider $result]
			}
		}
		# XXX: add soft-dependencies?
	}
	return $result
}

# dlist_get_next
# Returns the any eligible item from the dependency list.
# Eligibility is a function of the ditems in the list and
# the status dictionary.  A ditem is eligible when all of
# the services it Requires are present in the status
# dictionary with a successful result code.
#
# Notes: this implementation of get next defers items based
# on unfulfilled tokens in the Uses key.  However these items
# will eventually be returned if there are no alternatives.
# Soft-dependencies can be implemented in this way.
#   dlist      - the dependency list to select from
#   statusdict - the status dictionary describing the history
#                of the dependency list.

proc dlist_get_next {dlist statusdict} {
	upvar $statusdict upstatus
	set nextitem {}
	
	# arbitrary large number ~ INT_MAX
	set minfailed 2000000000
	
	foreach ditem $dlist {
		# Skip if the ditem has unsatisfied hard dependencies
		if {[dlist_count_unmet $dlist upstatus [ditem_key $ditem requires]]} {
			continue
		}
		
		# We will favor the ditem with the fewest unmet soft dependencies
		set unmet [dlist_count_unmet $dlist upstatus [ditem_key $ditem uses]]
		
		# Delay items with unment soft dependencies that can eventually be met
		if {$unmet > 0 && [dlist_has_pending $dlist [ditem_key $ditem uses]]} {
			continue
		}
		
		if {$unmet >= $minfailed} {
			# not better than the last pick
			continue
		} else {
			# better than the last pick (fewer unmet soft deps)
			set minfailed $unmet
			set nextitem $ditem
		}
	}
	return $nextitem
}

# dlist_eval
# Evaluate the dlist, select each eligible ditem according to
# the optional selector argument (the default selector is 
# dlist_get_next).  The specified handler is then invoked on
# each ditem in the order they are selected.  When no more
# ditems are eligible to run (the selector returns {}) then
# dlist_eval will exit with a list of the remaining ditems,
# or {} if all ditems were evaluated.
#   dlist    - the dependency list to evaluate
#   testcond - test condition to populate the status dictionary
#              should return {-1, 0, 1}
#   handler  - the handler to invoke on each ditem
#   canfail  - If 1, then progress will not stop when a failure
#              occures; if 0, then dlist_eval will return on the
#              first failure
#   selector - the selector for determining eligibility
#   reason_var - variable name to return failure reason in

proc dlist_eval {dlist testcond handler {canfail "0"} {selector "dlist_get_next"} {reason_var "dlist_eval_reason"}} {
	array set statusdict [list]
	if {$reason_var ne ""} {
	    upvar $reason_var reason
	}
	set reason ""

	# Do a pre-run seeing if any items automagically
	# can evaluate to true.
	if {$testcond ne ""} {
		foreach ditem $dlist {
			if {[$testcond $ditem] == 1} {
				foreach token [ditem_key $ditem provides] {
					set statusdict($token) 1
				}
				dlist_delete dlist $ditem
			}
		}
	}
	
	# Loop for as long as there are ditems in the dlist.
	while {1} {
		set ditem [$selector $dlist statusdict]

		if {$ditem eq {}} {
			if {[llength $dlist] > 0} {
				set reason unmet_deps
			}
			break
		} else {
			# $handler should return a unix status code, 0 for success.
			# statusdict notation is 1 for success
			if {[catch {{*}$handler $ditem} result]} {
				ui_debug $::errorInfo
				ui_error $result
				set reason handler
				return $dlist
			}
			# No news is good news at this point.
			if {$result eq {}} { set result 0 }
			
			foreach token [ditem_key $ditem provides] {
				set statusdict($token) [expr {$result == 0}]
			}
			
			# Abort if we're not allowed to fail
			if {$canfail == 0 && $result != 0} {
			    set reason handler
				return $dlist
			}
			
			# Delete the ditem from the waiting list.
			dlist_delete dlist $ditem
		}
	}
	
	# Return the list of lusers
	return $dlist
}


##### Private API #####
# Anything below this point is subject to change without notice.
#####

# Each ditem is actually an array in the macports_dlist
# namespace.  ditem keys correspond to the equivalent array
# key.  A dlist is simply a list of names of ditem arrays.
# All private API functions exist in the macports_dlist
# namespace.

namespace eval macports_dlist {

variable ditem_uniqid 0

proc ditem_create {} {
	variable ditem_uniqid
	incr ditem_uniqid
	set ditem "ditem_${ditem_uniqid}"
	variable $ditem
	array set $ditem [list]
	return $ditem
}

proc ditem_delete {ditem} {
	variable $ditem
	unset $ditem
}

proc ditem_key {ditem args} {
	variable $ditem
	set nbargs [llength $args]
	if {$nbargs > 1} {
		set key [lindex $args 0]
		return [set [set ditem]($key) [lindex $args 1]]
	} elseif {$nbargs == 1} {
		set key [lindex $args 0]
		if {[info exists [set ditem]($key)]} {
		    return [set [set ditem]($key)]
		} else {
		    return {}
		}
	} else {
		return [array get $ditem]
	}
}

proc ditem_append {ditem key args} {
	variable $ditem
	if {[info exists [set ditem]($key)]} {
	    set x [set [set ditem]($key)]
	} else {
	    set x {}
	}
	if {$x ne {}} {
		lappend x {*}$args
	} else {
		set x $args
	}
	set [set ditem]($key) $x
	return $x
}

proc ditem_append_unique {ditem key args} {
	variable $ditem
	if {[info exists [set ditem]($key)]} {
	    set x [set [set ditem]($key)]
	} else {
	    set x {}
	}
	if {$x ne {}} {
		lappend x {*}$args
		set x [lsort -unique $x]
	} else {
		set x $args
	}
	set [set ditem]($key) $x
	return $x
}

proc ditem_contains {ditem key args} {
	variable $ditem
	if {[llength $args] == 0} {
		return [info exists [set ditem]($key)]
	} else {
		if {[info exists [set ditem]($key)]} {
			set x [set [set ditem]($key)]
		} else {
			return 0
		}
		if {[llength $x] > 0 && [lindex $args 0] in $x} {
			return 1
		} else {
			return 0
		}
	}
}

# End of macports_dlist namespace
}
