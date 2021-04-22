# -*- tcl -*-
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>

# Support package. Basic text generation commands.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.4 ; # Required Core

namespace eval ::doctools::text {}

# # ## ### ##### ######## ############# #####################

proc ::doctools::text::begin {} {
    variable state
    array unset state *
    array set   state {
	stack     {}
	buffer    {}
	prefix    {}
	pstack    {}
	underl    {}
	break     0
	newlines  1
	indenting 1
    }
    return
}

proc ::doctools::text::done {} {
    variable state
    return $state(buffer)
}

proc ::doctools::text::save {} {
    variable state
    set current [array get state]
    begin
    set state(stack) $current
    return
}

proc ::doctools::text::restore {} {
    variable state
    set text [done]
    array set state $state(stack)
    return $text
}

proc ::doctools::text::collect {script} {
    save
    uplevel 1 $script
    return [restore]
}

# # ## ### ##### ######## ############# #####################

proc ::doctools::text::+ {text} {
    variable state
    if {$state(break)} {
	+++ [string repeat \n $state(break)]
	+++ $state(prefix)
	set state(break) 0
    }
    +++ $text
    set state(underl) [string length $text]
    return
}

proc ::doctools::text::underline {char} {
    variable state
    newline
    + [string repeat [string index $char 0] $state(underl)]
    newline
    return
}

proc ::doctools::text::+++ {text} {
    variable state
    append   state(buffer) $text
    return
}

# # ## ### ##### ######## ############# #####################

proc ::doctools::text::newline {{increment 1}} {
    variable state
    if {!$state(newlines)} { return 0 }
    incr state(break) $increment
    return 1
}

proc ::doctools::text::newline? {} {
    variable state
    if {!$state(newlines)} { return 0 }
    if {$state(break)} { return 1 }
    if {![string length $state(buffer)]} { return 1 }
    if {[string index   $state(buffer) end] eq "\n"} { return 1 }
    incr state(break)
    return 1
}

# # ## ### ##### ######## ############# #####################

proc ::doctools::text::prefix {text} {
    variable state
    if {!$state(indenting)} return
    set state(prefix) $text
    return
}

proc ::doctools::text::indent {{increment 2}} {
    variable state
    if {!$state(indenting)} return
    lappend state(pstack) $state(prefix)
    set     state(prefix) [string repeat { } $increment]$state(prefix)
    return
}

proc ::doctools::text::dedent {} {
    variable state
    if {!$state(indenting)} return
    set state(prefix) [lindex   $state(pstack) end]
    set state(pstack) [lreplace $state(pstack) end end]
    return
}

proc ::doctools::text::indented {increment script} {
    indent $increment
    uplevel 1 $script
    dedent
    return
}

# # ## ### ##### ######## ############# #####################

proc ::doctools::text::indenting {enable} {
    variable state
    set state(indenting) $enable
    return
}

proc ::doctools::text::newlines {enable} {
    variable state
    set state(newlines) $enable
    return
}

# # ## ### ##### ######## ############# #####################

proc ::doctools::text::field {wvar elements {index {}}} {
    upvar 1 $wvar width
    set width 0
    #puts @!$width
    if {$index ne {}} {
	foreach e $elements {
	    #puts stdout @/$e
	    set e [lindex $e $index]
	    #puts stdout @^$e
	    set l [string length $e]
	    if {$l <= $width} continue
	    set width $l
	}
    } else {
	foreach e $elements {
	    #puts stdout @/$e
	    set l [string length $e]
	    if {$l <= $width} continue
	    set width $l
	}
    }
    #puts stdout @=$width
    return
}

proc ::doctools::text::right {wvar str} {
    upvar $wvar width
    return [format %${width}s $str]
}

proc ::doctools::text::left {wvar str} {
    upvar $wvar width
    return [format %-${width}s $str]
}

# # ## ### ##### ######## ############# #####################

proc ::doctools::text::import {{namespace {}}} {
    uplevel 1 [list namespace eval ${namespace}::text {
	namespace import ::doctools::text::*
    }]
    return
}

proc ::doctools::text::importhere {{namespace ::}} {
    uplevel 1 [list namespace eval ${namespace} {
	namespace import ::doctools::text::*
    }]
    return
}

# # ## ### ##### ######## ############# #####################

namespace eval ::doctools::text {
    variable  state
    array set state {}

    namespace export begin done save restore collect + underline +++ \
	prefix indent dedent indented indenting newline newlines \
	field right left newline?
}

# # ## ### ##### ######## ############# #####################
package provide doctools::text 0.1
return
