# tie.tcl --
#
#	Tie arrays to persistence engines.
#
# Copyright (c) 2004-2021 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require snit
package require cmdline

# ### ### ### ######### ######### #########
## Implementation

# ### ### ### ######### ######### #########
## Public API

namespace eval ::tie {}

proc ::tie::tie {avar args} {
    # Syntax : avar ?-open? ?-save? ?-merge? dstype dsargs...?

    variable registry

    upvar 1 $avar thearray

    if {![array exists thearray]} {
	return -code error "can't tie to \"$avar\": no such array variable"
    }

    # Create shortcuts for the options, and initialize them.
    foreach k {open save merge} {upvar 0 opts($k) $k}
    set open  0
    set save  0
    set merge 0

    # Option processing ...

    array set opts [GetOptions args]

    # Basic validation ...

    if {$open && $save} {
	return -code error "-open and -save exclude each other"
    } elseif {!$open && !$save} {
	set open 1
    }

    if {![llength $args]} {
	return -code error "dstype and type arguments missing"
    }
    set type [lindex $args 0]
    set args [lrange $args 1 end]

    # Create DS object from type (DS class) and args.
    if {[::info exists registry($type)]} {
	set type $registry($type)
    }
    set dso [eval [concat $type %AUTO% $args]]

    Connect thearray $open $merge $dso
    return [NewToken thearray $dso]
}

proc ::tie::untie {avar args} {
    # Syntax : arrayvarname ?token?

    variable mgr
    variable tie

    upvar 1 $avar thearray

    switch -exact -- [llength $args] {
	0 {
	    # Remove all ties for the variable. Do nothing if there
	    # are no ties in place.

	    set mid [TraceManager thearray]
	    if {$mid eq ""} return
	}
	1 {
	    # Remove a specific tie.

	    set tid [lindex $args 0]
	    if {![::info exists tie($tid)]} {
		return -code error "Unknown tie \"$tid\""
	    }

	    foreach {mid dso} $tie($tid) break
	    set midvar [TraceManager thearray]

	    if {$mid ne $midvar} {
		return -code error "Tie \"$tid\" not associated with variable \"$avar\""
	    }

	    set pos       [lsearch -exact $mgr($mid) $tid]
	    set mgr($mid) [lreplace $mgr($mid) $pos $pos]

	    unset tie($tid)
	    $dso destroy

	    # Leave the manager in place if there still ties
	    # associated with the variable.
	    if {[llength $mgr($mid)]} return
	}
	default {
	    return -code error "wrong#args: array ?token?"	    
	}
    }

    # Delegate full removal to common code.
    Untie $mid thearray
    return
}

proc ::tie::info {cmd args} {
    variable mgr
    if {$cmd eq "ties"} {
	if {[llength $args] != 1} {
	    return -code error "wrong#args: should be \"tie::info ties avar\""
	}
	upvar 1 [lindex $args 0] thearray
	set mid [TraceManager thearray]
	if {$mid eq ""} {return {}}

	return $mgr($mid)
    } elseif {$cmd eq "types"} {
	if {[llength $args] != 0} {
	    return -code error "wrong#args: should be \"tie::info types\""
	}
	variable registry
	return [array get registry]
    } elseif {$cmd eq "type"} {
	if {[llength $args] != 1} {
	    return -code error "wrong#args: should be \"tie::info type dstype\""
	}
	variable registry
	set type [lindex $args 0]
	if {![::info exists registry($type)]} {
	    return -code error "Unknown type \"$type\""
	}
	return $registry($type)
    } else {
	return -code error "Unknown command \"$cmd\", should be ties, type, or types"
    }
}

proc ::tie::register {dsclasscmd _as_ dstype} {
    variable registry
    if {$_as_ ne "as"} {
	return -code error "wrong#args: should be \"tie::register command 'as' type\""
    }

    # Resolve a chain of type definitions right now.
    while {[::info exists registry($dsclasscmd)]} {
	set dsclasscmd $registry($dsclasscmd)
    }

    set registry($dstype) $dsclasscmd
    return
}

# ### ### ### ######### ######### #########
## Internal : Framework state

namespace eval ::tie {
    # Registry of short names and their associated class commands

    variable  registry
    array set registry {}

    # Management databases for the ties.
    #
    #    mgr   : mgr id  -> list (tie id)
    #    tie   : tie id  -> (mgr id, dso cmd)
    #
    #    array  ==> mgr -1---n-> tie
    #                ^           |
    #                +-1-------n-+
    #
    #    lock  : mgr id x key -> 1/exists 0/!exists

    # Database of managers for arrays.
    # Also counter for the generation of mgr ids.

    variable mgrcount 0
    variable mgr ; array set mgr {}


    # Database of ties (and their tokens).
    # Also counter for the generation of tie ids.

    variable  tiecount 0
    variable  tie ; array set tie {}

    # Database of locked arrays, keys, and data sources.

    variable  lock ; array set lock {}

    # Key	| Meaning
    # ---	+ -------
    # $mid,$idx	| Propagation for index $idx is in progress.
}

# ### ### ### ######### ######### #########
## Internal : Option processor

proc ::tie::GetOptions {arglistVar} {
    upvar 1 $arglistVar argv

    set opts [lrange [::cmdline::GetOptionDefaults {
	{open        {}}
	{save        {}}
	{merge       {}}
    } result] 2 end] ;# Remove ? and help.

    set argc [llength $argv]
    while {[set err [::cmdline::getopt argv $opts opt arg]]} {
	if {$err < 0} {
	    set olist ""
	    foreach o [lsort $opts] {
		if {[string match *.arg $o]} {
		    set o [string range $o 0 end-4]
		}
		lappend olist -$o
	    }
	    return -code error "bad option \"$opt\",\
		    should be one of\
		    [linsert [join $olist ", "] end-1 or]"
	}
	set result($opt) $arg
    }
    return [array get result]
}

# ### ### ### ######### ######### #########
## Internal : Token generator

proc ::tie::NewToken {avar dso} {
    variable tiecount
    variable tie
    variable mgr

    upvar 1 $avar thearray

    set     mid         [NewTraceManager thearray]
    set     tid         tie[incr tiecount]
    set     tie($tid)   [list $mid $dso]
    lappend mgr($mid)   $tid
    return $tid
}

# ### ### ### ######### ######### #########
## Internal : Trace Management

proc ::tie::TraceManager {avar} {
    upvar 1 $avar thearray

    set traces [trace info variable thearray]

    foreach t $traces {
	foreach {op cmd} $t break
	if {
	    ([llength $cmd] == 2) &&
	    ([lindex $cmd 0] eq "::tie::Trace")
	} {
	    # Our internal manager id is the first argument of the
	    # trace command we attached to the array.
	    return [lindex $cmd 1]
	}
    }
    # No framework trace was found, there is no manager.
    return {}
}

proc ::tie::NewTraceManager {avar} {
    variable mgrcount
    variable mgr

    upvar 1 $avar thearray

    set mid [TraceManager thearray]
    if {$mid ne ""} {return $mid}

    # No manager was found, we have to create a new one for the
    # variable.

    set mid [incr mgrcount]
    set mgr($mid) [list]

    trace add variable thearray \
	    {write unset} \
	    [list ::tie::Trace $mid]

    return $mid
}

proc ::tie::Trace {mid avar idx op} {
    #puts "[pid] Trace $mid $avar ($idx) $op"

    variable mgr
    variable tie
    variable lock

    upvar $avar thearray

    if {($op eq "unset") && ($idx eq "")} {
	# The variable as a whole is unset. This
	# destroys all the ties placed on it.
	# Note: The traces are already gone!

	Untie $mid thearray
	return
    }

    if {[::info exists lock($mid,$idx)]} {
	#puts "%% locked $mid,$idx"
	return
    }
    set lock($mid,$idx) .
    #puts "%% lock $mid,$idx"

    if {$op eq "unset"} {
	foreach tid $mgr($mid) {
	    set dso [lindex $tie($tid) 1]
	    $dso unsetv $idx
	}
    } elseif {$op eq "write"} {
	set value $thearray($idx)
	foreach tid $mgr($mid) {
	    set dso [lindex $tie($tid) 1]
	    $dso setv $idx $value
	}
    } else {
	#puts "%% unlock/1 $mid,$idx"
	unset -nocomplain lock($mid,$idx)
	return -code error "Bad trace call, unexpected operation \"$op\""
    }

    #puts "%% unlock/2 $mid,$idx"
    unset -nocomplain lock($mid,$idx)
    return
}

proc ::tie::Connect {avar open merge dso} {
    upvar 1 $avar thearray

    # Doing this as first operation is a convenient check that the ds
    # object command exists.
    set dsdata [$dso get]
 
    if {$open} {
	# Open DS and load data from it.

	# Save current contents of array, for restoration in case of
	# trouble.
	set save [array get thearray]

	if {$merge} {
	    # merge -> Remember the existing keys, so that we
	    # save their contents after loading the DS as well.
	    set wback [array names thearray]
	} else {
	    # not merge -> Replace existing content.
	    array unset thearray *
	}

	if {[set code [catch {
	    array set thearray $dsdata
	    # ! Propagation through other ties.
	} msg]]} {
	    # Errors found. Reset bogus contents, then reinsert the
	    # saved information to restore the previous state.
	    array unset thearray *
	    array set thearray $save

	    return -code $code \
		    -errorcode $::errorCode \
		    -errorinfo $::errorInfo $msg
	}

	if {$merge} {
	    # Now save everything we had before the tie was added into
	    # the DS. This may save data which came from the DS.
	    foreach idx $wback {
		$dso setv $idx $thearray($idx)
	    }
	}
    } else {
	# Save array data to DS.

	# Save current contents of DS, for restoration in case of
	# trouble.
	# set save $dsdata

	set source [array get thearray]

	if {$merge} {
	    # merge -> Remember the existing keys, so that we
	    # read their contents after saving the array as well.
	    set rback [$dso names]
	} else {
	    # not merge -> Replace existing content.
	    $dso unset
	}

	if {[set code [catch {
	    $dso set $source
	} msg]]} {
	    $dso unset
	    $dso set $dsdata

	    return -code $code \
		    -errorcode $::errorCode \
		    -errorinfo $::errorInfo $msg
	}

	if {$merge} {
	    # Now read everything we had before the tie was added from
	    # the DS. This may read data which came from the array.
	    foreach idx $rback {
		set thearray($idx) [$dso getv $idx]
		# ! Propagation through other ties.
	    }
	}
    }
    return
}

proc ::tie::Untie {mid avar} {
    variable mgr
    variable tie
    variable lock

    upvar 1 $avar thearray

    trace remove variable thearray \
	    {write unset} \
	    [list ::tie::Trace $mid]

    foreach tid $mgr($mid) {
	foreach {mid dso} $tie($tid) break
	# ASSERT: mid == mid

	unset tie($tid)
	$dso destroy
    }

    unset mgr($mid)
    array unset lock ${mid},*
    return
}

# ### ### ### ######### ######### #########
## Test helper, peek into internals
## Returns a serialized representation.

proc ::tie::Peek {} {
    variable mgr
    variable tie

    variable mgrcount
    variable tiecount

    list \
	    $mgrcount $tiecount \
	    mgr [Dictsort [array get mgr]] \
	    tie [Dictsort [array get tie]]
}

proc ::tie::Reset {} {
    variable mgrcount 0
    variable tiecount 0
    return
}

proc ::tie::Dictsort {dict} {
    array set a $dict
    set out [list]
    foreach key [lsort [array names a]] {
	lappend out $key $a($key)
    }
    return $out
}

# ### ### ### ######### ######### #########
## Standard DS classes
# @mdgen NODEP: tie::std::log
# @mdgen NODEP: tie::std::dsource
# @mdgen NODEP: tie::std::array
# @mdgen NODEP: tie::std::rarray
# @mdgen NODEP: tie::std::file
# @mdgen NODEP: tie::std::growfile

::tie::register {package require tie::std::log      ; ::tie::std::log}      as log
::tie::register {package require tie::std::dsource  ; ::tie::std::dsource}  as dsource
::tie::register {package require tie::std::array    ; ::tie::std::array}    as array
::tie::register {package require tie::std::rarray   ; ::tie::std::rarray}   as remotearray
::tie::register {package require tie::std::file     ; ::tie::std::file}     as file
::tie::register {package require tie::std::growfile ; ::tie::std::growfile} as growfile

# ### ### ### ######### ######### #########
## Ready to go

package provide tie 1.2
