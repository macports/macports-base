# -*- tcl -*-
# ### ### ### ######### ######### #########
## UEvent - User Event Service - Tcl-level general Event Handling

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.4
package require logger

namespace eval ::uevent               {}
namespace eval ::uevent::token        {}
namespace eval ::uevent::watch::tag   {}
namespace eval ::uevent::watch::event {}

# ### ### ### ######### ######### #########
## API: bind, unbind, generate

proc ::uevent::bind {tag event command} {
    # Register command (prefix!) as observer for events on the tag.
    # Command will take 3 arguments: tag, event, and dictionary of
    # detail information. Result is token by which the observer can
    # be removed.

    variable db
    variable dt
    variable tk
    variable ex

    log::debug [::list bind: $tag $event -> $command]

    set tec [::list $tag $event $command]

    # Same combination as before, same token
    if {[info exists ex($tec)]} {
	log::debug [::list known! $ex($tec)]
	return $ex($tec)
    }

    # New token, and enter everything ...

    set te [::list $tag $event]
    set t  [NewToken]

    set     tk($t) $tec
    set     ex($tec) $t
    lappend db($te)  $t
    lappend dt($tag) $t

    if {[llength $dt($tag)] == 1} {
	# Notify any watchers that at least one observers is now bound
	# to the tag
	watch::tag::Invoke bound $tag
    }
    if {[llength $db($te)] == 1} {
	# Notify any watchers that at least one observers is now bound
	# to the tag/event combination.
	watch::event::Invoke bound $tag $event
    }

    log::debug [::list new! $t]
    return $t
}

proc ::uevent::unbind {token} {
    # Removes the event binding represented by the token.

    variable db
    variable dt
    variable tk
    variable ex

    log::debug [::list unbind: $token]

    if {![info exists tk($token)]} return

    set tec $tk($token)
    set te [lrange $tec 0 1]

    log::debug [linsert [linsert $tec 0 =] end-1 ->]

    unset ex($tec)
    unset tk($token)

    set pos [lsearch -exact $db($te) $token]
    if {$pos < 0} return

    foreach {tag event} $te break

    if {[llength $db($te)] == 1} {
	# Last observer for this tag,event combination is gone.
	log::debug [linsert $te 0 last!]
	unset db($te)

	# Notify any watchers that no observers are bound to the
	# tag/event combination anymore.
	watch::event::Invoke unbound $tag $event
    } else {
	# Shrink list of observers
	log::debug [linsert [linsert $te 0 shrink!] end @ $pos]
	set db($te) [lreplace $db($te) $pos $pos]
    }

    if {[llength $dt($tag)] == 1} {
	# Last observer for this tag in itself
	log::debug [linsert $tag 0 last!]
	unset dt($tag)

	# Notify any watchers that no observers are bound to the tag
	# anymore.
	watch::tag::Invoke unbound $tag
    } else {
	# Shrink list of observers
	log::debug [linsert [linsert $tag 0 shrink!] end @ $pos]
	set dt($tag) [lreplace $dt($tag) $pos $pos]
    }

    return
}

proc ::uevent::generate {tag event {details {}}} {
    # Generates the event on the tag, with detail information (a
    # dictionary). This notifies all registered observers.  The
    # notifications are put into the Tcl event queue via 'after 0'
    # events, decoupling them in time from the issueing code.

    variable db
    variable tk

    log::debug [::list generate: $tag $event $details]

    set key [::list $tag $event]
    if {![info exists db($key)]} return

    foreach t $db($key) {
	set cmd [lindex $tk($t) 2]
	log::debug [::list trigger! $t = $cmd]
	after 0 [linsert $cmd end $tag $event $details]
    }

    return
}

proc ::uevent::list {args} {
    # list           - Return all known tags
    # list tag       - Return all events bound to the tag
    # list tag event - Return commands bound to event in tag

    switch -- [llength $args] {
	0 {
	    variable db
	    # Return all known tags.
	    set res {}
	    foreach te [array names db] {
		lappend res [lindex $te 0]
	    }
	    return [lsort -uniq $res]
	}
	1 {
	    variable db
	    # Return all known events for a specific tag
	    set res {}
	    set tag [lindex $args 0]
	    foreach te [array names db [::list $tag *]] {
		lappend res [lindex $te 1]
	    }
	    if {![llength $res]} {
		return -code error "Tag \"$tag\" is not known"
	    }
	    return $res
	}
	2 {
	    variable db
	    variable tk
	    # Return all commands bound to a tag/event combination
	    if {![info exists db($args)]} {
		foreach {tag event} $args break
		return -code error "Tag/Event \"$tag\"/\"$event\" is not known"
	    }
	    set res {}
	    foreach t $db($args) {
		lappend res [lindex $tk($t) 2]
	    }
	    return $res
	}
	default {
	    return -code error "wrong#args: expected ?tag? ?event?"
	}
    }
}

# ### ### ### ######### ######### #########

proc ::uevent::watch::tag::add {pattern cmdprefix} {
    variable db
    variable tk
    variable ex

    set token [Place uevmt $pattern $cmdprefix new]
    if {!$new} { return $token }

    # Check if there are already bindings on tags matching the
    # specified pattern. If yes, we have to invoke the command for
    # them all.

    # Situation: Part of the application binds to events on the tag
    # before the system genrating these events on the tag is
    # present. Thus watching is adding at a time when bindings already
    # exist.

    upvar \#0 ::uevent::dt map

    foreach tag [array names map] {
	if {![string match $pattern $tag]} continue
	uplevel \#0 [linsert $cmdprefix end bound $tag]
    }

    return $token
}

proc ::uevent::watch::tag::remove {token} {
    variable db
    variable tk
    variable ex

    Remove $token
    return
}

proc ::uevent::watch::tag::Invoke {action tag} {
    variable db
    variable tk

    foreach pattern [array names db] {
	if {![string match $pattern $tag]} continue

	foreach token $db($pattern) {
	    set cmd [lindex $tk($token) end]
	    uplevel \#0 [linsert $cmd end $action $tag]
	}
    }
    return
}

# ### ### ### ######### ######### #########

proc ::uevent::watch::event::add {tpattern epattern cmdprefix} {
    set key [list $tpattern $epattern]

    variable db
    variable tk
    variable ex

    set token [Place uevme $key $cmdprefix new]
    if {!$new} { return $token }

    # Check if there are already bindings on tag/event combinations
    # matching the specified pattern. If yes, we have to invoke the
    # command for them all.

    # Situation: Part of the application binds to events on the tag
    # before the system genrating these events on the tag is
    # present. Thus watching is adding at a time when bindings already
    # exist.

    upvar \#0 ::uevent::db map

    foreach key [array names map] {
	foreach {tag event} $key break
	if {![string match $tpattern $tag]}   continue
	if {![string match $epattern $event]} continue
	uplevel \#0 [linsert $cmdprefix end bound $tag $event]
    }

    return $token
}

proc ::uevent::watch::event::remove {token} {
    variable db
    variable tk
    variable ex

    Remove $token
    return
}

proc ::uevent::watch::event::Invoke {action tag event} {
    variable db
    variable tk

    foreach key [array names db] {
	foreach {tpattern epattern} $key break
	if {![string match $tpattern $tag]} continue
	if {![string match $epattern $event]} continue

	foreach token $db($key) {
	    set cmd [lindex $tk($token) end]
	    uplevel \#0 [linsert $cmd end $action $tag $event]
	}
    }
    return
}

# ### ### ### ######### ######### #########
## Initialization - Tracing, System state

logger::initNamespace ::uevent
namespace eval        ::uevent {
    # ### ### ### ######### ######### #########
    # Information needed:
    # (1)  Per <tag,event> the commands bound to it.
    # (1a) Per <tag>      the commands bound to it.
    # (2)  Per <tag,event,command> a token representing it.
    # (3)  For all <tag,event,command> a quick way to check their existence

    # (Ad 1)  db : array (list (tag, event) -> list (token))
    # (Ad 1a) dt : array (tag               -> list (token))
    # (Ad 2)  tk : array (token -> list (tag, event, command))
    # (Ad 3)  ex : array (list (tag, event, command) -> token)

    variable db ; array set db {}
    variable dt ; array set dt {}
    variable tk ; array set tk {}
    variable ex ; array set ex {}

    # (1a) is for bind watching.

    # ### ### ### ######### ######### #########

    namespace export bind unbind generate list
}

# ### ### ### ######### ######### #########
namespace eval ::uevent::watch::tag {
    # ### ### ### ######### ######### #########
    # Information needed for (un)bind monitoring (tags).

    # (1) Per <tag> (patterns) the commands bound to it.
    # (2) Per <tag,command> a token representing it.
    # (3) For all <tag,command> a quick way to check their existence

    # (Ad 1) db : array (tagp -> list (token))
    # (Ad 2) tk : array (token -> list (tagp, command))
    # (Ad 3) ex : array (list (tagp, command) -> token)

    variable db ; array set db {}
    variable tk ; array set tk {}
    variable ex ; array set ex {}

    namespace export add remove
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
namespace eval ::uevent::watch::event {
    # ### ### ### ######### ######### #########
    # Information needed for (un)bind monitoring (tag/events).

    # (1) Per <tag,event> (patterns) the commands bound to it.
    # (2) Per <<tag,event>,command> a token representing it.
    # (3) For all <<tag,event>,command> a quick way to check their existence

    # (Ad 1) db : array (list (tagp, eventp) -> list (token))
    # (Ad 2) tk : array (token -> list ((atgp, eventp), command))
    # (Ad 3) ex : array (list ((tagp, eventp), command) -> token)

    namespace export add remove
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Internals: Token Generator, and general DB management
## (same structure)

proc ::uevent::token::NewToken {{type uev}} {
    variable tcounter
    return ${type}[incr tcounter]
}

proc ::uevent::token::Place {type key command nv} {
    upvar 1 db db tk tk ex ex $nv new

    set kc [::list $key $command]

    # Same key/command combination as before => same token
    if {[info exists ex($kc)]} {
	set new 0
	return $ex($kc)
    }

    # New token, and enter everything ...
    set token [NewToken $type]

    set     tk($token) $kc
    set     ex($kc)    $token
    lappend db($key)   $token

    set new 1
    return $token
}

proc ::uevent::token::Remove {token} {
    upvar 1 db db tk tk ex ex

    if {![info exists tk($token)]} return

    set kc  $tk($token)
    set key [lindex $kc 0]

    unset ex($kc)
    unset tk($token)

    set pos [lsearch -exact $db($key) $token]
    if {$pos < 0} return

    if {[llength $db($key)] == 1} {
	unset db($key)
    } else {
	set db($key) [lreplace $db($key) $pos $pos]
    }
    return
}

namespace eval ::uevent::token {
    variable tcounter 0
    namespace export NewToken Place Remove
}

# ### ### ### ######### ######### #########
## Link general internal parts to their users.

namespace eval ::uevent {
    namespace import ::uevent::token::*
}

namespace eval ::uevent::watch::tag {
    namespace import ::uevent::token::*
}

namespace eval ::uevent::watch::event {
    namespace import ::uevent::token::*
}

# ### ### ### ######### ######### #########
## Ensemblify the system when running under Tcl 8.5 or higher.

if {[package vsatisfies [package present Tcl] 8.5]} {
    namespace eval ::uevent {
	namespace eval watch {
	    namespace eval tag {
		namespace ensemble create
	    }
	    namespace eval event {
		namespace ensemble create
	    }
	    namespace export tag event
	    namespace ensemble create
	}
	namespace export watch
	namespace ensemble create
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide uevent 0.3.1

##
# ### ### ### ######### ######### #########
