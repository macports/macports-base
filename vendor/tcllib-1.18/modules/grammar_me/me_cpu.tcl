# -*- tcl -*-
# (C) 2005-2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
# ### ### ### ######### ######### #########
## Package description

## Implementation of ME virtual machines, object-based API to the
## state values provided by "grammar::me::cpu::core".

# ### ### ### ######### ######### #########
## Requisites

package require snit
package require grammar::me::cpu::core

# ### ### ### ######### ######### #########
## Implementation

snit::type ::grammar::me::cpu {
    constructor {code_} {
	# The 'core new' call validates the code as well.

	set state [core::new $code_]
	return
    }

    method lc     {location}     {return [core::lc     $state $location]}
    method tok    {args}         {return [eval [linsert $args 0 core::tok $state]]}
    method pc     {}             {return [core::pc     $state]}
    method iseof  {}             {return [core::iseof  $state]}
    method at     {}             {return [core::at     $state]}
    method cc     {}             {return [core::cc     $state]}
    method sv     {}             {return [core::sv     $state]}
    method ok     {}             {return [core::ok     $state]}
    method error  {}             {return [core::error  $state]}
    method lstk   {}             {return [core::lstk   $state]}
    method astk   {}             {return [core::astk   $state]}
    method mstk   {}             {return [core::mstk   $state]}
    method estk   {}             {return [core::estk   $state]}
    method rstk   {}             {return [core::rstk   $state]}
    method nc     {}             {return [core::nc     $state]}
    method ast    {}             {return [core::ast    $state]}
    method halted {}             {return [core::halted $state]}
    method code   {}             {return [core::code   $state]}

    method eof {} {
	core::eof state
	return
    }

    method put {tok lex line col} {
	core::put state $tok $lex $line $col
	return
    }

    method putstring {str lvar cvar} {
	upvar 1 $lvar line $cvar col
	foreach ch [split $str {}] {
	    core::put state $ch {} $line $col
	    if {$ch eq "\n"} {
		incr line
		set  col 0
	    } else {
		incr col
	    }
	}
	return
    }

    method run {{n -1}} {
	core::run state $n
	return
    }

    method pull {next} {
	while {1} {
	    core::run state
	    if {[core::halted $state]} break

	    set tokdata [uplevel \#0 $next]
	    if {![llength $tokdata]} break
	    if {[llength $tokdata] != 4} {
		return -code error "Bad callback result, expected 4 elements"
	    }
	    foreach {tok lex line col} $tokdata break
	    core::put state $tok $lex $line $col
	}
    }

    method reset {} {
	set state [core::new [core::code $state]]
	return
    }

    # ### ### ### ######### ######### #########
    ## Data structures

    variable state ; # State of ME cpu handled here.
}

# ### ### ### ######### ######### #########
## Ready

package provide grammar::me::cpu 0.2
