#---------------------------------------------------------------------
# TITLE:
#	expander.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#
# An expander is an object that takes as input text with embedded
# Tcl code and returns text with the embedded code expanded.  The
# text can be provided all at once or incrementally.
#
# See  expander.[e]html for usage info.
# Also expander.n
#
# LICENSE:
#       Copyright (C) 2001 by William H. Duquette.  See expander_license.txt,
#       distributed with this file, for license information.
#
# CHANGE LOG:
#
#       10/31/01: V0.9 code is complete.
#       11/23/01: Added "evalcmd"; V1.0 code is complete.

# Provide the package.

# Create the package's namespace.

namespace eval ::textutil {
    namespace eval expander {
	# All indices are prefixed by "$exp-".
	#
	# lb		    The left bracket sequence
	# rb		    The right bracket sequence
	# errmode	    How to handle macro errors: 
	#		    nothing, macro, error, fail.
        # evalcmd           The evaluation command.
	# textcmd           The plain text processing command.
	# level		    The context level
	# output-$level     The accumulated text at this context level.
	# name-$level       The tag name of this context level
	# data-$level-$var  A variable of this context level     
	
	variable Info
    
	# In methods, the current object:
	variable This ""
	
	# Export public commands
	namespace export expander
    }

    #namespace import expander::*
    namespace export expander

    proc expander {name} {uplevel ::textutil::expander::expander [list $name]}
}

#---------------------------------------------------------------------
# FUNCTION:
# 	expander name
#
# INPUTS:
#	name		A proc name for the new object.  If not
#                       fully-qualified, it is assumed to be relative
#                       to the caller's namespace.
#
# RETURNS:
#	nothing
#
# DESCRIPTION:
#	Creates a new expander object.

proc ::textutil::expander::expander {name} {
    variable Info

    # FIRST, qualify the name.
    if {![string match "::*" $name]} {
        # Get caller's namespace; append :: if not global namespace.
        set ns [uplevel 1 namespace current]
        if {"::" != $ns} {
            append ns "::"
        }
        
        set name "$ns$name"
    }

    # NEXT, Check the name
    if {"" != [info commands $name]} {
        return -code error "command name \"$name\" already exists"
    }

    # NEXT, Create the object.
    proc $name {method args} [format {
        if {[catch {::textutil::expander::Methods %s $method $args} result]} {
            return -code error $result
        } else {
            return $result
        }
    } $name]

    # NEXT, Initialize the object
    Op_reset $name
    
    return $name
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Methods name method argList
#
# INPUTS:
#	name		The object's fully qualified procedure name.
#			This argument is provided by the object command
#			itself.
#	method		The method to call.
#	argList		Arguments for the specific method.
#
# RETURNS:
#	Depends on the method
#
# DESCRIPTION:
#	Handles all method dispatch for a expander object.
#       The expander's object command merely passes its arguments to
#	this function, which dispatches the arguments to the
#	appropriate method procedure.  If the method raises an error,
#	the method procedure's name in the error message is replaced
#	by the object and method names.

proc ::textutil::expander::Methods {name method argList} {
    variable Info
    variable This

    switch -exact -- $method {
        expand -
        lb -
        rb -
        setbrackets -
        errmode -
        evalcmd -
	textcmd -
        cpush -
	ctopandclear -
        cis -
        cname -
        cset -
        cget -
        cvar -
        cpop -
        cappend -
	where -
        reset {
            # FIRST, execute the method, first setting This to the object
            # name; then, after the method has been called, restore the
            # old object name.
            set oldThis $This
            set This $name

            set retval [catch "Op_$method $name $argList" result]

            set This $oldThis

            # NEXT, handle the result based on the retval.
            if {$retval} {
                regsub -- "Op_$method" $result "$name $method" result
                return -code error $result
            } else {
                return $result
            }
        }
        default {
            return -code error "\"$name $method\" is not defined"
        }
    }
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Get key
#
# INPUTS:
#	key		A key into the Info array, excluding the
#	                object name.  E.g., "lb"
#
# RETURNS:
#	The value from the array
#
# DESCRIPTION:
#	Gets the value of an entry from Info for This.

proc ::textutil::expander::Get {key} {
    variable Info
    variable This

    return $Info($This-$key)
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Set key value
#
# INPUTS:
#	key		A key into the Info array, excluding the
#	                object name.  E.g., "lb"
#
#	value		A Tcl value
#
# RETURNS:
#	The value
#
# DESCRIPTION:
#	Sets the value of an entry in Info for This.

proc ::textutil::expander::Set {key value} {
    variable Info
    variable This

    return [set Info($This-$key) $value]
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Var key
#
# INPUTS:
#	key		A key into the Info array, excluding the
#	                object name.  E.g., "lb"
#
# RETURNS:
#	The full variable name, suitable for setting or lappending

proc ::textutil::expander::Var {key} {
    variable Info
    variable This

    return ::textutil::expander::Info($This-$key)
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Contains list value
#
# INPUTS:
#       list		any list
#	value		any value
#
# RETURNS:
#	TRUE if the list contains the value, and false otherwise.

proc ::textutil::expander::Contains {list value} {
    if {[lsearch -exact $list $value] == -1} {
        return 0
    } else {
        return 1
    }
}


#---------------------------------------------------------------------
# FUNCTION:
# 	Op_lb ?newbracket?
#
# INPUTS:
#	newbracket		If given, the new bracket token.
#
# RETURNS:
#	The current left bracket
#
# DESCRIPTION:
#	Returns the current left bracket token.

proc ::textutil::expander::Op_lb {name {newbracket ""}} {
    if {[string length $newbracket] != 0} {
        Set lb $newbracket
    }
    return [Get lb]
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_rb ?newbracket?
#
# INPUTS:
#	newbracket		If given, the new bracket token.
#
# RETURNS:
#	The current left bracket
#
# DESCRIPTION:
#	Returns the current left bracket token.

proc ::textutil::expander::Op_rb {name {newbracket ""}} {
    if {[string length $newbracket] != 0} {
        Set rb $newbracket
    }
    return [Get rb]
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_setbrackets lbrack rbrack
#
# INPUTS:
#	lbrack		The new left bracket
#	rbrack		The new right bracket
#
# RETURNS:
#	nothing
#
# DESCRIPTION:
#	Sets the brackets as a pair.

proc ::textutil::expander::Op_setbrackets {name lbrack rbrack} {
    Set lb $lbrack
    Set rb $rbrack
    return
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_errmode ?newErrmode?
#
# INPUTS:
#	newErrmode		If given, the new error mode.
#
# RETURNS:
#	The current error mode
#
# DESCRIPTION:
#	Returns the current error mode.

proc ::textutil::expander::Op_errmode {name {newErrmode ""}} {
    if {[string length $newErrmode] != 0} {
        if {![Contains "macro nothing error fail" $newErrmode]} {
            error "$name errmode: Invalid error mode: $newErrmode"
        }

        Set errmode $newErrmode
    }
    return [Get errmode]
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_evalcmd ?newEvalCmd?
#
# INPUTS:
#	newEvalCmd		If given, the new eval command.
#
# RETURNS:
#	The current eval command
#
# DESCRIPTION:
#	Returns the current eval command.  This is the command used to
#	evaluate macros; it defaults to "uplevel #0".

proc ::textutil::expander::Op_evalcmd {name {newEvalCmd ""}} {
    if {[string length $newEvalCmd] != 0} {
        Set evalcmd $newEvalCmd
    }
    return [Get evalcmd]
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_textcmd ?newTextCmd?
#
# INPUTS:
#	newTextCmd		If given, the new text command.
#
# RETURNS:
#	The current text command
#
# DESCRIPTION:
#	Returns the current text command.  This is the command used to
#	process plain text. It defaults to {}, meaning identity.

proc ::textutil::expander::Op_textcmd {name args} {
    switch -exact [llength $args] {
	0 {}
	1 {Set textcmd [lindex $args 0]}
	default {
	    return -code error "wrong#args for textcmd: name ?newTextcmd?"
	}
    }
    return [Get textcmd]
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_reset
#
# INPUTS:
#	none
#
# RETURNS:
#	nothing
#
# DESCRIPTION:
#	Resets all object values, as though it were brand new.

proc ::textutil::expander::Op_reset {name} {
    variable Info 

    if {[info exists Info($name-lb)]} {
        foreach elt [array names Info "$name-*"] {
            unset Info($elt)
        }
    }

    set Info($name-lb) "\["
    set Info($name-rb) "\]"
    set Info($name-errmode) "fail"
    set Info($name-evalcmd) "uplevel #0"
    set Info($name-textcmd) ""
    set Info($name-level) 0
    set Info($name-output-0) ""
    set Info($name-name-0) ":0"

    return
}

#-------------------------------------------------------------------------
# Context: Every expansion takes place in its own context; however, 
# a macro can push a new context, causing the text it returns and all
# subsequent text to be saved separately.  Later, a matching macro can
# pop the context, acquiring all text saved since the first command,
# and use that in its own output.

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_cpush cname
#
# INPUTS:
#	cname		The context name
#
# RETURNS:
#	nothing
#
# DESCRIPTION:
#       Pushes an empty macro context onto the stack.  All expanded text
#       will be added to this context until it is popped.

proc ::textutil::expander::Op_cpush {name cname} {
    # FRINK: nocheck
    incr [Var level]
    # FRINK: nocheck
    set [Var output-[Get level]] {}
    # FRINK: nocheck
    set [Var name-[Get level]] $cname

    # The first level is init'd elsewhere (Op_expand)
    if {[set [Var level]] < 2} return

    # Initialize the location information, inherit from the outer
    # context.

    LocInit $cname
    catch {LocSet $cname [LocGet $name]}
    return    
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_cis cname
#
# INPUTS:
#	cname		A context name
#
# RETURNS:
#	true or false
#
# DESCRIPTION:
#       Returns true if the current context has the specified name, and
#	false otherwise.

proc ::textutil::expander::Op_cis {name cname} {
    return [expr {[string compare $cname [Op_cname $name]] == 0}]
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_cname
#
# INPUTS:
#	none
#
# RETURNS:
#	The context name
#
# DESCRIPTION:
#       Returns the name of the current context.

proc ::textutil::expander::Op_cname {name} {
    return [Get name-[Get level]]
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_cset varname value
#
# INPUTS:
#	varname		The name of a context variable
#	value		The new value for the context variable
#
# RETURNS:
#	The value
#
# DESCRIPTION:
#       Sets a variable in the current context.

proc ::textutil::expander::Op_cset {name varname value} {
    Set data-[Get level]-$varname $value
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_cget varname
#
# INPUTS:
#	varname		The name of a context variable
#
# RETURNS:
#	The value
#
# DESCRIPTION:
#       Returns the value of a context variable.  It's an error if
#	the variable doesn't exist.

proc ::textutil::expander::Op_cget {name varname} {
    if {![info exists [Var data-[Get level]-$varname]]} {
        error "$name cget: $varname doesn't exist in this context ([Get level])"
    }
    return [Get data-[Get level]-$varname]
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_cvar varname
#
# INPUTS:
#	varname		The name of a context variable
#
# RETURNS:
#	The index to the variable
#
# DESCRIPTION:
#       Returns the index to a context variable, for use with set, 
#	lappend, etc.

proc ::textutil::expander::Op_cvar {name varname} {
    if {![info exists [Var data-[Get level]-$varname]]} {
        error "$name cvar: $varname doesn't exist in this context"
    }

    return [Var data-[Get level]-$varname]
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_cpop cname
#
# INPUTS:
#	cname		The expected context name.
#
# RETURNS:
#	The accumulated output in this context
#
# DESCRIPTION:
#       Returns the accumulated output for the current context, first
#	popping the context from the stack.  The expected context name
#	must match the real name, or an error occurs.

proc ::textutil::expander::Op_cpop {name cname} {
    variable Info

    if {[Get level] == 0} {
        error "$name cpop underflow on '$cname'"
    }

    if {[string compare [Op_cname $name] $cname] != 0} {
        error "$name cpop context mismatch: expected [Op_cname $name], got $cname"
    }

    set result [Get output-[Get level]]
    # FRINK: nocheck
    set [Var output-[Get level]] ""
    # FRINK: nocheck
    set [Var name-[Get level]] ""

    foreach elt [array names "Info data-[Get level]-*"] {
        unset Info($elt)
    }

    # FRINK: nocheck
    incr [Var level] -1
    return $result
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_ctopandclear
#
# INPUTS:
#	None.
#
# RETURNS:
#	The accumulated output in the topmost context, clears the context,
#	but does not pop it.
#
# DESCRIPTION:
#       Returns the accumulated output for the current context, first
#	popping the context from the stack.  The expected context name
#	must match the real name, or an error occurs.

proc ::textutil::expander::Op_ctopandclear {name} {
    variable Info

    if {[Get level] == 0} {
        error "$name cpop underflow on '[Op_cname $name]'"
    }

    set result [Get output-[Get level]]
    Set output-[Get level] ""
    return $result
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_cappend text
#
# INPUTS:
#	text		Text to add to the output
#
# RETURNS:
#	The accumulated output
#
# DESCRIPTION:
#       Appends the text to the accumulated output in the current context.

proc ::textutil::expander::Op_cappend {name text} {
    # FRINK: nocheck
    append [Var output-[Get level]] $text
}

#-------------------------------------------------------------------------
# Macro-expansion:  The following code is the heart of the module.
# Given a text string, and the current variable settings, this code
# returns an expanded string, with all macros replaced.

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_expand inputString ?brackets?
#
# INPUTS:
#	inputString		The text to expand.
#	brackets		A list of two bracket tokens.
#
# RETURNS:
#	The expanded text.
#
# DESCRIPTION:
#	Finds all embedded macros in the input string, and expands them.
#	If ?brackets? is given, it must be list of length 2, containing
#	replacement left and right macro brackets; otherwise the default
#	brackets are used.

proc ::textutil::expander::Op_expand {name inputString {brackets ""}} {
    # FIRST, push a new context onto the stack, and save the current
    # brackets.

    Op_cpush $name expand
    Op_cset $name lb [Get lb]
    Op_cset $name rb [Get rb]

    # Keep position information in context variables as well.
    # Line we are in, counting from 1; column we are at,
    # counting from 0, and index of character we are at,
    # counting from 0. Tabs counts as '1' when computing
    # the column.

    LocInit $name

    # SF Tcllib Bug #530056.
    set start_level [Get level] ; # remember this for check at end

    # NEXT, use the user's brackets, if given.
    if {[llength $brackets] == 2} {
        Set lb [lindex $brackets 0]
        Set rb [lindex $brackets 1]
    }

    # NEXT, loop over the string, finding and expanding macros.
    while {[string length $inputString] > 0} {
        set plainText [ExtractToToken inputString [Get lb] exclude]

        # FIRST, If there was plain text, append it to the output, and 
        # continue.
        if {$plainText != ""} {
	    set input $plainText
	    set tc [Get textcmd]
	    if {[string length $tc] > 0} {
		lappend tc $plainText

		if {![catch "[Get evalcmd] [list $tc]" result]} {
		    set plainText $result
		} else {
		    HandleError $name {plain text} $tc $result
		}
	    }
            Op_cappend $name $plainText
	    LocUpdate  $name $input

            if {[string length $inputString] == 0} {
                break
            }
        }

        # NEXT, A macro is the next thing; process it.
        if {[catch {GetMacro inputString} macro]} {
	    # SF tcllib bug 781973 ... Do not throw a regular
	    # error. Use HandleError to give the user control of the
	    # situation, via the defined error mode. The continue
	    # intercepts if the user allows the expansion to run on,
	    # yet we must not try to run the non-existing macro.

	    HandleError $name {reading macro} $inputString $macro
	    continue
        }

        # Expand the macro, and output the result, or
        # handle an error.
        if {![catch "[Get evalcmd] [list $macro]" result]} {
            Op_cappend $name $result 

	    # We have to advance the location by the length of the
	    # macro, plus the two brackets. They were stripped by
	    # GetMacro, so we have to add them here again to make
	    # computation correct.

	    LocUpdate $name [Get lb]${macro}[Get rb]
            continue
        } 

	HandleError $name macro $macro $result
    }

    # SF Tcllib Bug #530056.
    if {[Get level] > $start_level} {
	# The user macros pushed additional contexts, but forgot to
	# pop them all. The main work here is to place all the still
	# open contexts into the error message, and to produce
	# syntactically correct english.

	set c [list]
	set n [expr {[Get level] - $start_level}]
	if {$n == 1} {
	    set ctx  context
	    set verb was
	} else {
	    set ctx  contexts
	    set verb were
	}
	for {incr n -1} {$n >= 0} {incr n -1} {
	    lappend c [Get name-[expr {[Get level]-$n}]]
	}
	return -code error \
		"The following $ctx pushed by the macros $verb not popped: [join $c ,]."
    } elseif {[Get level] < $start_level} {
	set n [expr {$start_level - [Get level]}]
	if {$n == 1} {
	    set ctx  context
	} else {
	    set ctx  contexts
	}
	return -code error \
		"The macros popped $n more $ctx than they had pushed."
    }

    Op_lb $name [Op_cget $name lb]
    Op_rb $name [Op_cget $name rb]

    return [Op_cpop $name expand]
}

#---------------------------------------------------------------------
# FUNCTION:
# 	Op_where
#
# INPUTS:
#	None.
#
# RETURNS:
#	The current location in the input.
#
# DESCRIPTION:
#	Retrieves the current location the expander
#	is at during processing.

proc ::textutil::expander::Op_where {name} {
    return [LocGet $name]
}

#---------------------------------------------------------------------
# FUNCTION
#	HandleError name title command errmsg
#
# INPUTS:
#	name		The name of the expander object in question.
#	title		A title text
#	command		The command which caused the error.
#	errmsg		The error message to report
#
# RETURNS:
#	Nothing
#
# DESCRIPTIONS
#	Is executed when an error in a macro or the plain text handler
#	occurs. Generates an error message according to the current
#	error mode.

proc ::textutil::expander::HandleError {name title command errmsg} {
    switch [Get errmode] {
	nothing { }
	macro {
	    # The location is irrelevant here.
	    Op_cappend $name "[Get lb]$command[Get rb]" 
	}
	error {
	    foreach {ch line col} [LocGet $name] break
	    set display [DisplayOf $command]

	    Op_cappend $name "\n=================================\n"
	    Op_cappend $name "*** Error in $title at line $line, column $col:\n"
	    Op_cappend $name "*** [Get lb]$display[Get rb]\n--> $errmsg\n"
	    Op_cappend $name "=================================\n"
	}
	fail   { 
	    foreach {ch line col} [LocGet $name] break
	    set display [DisplayOf $command]

	    return -code error "Error in $title at line $line,\
		    column $col:\n[Get lb]$display[Get rb]\n-->\
		    $errmsg"
	}
	default {
	    return -code error "Unknown error mode: [Get errmode]"
	}
    }
}

#---------------------------------------------------------------------
# FUNCTION:
# 	ExtractToToken string token mode
#
# INPUTS:
#	string		The text to process.
#	token		The token to look for
#	mode		include or exclude
#
# RETURNS:
#	The extracted text
#
# DESCRIPTION:
# 	Extract text from a string, up to or including a particular
# 	token.  Remove the extracted text from the string.
# 	mode determines whether the found token is removed;
# 	it should be "include" or "exclude".  The string is
# 	modified in place, and the extracted text is returned.

proc ::textutil::expander::ExtractToToken {string token mode} {
    upvar $string theString

    # First, determine the offset
    switch $mode {
        include { set offset [expr {[string length $token] - 1}] }
        exclude { set offset -1 }
        default { error "::expander::ExtractToToken: unknown mode $mode" }
    }

    # Next, find the first occurrence of the token.
    set tokenPos [string first $token $theString]

    # Next, return the entire string if it wasn't found, or just
    # the part upto or including the character.
    if {$tokenPos == -1} {
        set theText $theString
        set theString ""
    } else {
        set newEnd    [expr {$tokenPos + $offset}]
        set newBegin  [expr {$newEnd + 1}]
        set theText   [string range $theString 0 $newEnd]
        set theString [string range $theString $newBegin end]
    }

    return $theText
}

#---------------------------------------------------------------------
# FUNCTION:
# 	GetMacro string
#
# INPUTS:
#	string		The text to process.
#
# RETURNS:
#	The macro, stripped of its brackets.
#
# DESCRIPTION:

proc ::textutil::expander::GetMacro {string} {
    upvar $string theString

    # FIRST, it's an error if the string doesn't begin with a
    # bracket.
    if {[string first [Get lb] $theString] != 0} {
        error "::expander::GetMacro: assertion failure, next text isn't a command! '$theString'"
    }

    # NEXT, extract a full macro
    set macro [ExtractToToken theString [Get lb] include]
    while {[string length $theString] > 0} {
        append macro [ExtractToToken theString [Get rb] include]

        # Verify that the command really ends with the [rb] characters,
        # whatever they are.  If not, break because of unexpected
        # end of file.
        if {![IsBracketed $macro]} {
            break;
        }

        set strippedMacro [StripBrackets $macro]

        if {[info complete "puts \[$strippedMacro\]"]} {
            return $strippedMacro
        }
    }

    if {[string length $macro] > 40} {
        set macro "[string range $macro 0 39]...\n"
    }
    error "Unexpected EOF in macro:\n$macro"
}

# Strip left and right bracket tokens from the ends of a macro,
# provided that it's properly bracketed.
proc ::textutil::expander::StripBrackets {macro} {
    set llen [string length [Get lb]]
    set rlen [string length [Get rb]]
    set tlen [string length $macro]

    return [string range $macro $llen [expr {$tlen - $rlen - 1}]]
}

# Return 1 if the macro is properly bracketed, and 0 otherwise.
proc ::textutil::expander::IsBracketed {macro} {
    set llen [string length [Get lb]]
    set rlen [string length [Get rb]]
    set tlen [string length $macro]

    set leftEnd  [string range $macro 0       [expr {$llen - 1}]]
    set rightEnd [string range $macro [expr {$tlen - $rlen}] end]

    if {$leftEnd != [Get lb]} {
        return 0
    } elseif {$rightEnd != [Get rb]} {
        return 0
    } else {
        return 1
    }
}

#---------------------------------------------------------------------
# FUNCTION:
# 	LocInit name
#
# INPUTS:
#	name		The expander object to use.
#
# RETURNS:
#	No result.
#
# DESCRIPTION:
#	A convenience wrapper around LocSet. Initializes the location
#	to the start of the input (char 0, line 1, column 0).

proc ::textutil::expander::LocInit {name} {
    LocSet $name {0 1 0}
    return
}

#---------------------------------------------------------------------
# FUNCTION:
# 	LocSet name loc
#
# INPUTS:
#	name		The expander object to use.
#	loc		Location, list containing character position,
#			line number and column, in this order.
#
# RETURNS:
#	No result.
#
# DESCRIPTION:
#	Sets the current location in the expander to 'loc'.

proc ::textutil::expander::LocSet {name loc} {
    foreach {ch line col} $loc break
    Op_cset  $name char $ch
    Op_cset  $name line $line
    Op_cset  $name col  $col
    return
}

#---------------------------------------------------------------------
# FUNCTION:
# 	LocGet name
#
# INPUTS:
#	name		The expander object to use.
#
# RETURNS:
#	A list containing the current character position, line number
#	and column, in this order.
#
# DESCRIPTION:
#	Returns the current location as stored in the expander.

proc ::textutil::expander::LocGet {name} {
    list [Op_cget $name char] [Op_cget $name line] [Op_cget $name col]
}

#---------------------------------------------------------------------
# FUNCTION:
# 	LocUpdate name text
#
# INPUTS:
#	name		The expander object to use.
#	text		The text to process.
#
# RETURNS:
#	No result.
#
# DESCRIPTION:
#	Takes the current location as stored in the expander, computes
#	a new location based on the string (its length and contents
#	(number of lines)), and makes that new location the current
#	location.

proc ::textutil::expander::LocUpdate {name text} {
    foreach {ch line col} [LocGet $name] break
    set numchars [string length $text]
    #8.4+ set numlines [regexp -all "\n" $text]
    set numlines [expr {[llength [split $text \n]]-1}]

    incr ch   $numchars
    incr line $numlines
    if {$numlines} {
	set col [expr {$numchars - [string last \n $text] - 1}]
    } else {
	incr col $numchars
    }

    LocSet $name [list $ch $line $col]
    return
}

#---------------------------------------------------------------------
# FUNCTION:
# 	LocRange name text
#
# INPUTS:
#	name		The expander object to use.
#	text		The text to process.
#
# RETURNS:
#	A text range description, compatible with the 'location' data
#	used in the tcl debugger/checker.
#
# DESCRIPTION:
#	Takes the current location as stored in the expander object
#	and the length of the text to generate a character range.

proc ::textutil::expander::LocRange {name text} {
    # Note that the structure is compatible with
    # the ranges uses by tcl debugger and checker.
    # {line {charpos length}}

    foreach {ch line col} [LocGet $name] break
    return [list $line [list $ch [string length $text]]]
}

#---------------------------------------------------------------------
# FUNCTION:
# 	DisplayOf text
#
# INPUTS:
#	text		The text to process.
#
# RETURNS:
#	The text, cut down to at most 30 bytes.
#
# DESCRIPTION:
#	Cuts the incoming text down to contain no more than 30
#	characters of the input. Adds an ellipsis (...) if characters
#	were actually removed from the input.

proc ::textutil::expander::DisplayOf {text} {
    set ellip ""
    while {[string bytelength $text] > 30} {
	set ellip ...
	set text [string range $text 0 end-1]
    }
    set display $text$ellip
}

#---------------------------------------------------------------------
# Provide the package only if the code above was read and executed
# without error.

package provide textutil::expander 1.3.1
