## -*- tcl -*-
## (C) 2010 Andreas Kupries <andreas_kupries@users.sourceforge.net>
## 'unknown hook' code -- Derived from http://wiki.tcl.tk/12790 (Neil Madden).
## 'var/state' code    -- Derived from http://wiki.tcl.tk/1489 (various).
## BSD Licensed
# # ## ### ##### ######## ############# ######################

# namespacex hook  - Easy extensibility of 'namespace unknown'.
# namespacex info  - Get all variables/children, direct and indirect
# namespacex state - Save/restore the variable-based state of namespaces.

# # ## ### ##### ######## ############# ######################
## Requisites

package require Tcl 8.5  ; # namespace ensembles, {*}

# The try command is used in the namespacex::import command. For
# backward compatibility we will use the try package from tcllib if
# running on a platform that does not have it as a core command,
# i.e. before 8.6.

if {![llength [info commands try]]} {
    package require try ; # tcllib
}

namespace eval ::namespacex {
    namespace export add hook info import normalize strip state
    namespace ensemble create

    namespace eval hook {
	namespace export add proc on next
	namespace ensemble create

	# add - hook a command prefix into the chain of unknown handlers for a
	#       namespace. The prefix will be run with whatever args there are, so
	#       it should use 'args' to accomodate? to everything.

	# on  - ditto for separate guard and action command prefixes.
	#       If the guard fails it chains via next, otherwise the
	#       action runs. The action can asume that the guard checked for proper
	#       number of arguments, maybe even types. Whatever fits.

	# proc - like add, but an unamed procedure, with arguments and
	#        body. Not much use, except maybe to handle the exact way
	#        of chaining on your own (next can take a rewritten
	#        command, the 'on' compositor makes no use of that.

	# Both 'proc' and 'on' are based on 'add'.
    }

    namespace eval info {
	namespace export allvars allchildren vars
	namespace ensemble create
    }

    namespace eval state {
	namespace export drop set get
	namespace ensemble create
    }
}

# # ## ### ##### ######## ############# ######################
## Implementation :: Hooks - Visible API

# # ## ### ##### ######## ############# ######################
## (1) Core: Register a command prefix to be run by 
##           namespace unknown of a namespace FOO.
##           FOO defaults to the current namespace.
##
##     The prefixes are executed in reverse order of registrations,
##     i.e. the prefix registered last is executed first. The next
##     is run if and only if the current prefix forced this via
##    '::namespacex::hook::next'. IOW the chain is managed cooperatively.

proc ::namespacex::hook::add {args} {
    # syntax: ?namespace? cmdprefix

    if {[llength $args] > 2} {
	return -code error "wrong\#args, should be \"?namespace? cmdprefix\""
    } elseif {[llength $args] == 2} {
	lassign $args namespace cmdprefix
    } else { # [llength $args] == 1
	lassign $args cmdprefix
	set namespace [uplevel 1 { namespace current }]
    }

    #puts UH|ADD|for|$namespace|
    #puts UH|ADD|old|<<[Get $namespace]>>
    #puts UH|ADD|cmd|<<$cmdprefix>>

    Set $namespace [namespace code [list Handle $cmdprefix [Get $namespace]]]
    return
}

proc ::namespacex::hook::proc {args} {
    # syntax: ?namespace? arguments body

    set procNamespace [uplevel 1 { namespace current }]

    if {([llength $args] < 2) ||
	([llength $args] > 3)} {
	return -code error "wrong\#args, should be \"?namespace? arguments body\""
    } elseif {[llength $args] == 3} {
	lassign $args namespace arguments body
    } else { # [llength $args] == 2
	lassign $args arguments body
	set namespace $procNamespace
    }

    add $namespace [list ::apply [list $arguments $body $procNamespace]]
    return
}

proc ::namespacex::hook::on {args} {
    # syntax: ?namespace? guardcmd actioncmd

    if {([llength $args] < 2) ||
	([llength $args] > 3)} {
	return -code error "wrong\#args, should be \"?namespace? guard action\""
    } elseif {[llength $args] == 3} {
	lassign $args namespace guard action
    } else { # [llength $args] == 2
	lassign $args guard action
	set namespace [uplevel 1 { namespace current }]
    }

    add $namespace [list ::apply [list {guard action args} {
	if {![{*}$guard {*}$args]} {
	    # This is what requires '[ns current]' as context.
	    next
	}
	return [{*}$action {*}$args]
    } [namespace current]] $guard $action]
    return
}

proc ::namespacex::hook::next {args} {
    #puts UH|NEXT|$args|
    return -code continue -level 2 $args
}

# # ## ### ##### ######## ############# ######################
## Implementation :: Hooks - Internal Helpers.
## Get and set the unknown handler for a specified namespace.

# Generic handler with the user's handler and previous handler as
# arguments. The latter is an invokation of the internal handler
# again, with its own arguments. In this way 'Handle' forms the spine
# of the chain of handlers, running them and handling 'next' to
# traverse the chain. From a data structure perspective we have deeply
# nested list here, which is recursed into as the chain is traversed.

proc ::namespacex::hook::Get {ns} {
    return [namespace eval $ns { namespace unknown }]
}

proc ::namespacex::hook::Set {ns handler} {
    #puts UH|SET|$ns|<<$handler>>

    namespace eval $ns [list namespace unknown $handler]
    return
}

proc ::namespacex::hook::Handle {handler old args} {
    #puts UH|HDL|$handler|||old|$old||args||$args|

    set rc [catch {
	uplevel 1 $handler $args
    } result]

    #puts UH|HDL|rc=$rc|result=$result|

    if {$rc == 4} {
        # continue - invoke next handler

	if {$old eq {}} {
	    # no next handler available - stop
	    #puts UH|HDL|STOP
	    return -code error "invalid command name \"[lindex $args 0]\""
	}

        if {![llength $result]} {
            uplevel 1 $old $args
        } else {
            uplevel 1 $old $result
        }
    } else {
        return -code $rc $result
    }
}

# # ## ### ##### ######## ############# ######################
## Implementation :: Info - Visible API

proc ::namespacex::import {from args} {
    set upns [uplevel 1 {::namespace current}]
    if {![string match ::* $from]} {
	set from ${upns}::$from[set from {}]
    }
    set orig [namespace eval $from {::namespace export}]
    try {
	namespace eval $from {::namespace export *}
	set tmp [::namespace current]::[::info cmdcount]
	namespace eval $tmp [list ::namespace import ${from}::*]
	if {[llength $args] == 1} {
	    lappend args [lindex $args 0]
	}
	dict size $args
	foreach {old new} $args {
	    rename ${tmp}::$old ${upns}::$new
	}
	namespace delete $tmp
    } finally {
	namespace eval $from [list ::namespace export -clear {*}$orig]
    }
    return
}

proc ::namespacex::info::allvars {ns} {
    set ns [uplevel 1 [list [namespace parent] normalize $ns]]
    ::set result [::info vars ${ns}::*]
    foreach cns [allchildren $ns] {
	lappend result {*}[::info vars ${cns}::*]
    }
    return [::namespacex::Strip $ns $result]
}

proc ::namespacex::info::allchildren {ns} {
    set ns [uplevel 1 [list [namespace parent] normalize $ns]]
    ::set result [list]
    foreach cns [::namespace children $ns] {
	lappend result {*}[allchildren $cns]
	lappend result $cns
    }
    return $result
}

proc ::namespacex::info::vars {ns {pattern *}} {
    set ns [uplevel 1 [list [namespace parent] normalize $ns]]
    return [::namespacex::Strip $ns [::info vars ${ns}::$pattern]]
}

# this implementation avoids string operations
proc ::namespacex::normalize {ns} {
    if {[uplevel 1 [list ::namespace exists $ns]]} {
	return [uplevel 1 [list namespace eval $ns {::namespace current}]]
    }
    if {![string match ::* $ns]} {
	set ns [uplevel 1 {::namespace current}]::$ns
    }
    regsub {::+} $ns :: ns
    return $ns
}

proc ::namespacex::strip {ns itemlist} {
    set ns [uplevel 1 [list [namespace current] normalize $ns]]
    set n [string length $ns]
    incr n -1
    foreach i $itemlist {
	if {[string range $i 0 $n] eq "$ns"} continue
	return -code error "Expected $ns as prefix for $i, not found"
    }
    return [Strip $ns $itemlist]
}

proc ::namespacex::Strip {ns itemlist} {
    # Assert: is-fqn (ns)
    if {![string match {::*} $ns]} { error "Expected fqn for ns" }
    
    set n [string length $ns]
    incr n 2

    set result {}
    foreach i $itemlist {
	lappend result [string range $i $n end]
    }
    return $result
}

# # ## ### ##### ######## ############# ######################
## Implementation :: State - Visible API

proc ::namespacex::state::drop {ns} {
    ::set ns [uplevel 1 [list [namespace parent] normalize $ns]]
    namespace eval $ns [list ::unset {*}[::namespacex info allvars $ns]]
    return
}

proc ::namespacex::state::get {ns} {
    ::set ns [uplevel 1 [list [namespace parent] normalize $ns]]
    ::set result {}
    foreach v [::namespacex info allvars $ns] {
	namespace upvar $ns $v value
	if {[array exists value]} {
	    lappend result [list A $v] [array get value]
	} else {
	    lappend result [list S $v] $value
	}
    }
    return $result
}

proc ::namespacex::state::set {ns state} {
    ::set ns [uplevel 1 [list [namespace parent] normalize $ns]]
    # Inlined 'state drop'.
    namespace eval $ns [list ::unset {*}[::namespacex info allvars $ns]]

    foreach {var value} $state {
	if {[llength $var] == 2} {
	    # test for type-tagged variables
	    switch -exact -- [lindex $var 0] {
		A {
		    namespace upvar $ns [lindex $var 1] nsvar
		    array set nsvar $value
		    continue
		}
		S {
		    namespace upvar $ns [lindex $var 1] nsvar
		    ::set nsvar $value
		    continue
		}
	    }
	    # If tag is unknown assume untagged variable whose name contains spaces
	}
	# old-style state with untagged variable names. Assume scalar.
	namespace upvar $ns $var nsvar
	::set nsvar $value
    }
    return
}

# # ## ### ##### ######## ############# ######################
## Ready

package provide namespacex 0.3
