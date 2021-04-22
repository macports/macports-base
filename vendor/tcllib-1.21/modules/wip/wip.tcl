# ### ### ### ######### ######### #########
##
# (c) 2008-2009 Andreas Kupries.

# WIP = Word Interpreter (Also a Work In Progress :). Especially while
# it is running :P

# Micro interpreter for lists of words. Domain specific languages
# based on this will have a bit of a Forth feel, with the input stream
# segmented into words and any other structuring left to whatever
# language. Note that we have here in essence only the core dispatch
# loop, and no actual commands whatsoever, making this definitely only
# a Forth feel and not an actual Forth.

# The idea is derived from Colin McCormack's treeql processor,
# modified to require less boiler plate within the command
# implementations, at the expense of, likely, execution speed. In
# addition the interface between processor core and commands is more
# complex too.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4

# For Tcl 8.{3,4} only snit1 of a suitable patchlevel is possible.
package require snit 1.3

# The run_next_* methods use set operations (x in set)
package require struct::set

# ### ### ### ######### ######### #########
## API & Implementation

snit::type ::wip {

    # ### ### ### ######### ######### #########
    ## API

    constructor           {e args}       {} ; # create processor

    # Defining commands and where they dispatch to.
    method def            {name {cp {}}} {} ; # Define a DSL command.
    method def/           {name arity {cp {}}} {} ; # Ditto, with explicit arity.
    method defl           {names}        {} ; # Def many, simple names (cp = name)
    method defd           {dict}         {} ; # s.a. name/cp dict
    method deflva         {args}         {} ; # s.a. defl, var arg form
    method defdva         {args}         {} ; # s.a. defd, var arg form

    method undefva        {args}         {} ; # Remove DSL commands from the map.
    method undefl         {names}        {} ; # Ditto, names given as list.

    # Execution of word lists.
    method runl           {alist}   {} ; # execute list of words
    method run            {args}    {} ; # ditto, words as varargs
    method run_next       {}        {} ; # run the next command in the input.
    method run_next_while {accept}  {} ; # s.a., while acceptable command
    method run_next_until {reject}  {} ; # s.a., until rejectable command
    method run_next_if    {accept}  {} ; # s.a., if acceptable command
    method run_next_ifnot {reject}  {} ; # s.a., if not rejectable command

    # Manipulation of the input word list.
    method peek           {}        {} ; # peek at next word in input
    method next           {}        {} ; # pull next word from input
    method insert         {at args} {} ; # insert words back into the input
    method push           {args}    {} ; # ditto, at == 0

    # ### ### ### ######### ######### #########
    ## Processor construction.

    constructor {e args} {
	if {$e eq ""} {
	    return -code error "No engine specified"
	}
	set engine $e
	$self unknown [mymethod ErrorForUnknown]
	$self Definitions $args
	return
    }

    method Definitions {alist} {
	# args = series of 'def name' and 'def name cp' statements.
	# The code to handle them is in essence a WIP too, just
	# hardcoded, as state machine.

	set state expect-def
	set n  {}
	set cp {}
	foreach a $alist {
	    if {$state eq "expect-def"} {
		if {$a ne "def"} {
		    return -code error "Expected \"def\", got \"$a\""
		}
		set state get-name
	    } elseif {$state eq "get-name"} {
		set name $a
		set state get-cp-or-def
	    } elseif {$state eq "get-cp-or-def"} {
		# This means that 'def' cannot be a command prefix for
		# DSL command.
		if {$a eq "def"} {
		    # Short definition, name only, completed.
		    $self def $name
		    # We already have the first word of the next
		    # definition here, name is coming up next.
		    set state get-name
		} else {
		    # Long definition, name + cp, completed.
		    $self def $name $a
		    # Must be followed by the next definition.
		    set state expect-def
		}
	    }
	}
	if {$state eq "get-cp-or-def"} {
	    # Had a short definition last, now complete.
	    $self def $name
	} elseif {$state eq "get-name"} {
	    # Incomplete definition at the end, bogus
	    return -code error "Incomplete definition at end, name missing."
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Processor state
    ## Handle of the object incoming commands are dispatched to.
    ## The currently active DSL code, i.e. word list.

    variable unknown {}      ; # command prefix invoked when
			       # encountering unknown command words.
    variable engine  {}      ; # command
    variable program {}      ; # list (string)
    variable arity -array {} ; # array (command name -> command arity)
    variable cmd   -array {} ; # array (command name -> method cmd prefix)

    # ### ### ### ######### ######### #########
    ## API: DSL definition

    ## DSL words map to method-prefixes, i.e. method names + fixed
    ## arguments. We store them with the engine already added in front
    ## to make them regular command prefixes. No 'mymethod' however,
    ## that works only in engine code itself, not form the outside.

    method def {name {mp {}}} {
	if {$mp eq {}} {
	    # Derive method-prefix from DSL word.
	    set mp [list $name]
	    set m  $name
	    set n 0

	} else {
	    # No need to check for an empty method-prefix. That cannot
	    # happen, as it is diverted, see above.

	    set m [lindex $mp 0]
	    set n [expr {[llength $mp]-1}]
	}

	# Get method arguments, check for problems.
	set a [$engine info args $m]
	if {[lindex $a end] eq "args"} {
	    return -code error "Unable to handle Tcl varargs"
	}

	# The arity of the command is number of required arguments,
	# with compensation for those already covered by the
	# method-prefix.

	set cmd($name)   [linsert $mp 0 $engine]
	set arity($name) [expr {[llength $a] - $n}]
	return
    }

    method def/ {name ay {mp {}}} {
	# Like def, except that the arity is specified
	# explicitly. This is for methods with a variable number of
	# arguments in their definition, possibly dependent on the
	# fixed parts of the prefix.

	if {$mp eq {}} {
	    # Derive method-prefix from DSL word.
	    set mp [list $name]
	    set m  $name

	} else {
	    # No need to check for an empty method-prefix. That cannot
	    # happen, as it is diverted, see above.

	    set m [lindex $mp 0]
	}

	# The arity of the command is specified by the caller.

	set cmd($name)   [linsert $mp 0 $engine]
	set arity($name) $ay
	return
    }

    method deflva {args}  { $self defl $args ; return }
    method defdva {args}  { $self defd $args ; return }
    method defl   {names} { foreach n $names { $self def $n } ; return }
    method defd   {dict}  {
	if {[llength $dict]%2==1} {
	    return -code error "Expected a dictionary, got \"$dict\""
	}
	foreach {name mp} $dict {
	    $self def $name $mp
	}
	return
    }

    method undefva {args} { $self undefl $args ; return }
    method undefl {names} {
	foreach name $names {
	    unset -nocomplain cmd($name)
	    unset -nocomplain arity($name)
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## API: DSL execution
    #
    ## Consider moving the core implementation into procs, to reduce
    ## call overhead

    method run {args} {
	return [$self runl $args]
    }

    method runl {alist} {
	# Note: We are saving the current program and restore it
	# afterwards, this handles the possibility that this is a
	# recursive call into the dispatcher.
	set saved $program
	set program $alist
	set r {}
	while {[llength $program]} {
	    set r [$self run_next]
	}
	set program $saved
	return $r
    }

    method run_next_while {accept} {
	set r {}
	while {[llength $program] && [struct::set contains $accept [$self peek]]} {
	    set r [$self run_next]
	}
	return $r
    }

    method run_next_until {reject} {
	set r {}
	while {[llength $program] && ![struct::set contains $reject [$self peek]]} {
	    set r [$self run_next]
	}
	return $r
    }

    method run_next_if {accept} {
	set r {}
	if {[llength $program] && [struct::set contains $accept [$self peek]]} {
	    set r [$self run_next]
	}
	return $r
    }

    method run_next_ifnot {reject} {
	set r {}
	if {[llength $program] && ![struct::set contains $reject [$self peek]]} {
	    set r [$self run_next]
	}
	return $r
    }

    method run_next {} {
	# The first word in the list is the current command. Determine
	# the number of its fixed arguments. This also checks command
	# validity in general.

	set c [lindex $program 0]
	if {![info exists arity($c)]} {
	    # Invoke the unknown handler
	    return [uplevel #0 [linsert $unknown end $c]]
	}

	set n $arity($c)
	set m $cmd($c)

	# Take the fixed arguments from the input as well.

	if {[llength $program] <= $n} {
	    return -code error -errorcode WIP \
		"Not enough arguments for command \"$c\""
	}

	set cargs [lrange $program 1 $n]
	incr n

	# Remove the command to dispatch, and its fixed arguments from
	# the program. This is done before the dispatch so that the
	# command has access to the true current state of the input.

	set program [lrange $program $n end]

	# Now run the command with its arguments. Commands needing
	# more than the declared fixed number of arguments are
	# responsible for reading them from input via the method
	# 'next' provided by the processor core.

	# Note: m already has the engine at the front, it was stored
	# that way, see 'def'.

	if {![llength $cargs]} {
	    return [eval $m]
	} else {
	    # Explanation: First linsert constructs 'linsert $m end {*}$cargs',
	    # which the inner eval transforms into '{*}$m {*}$cargs', which at
	    # last is run by the outer eval.
	    return [eval [eval [linsert $cargs 0 linsert $m end]]]
	}
    }

    # ### ### ### ######### ######### #########
    ## Input manipulation

    # Get next word from the input (shift)
    method next {} {
	set w       [lindex $program 0]
	set program [lrange $program 1 end]
	return $w
    }

    # Peek at the next word in the input
    method peek {} {
	return [lindex $program 0]
    }

    # Retrieve the whole current program
    method peekall {} {
	return $program
    }

    # Replace the current programm
    method replace {args} {
	set program $args
	return
    }
    method replacel {alist} {
	set program $alist
	return
    }

    # Insert words into the input stream.
    method insert {at args} {
	set program [eval [linsert $args 0 linsert $program $at]]
	return
    }
    method insertl {at alist} {
	set program [eval [linsert $alist 0 linsert $program $at]]
	return
    }

    # <=> insert 0
    method push {args} {
	set program [eval [linsert $args 0 linsert $program 0]]
	return
    }
    method pushl {alist} {
	set program [eval [linsert $alist 0 linsert $program 0]]
	return
    }

    # <=> insert end
    method add {args} {
	set program [eval [linsert $args 0 linsert $program end]]
	return
    }
    method addl {alist} {
	set program [eval [linsert $alist 0 linsert $program end]]
	return
    }

    # ### ### ### ######### ######### #########

    method unknown {cmdprefix} {
	set unknown $cmdprefix
	return
    }

    method ErrorForUnknown {word} {
	return -code error -errorcode WIP \
	    "Unknown command \"$word\""
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
##

# Macro to declare the method of a component as proc. We use this
# later to make access to a WIP processor simpler (no need to write
# the component reference on our own). And no, this is not the same as
# the standard delegation. Doing that simply replaces the component
# name in the call with '$self'. We remove the need to have this
# written in the call.

snit::macro wip::methodasproc {var method suffix} {
    proc $method$suffix {args} [string map [list @v@ $var @m@ $method] {
	upvar 1 {@v@} dst
	return [eval [linsert $args 0 $dst {@m@}]]
    }]
}

# ### ### ### ######### ######### #########
## Ready

# ### ### ### ######### ######### #########
##

# Macro to install most of the boilerplate needed to setup and use a
# WIP. The only thing left is to call the method 'wip_setup' in the
# constructor of the class using WIP. This macro allows the creation
# of multiple wip's, through custom suffices.

snit::macro wip::dsl {{suffix {}}} {
    if {$suffix ne ""} {set suffix _$suffix}

    # Instance state, wip processor used to run the language
    component mywip$suffix

    # Standard method to create the processor component. The user has
    # to manually add a call of this method to the constructor.

    method wip${suffix}_setup {} [string map [list @@ $suffix] {
	install {mywip@@} using ::wip "${selfns}::mywip@@" $self
    }]

    # Procedures for easy access to the processor methods, without
    # having to use self and wip. I.e. special delegation.

    foreach {p} {
	add	addl	def     undefva undefl
	defd	defdva	defl	deflva  def/
	insert	insertl	replace	replacel
	push	pushl	run	runl
	next	peek	peekall	run_next
	run_next_until	run_next_while
	run_next_ifnot	run_next_if
    } {
	wip::methodasproc mywip$suffix $p $suffix
    }
    return
}

# ### ### ### ######### ######### #########
## Ready

package provide wip 1.2
