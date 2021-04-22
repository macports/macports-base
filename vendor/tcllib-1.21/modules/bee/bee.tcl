# bee.tcl --
#
#	BitTorrent Bee de- and encoder.
#
# Copyright (c) 2004 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# See the file license.terms.

package require Tcl 8.4

namespace eval ::bee {
    # Encoder commands
    namespace export \
	    encodeString encodeNumber \
	    encodeListArgs encodeList \
	    encodeDictArgs encodeDict

    # Decoder commands.
    namespace export \
	    decode \
	    decodeChannel \
	    decodeCancel \
	    decodePush

    # Channel decoders, reference to state information, keyed by
    # channel handle.

    variable  bee
    array set bee {}

    # Counter for generation of names for the state variables.

    variable count 0

    # State information for the channel decoders.

    # stateN, with N an integer number counting from 0 on up.
    # ...(chan)   Handle of channel the decoder is for.
    # ...(cmd)    Command prefix, completion callback
    # ...(exact)  Boolean flag, set for exact processing.
    # ...(read)   Buffer for new characters to process.
    # ...(type)   Type of current value (integer, string, list, dict)
    # ...(value)  Buffer for assembling the current value.
    # ...(pend)   Stack of pending 'value' buffers, for nested
    #             containers.
    # ...(state)  Current state of the decoding state machine.

    # States of the finite automaton ...
    # intro  - One char, type of value, or 'e' as stop of container.
    # signum - sign or digit, for integer.
    # idigit - digit, for integer, or 'e' as stop
    # ldigit - digit, for length of string, or :
    # data   - string data, 'get' characters.
    # Containers via 'pend'.

    #Debugging help, nesting level
    #variable X 0
}


# ::bee::encodeString --
#
#	Encode a string to bee-format.
#
# Arguments:
#	string	The string to encode.
#
# Results:
#	The bee-encoded form of the string.

proc ::bee::encodeString {string} {
    return "[string length $string]:$string"
}


# ::bee::encodeNumber --
#
#	Encode an integer number to bee-format.
#
# Arguments:
#	num	The integer number to encode.
#
# Results:
#	The bee-encoded form of the integer number.

proc ::bee::encodeNumber {num} {
    if {![string is integer -strict $num]} {
	return -code error "Expected integer number, got \"$num\""
    }

    # The reformatting deals with hex, octal and other tcl
    # representation of the value. In other words we normalize the
    # string representation of the input value.

    set num [format %d $num]
    return "i${num}e"
}


# ::bee::encodeList --
#
#	Encode a list of bee-coded values to bee-format.
#
# Arguments:
#	list	The list to encode.
#
# Results:
#	The bee-encoded form of the list.

proc ::bee::encodeList {list} {
    return "l[join $list ""]e"
}


# ::bee::encodeListArgs --
#
#	Encode a variable list of bee-coded values to bee-format.
#
# Arguments:
#	args	The values to encode.
#
# Results:
#	The bee-encoded form of the list of values.

proc ::bee::encodeListArgs {args} {
    return [encodeList $args]
}


# ::bee::encodeDict --
#
#	Encode a dictionary of keys and bee-coded values to bee-format.
#
# Arguments:
#	dict	The dictionary to encode.
#
# Results:
#	The bee-encoded form of the dictionary.

proc ::bee::encodeDict {dict} {
    if {([llength $dict] % 2) == 1} {
	return -code error "Expected even number of elements, got \"[llength $dict]\""
    }
    set temp [list]
    foreach {k v} $dict {
	lappend temp [list $k $v]
    }
    set res "d"
    foreach item [lsort -index 0 $temp] {
	foreach {k v} $item break
	append res [encodeString $k]$v
    }
    append res "e"
    return $res
}


# ::bee::encodeDictArgs --
#
#	Encode a variable dictionary of keys and bee-coded values to bee-format.
#
# Arguments:
#	args	The keys and values to encode.
#
# Results:
#	The bee-encoded form of the dictionary.

proc ::bee::encodeDictArgs {args} {
    return [encodeDict $args]
}


# ::bee::decode --
#
#	Decode a bee-encoded value and returns the embedded tcl
#	value. For containers this recurses into the contained value.
#
# Arguments:
#	value	The string containing the bee-encoded value to decode.
#	evar	Optional. If set the name of the variable to store the
#		index of the first character after the decoded value to.
#	start	Optional. If set the index of the first character of the
#		value to decode. Defaults to 0, i.e. the beginning of the
#		string.
#
# Results:
#	The tcl value embedded in the encoded string.

proc ::bee::decode {value {evar {}} {start 0}} {
    #variable X
    #puts -nonewline "[string repeat "    " $X]decode @$start" ; flush stdout

    if {$evar ne ""} {upvar 1 $evar end} else {set end _}

    if {[string length $value] < ($start+2)} {
	# This checked that the 'start' index is still in the string,
	# and the end of the value most likely as well. Note that each
	# encoded value consists of at least two characters (the
	# bracketing characters for integer, list, and dict, and for
	# string at least one digit length and the colon).

	#puts \t[string length $value]\ <\ ($start+2)
	return -code error "String not large enough for value"
    }

    set type [string index $value $start]

    #puts -nonewline " $type=" ; flush stdout

    if {$type eq "i"} {
	# Extract integer
	#puts -nonewline integer ; flush stdout

	incr start ; # Skip over intro 'i'.
	set end [string first e $value $start]
	if {$end < 0} {
	    return -code error "End of integer number not found"
	}
	incr end -1 ; # Get last character before closing 'e'.
	set num [string range $value $start $end]
	if {
	    [regexp {^-0+$} $num] ||
	    ![string is integer -strict $num] ||
	    (([string length $num] > 1) && [string match 0* $num])
	} {
	    return -code error "Expected integer number, got \"$num\""
	}
	incr end 2 ; # Step after closing 'e' to the beginning of
	# ........ ; # the next bee-value behind the current one.

	#puts " ($num) @$end"
	return $num

    } elseif {($type eq "l") || ($type eq "d")} {
	#puts -nonewline $type\n ; flush stdout

	# Extract list or dictionary, recursively each contained
	# element. From the perspective of the decoder this is the
	# same, the tcl representation of both is a list, and for a
	# dictionary keys and values are also already in the correct
	# order.

	set result [list]
	incr start ; # Step over intro 'e' to beginning of the first
	# ........ ; # contained value, or behind the container (if
	# ........ ; # empty).

	set end $start
	#incr X
	while {[string index $value $start] ne "e"} {
	    lappend result [decode $value end $start]
	    set start $end
	}
	#incr X -1
	incr end

	#puts "[string repeat "    " $X]($result) @$end"

	if {$type eq "d" && ([llength $result] % 2 == 1)} {
	    return -code error "Dictionary has to be of even length"
	}
	return $result

    } elseif {[string match {[0-9]} $type]} {
	#puts -nonewline string ; flush stdout

	# Extract string. First the length, bounded by a colon, then
	# the appropriate number of characters.

	set end [string first : $value $start]
	if {$end < 0} {
	    return -code error "End of string length not found"
	}
	incr end -1
	set length [string range $value $start $end]
	incr end 2 ;# Skip to beginning of the string after the colon

	if {![string is integer -strict $length]} {
	    return -code error "Expected integer number for string length, got \"$length\""
	} elseif {$length < 0} {
	    # This cannot happen. To happen "-" has to be first character,
	    # and this is caught as unknown bee-type.
	    return -code error "Illegal negative string length"
	} elseif {($end + $length) > [string length $value]} {
	    return -code error "String not large enough for value"
	}

	#puts -nonewline \[$length\] ; flush stdout
	if {$length > 0} {
	    set  start $end
	    incr end $length
	    incr end -1
	    set result [string range $value $start $end]
	    incr end
	} else {
	    set result ""
	}

	#puts " ($result) @$end"
	return $result

    } else {
	return -code error "Unknown bee-type \"$type\""
    }
}

# ::bee::decodeIndices --
#
#	Similar to 'decode', but does not return the decoded tcl values,
#	but a structure containing the start- and end-indices for all
#	values in the structure.
#
# Arguments:
#	value	The string containing the bee-encoded value to decode.
#	evar	Optional. If set the name of the variable to store the
#		index of the first character after the decoded value to.
#	start	Optional. If set the index of the first character of the
#		value to decode. Defaults to 0, i.e. the beginning of the
#		string.
#
# Results:
#	The structure of the value, with indices and types for all
#	contained elements.

proc ::bee::decodeIndices {value {evar {}} {start 0}} {
    #variable X
    #puts -nonewline "[string repeat "    " $X]decode @$start" ; flush stdout

    if {$evar ne ""} {upvar 1 $evar end} else {set end _}

    if {[string length $value] < ($start+2)} {
	# This checked that the 'start' index is still in the string,
	# and the end of the value most likely as well. Note that each
	# encoded value consists of at least two characters (the
	# bracketing characters for integer, list, and dict, and for
	# string at least one digit length and the colon).

	#puts \t[string length $value]\ <\ ($start+2)
	return -code error "String not large enough for value"
    }

    set type [string index $value $start]

    #puts -nonewline " $type=" ; flush stdout

    if {$type eq "i"} {
	# Extract integer
	#puts -nonewline integer ; flush stdout

	set begin $start

	incr start ; # Skip over intro 'i'.
	set end [string first e $value $start]
	if {$end < 0} {
	    return -code error "End of integer number not found"
	}
	incr end -1 ; # Get last character before closing 'e'.
	set num [string range $value $start $end]
	if {
	    [regexp {^-0+$} $num] ||
	    ![string is integer -strict $num] ||
	    (([string length $num] > 1) && [string match 0* $num])
	} {
	    return -code error "Expected integer number, got \"$num\""
	}
	incr end
	set stop $end
	incr end 1 ; # Step after closing 'e' to the beginning of
	# ........ ; # the next bee-value behind the current one.

	#puts " ($num) @$end"
	return [list integer $begin $stop]

    } elseif {$type eq "l"} {
	#puts -nonewline $type\n ; flush stdout

	# Extract list, recursively each contained element.

	set result [list]

	lappend result list $start @

	incr start ; # Step over intro 'e' to beginning of the first
	# ........ ; # contained value, or behind the container (if
	# ........ ; # empty).

	set end $start
	#incr X

	set contained [list]
	while {[string index $value $start] ne "e"} {
	    lappend contained [decodeIndices $value end $start]
	    set start $end
	}
	lappend result $contained
	#incr X -1
	set stop $end
	incr end

	#puts "[string repeat "    " $X]($result) @$end"

	return [lreplace $result 2 2 $stop]

    } elseif {($type eq "l") || ($type eq "d")} {
	#puts -nonewline $type\n ; flush stdout

	# Extract dictionary, recursively each contained element.

	set result [list]

	lappend result dict $start @

	incr start ; # Step over intro 'e' to beginning of the first
	# ........ ; # contained value, or behind the container (if
	# ........ ; # empty).

	set end $start
	set atkey 1
	#incr X

	set contained [list]
	set val       [list]
	while {[string index $value $start] ne "e"} {
	    if {$atkey} {
		lappend contained [decode $value {} $start]
		lappend val       [decodeIndices $value end $start]
		set atkey 0
	    } else {
		lappend val       [decodeIndices $value end $start]
		lappend contained $val
		set val [list]
		set atkey 1
	    }
	    set start $end
	}
	lappend result $contained
	#incr X -1
	set stop $end
	incr end

	#puts "[string repeat "    " $X]($result) @$end"

	if {[llength $result] % 2 == 1} {
	    return -code error "Dictionary has to be of even length"
	}
	return [lreplace $result 2 2 $stop]

    } elseif {[string match {[0-9]} $type]} {
	#puts -nonewline string ; flush stdout

	# Extract string. First the length, bounded by a colon, then
	# the appropriate number of characters.

	set end [string first : $value $start]
	if {$end < 0} {
	    return -code error "End of string length not found"
	}
	incr end -1
	set length [string range $value $start $end]
	incr end 2 ;# Skip to beginning of the string after the colon

	if {![string is integer -strict $length]} {
	    return -code error "Expected integer number for string length, got \"$length\""
	} elseif {$length < 0} {
	    # This cannot happen. To happen "-" has to be first character,
	    # and this is caught as unknown bee-type.
	    return -code error "Illegal negative string length"
	} elseif {($end + $length) > [string length $value]} {
	    return -code error "String not large enough for value"
	}

	#puts -nonewline \[$length\] ; flush stdout
	incr end -1
	if {$length > 0} {
	    incr end $length
	    set stop $end
	} else {
	    set stop $end
	}
	incr end

	#puts " ($result) @$end"
	return [list string $start $stop]

    } else {
	return -code error "Unknown bee-type \"$type\""
    }
}


# ::bee::decodeChannel --
#
#	Attach decoder for a bee-value to a channel. See the
#	documentation for details.
#
# Arguments:
#	chan			Channel to attach to.
#	-command cmdprefix	Completion callback. Required.
#	-exact			Keep running after completion.
#	-prefix data		Seed for decode buffer.
#
# Results:
#	A token to use when referring to the decoder.
#	For example when canceling it.

proc ::bee::decodeChannel {chan args} {
    variable bee
    if {[info exists bee($chan)]} {
	return -code error "bee-Decoder already active for channel"
    }

    # Create state and token.

    variable  count
    variable  [set st state$count]
    array set $st {}
    set       bee($chan) $st
    upvar 0  $st state
    incr count

    # Initialize the decoder state, process the options. When
    # encountering errors here destroy the half-baked state before
    # throwing the message.

    set       state(chan) $chan
    array set state {
	exact  0
	type   ?
	read   {}
	value  {}
	pend   {}
	state  intro
	get    1
    }

    while {[llength $args]} {
	set option [lindex $args 0]
	set args [lrange $args 1 end]
	if {$option eq "-command"} {
	    if {![llength $args]} {
		unset bee($chan)
		unset state
		return -code error "Missing value for option -command."
	    }
	    set state(cmd) [lindex $args 0]
	    set args       [lrange $args 1 end]

	} elseif {$option eq "-prefix"} {
	    if {![llength $args]} {
		unset bee($chan)
		unset state
		return -code error "Missing value for option -prefix."
	    }
	    set state(read) [lindex $args 0]
	    set args        [lrange $args 1 end]

	} elseif {$option eq "-exact"} {
	    set state(exact) 1
	} else {
	    unset bee($chan)
	    unset state
	    return -code error "Illegal option \"$option\",\
		    expected \"-command\", \"-prefix\", or \"-keep\""
	}
    }

    if {![info exists state(cmd)]} {
	unset bee($chan)
	unset state
	return -code error "Missing required completion callback."
    }

    # Set up the processing of incoming data.

    fileevent $chan readable [list ::bee::Process $chan $bee($chan)]

    # Return the name of the state array as token.
    return $bee($chan)
}

# ::bee::Parse --
#
#	Internal helper. Fileevent handler for a decoder.
#	Parses input and handles both error and eof conditions.
#
# Arguments:
#	token	The decoder to run on its input.
#
# Results:
#	None.

proc ::bee::Process {chan token} {
    if {[catch {Parse $token} msg]} {
	# Something failed. Destroy and report.
	Command $token error $msg
	return
    }

    if {[eof $chan]} {
	# Having data waiting, either in the input queue, or in the
	# output stack (of nested containers) is a failure. Report
	# this instead of the eof.

	variable $token
	upvar 0  $token state

	if {
	    [string length $state(read)] ||
	    [llength       $state(pend)] ||
	    [string length $state(value)] ||
	    ($state(state) ne "intro")
	} {
	    Command $token error "Incomplete value at end of channel"
	} else {
	    Command $token eof
	}
    }
    return
}

# ::bee::Parse --
#
#	Internal helper. Reading from the channel and parsing the input.
#	Uses a hardwired state machine.
#
# Arguments:
#	token	The decoder to run on its input.
#
# Results:
#	None.

proc ::bee::Parse {token} {
    variable $token
    upvar 0  $token state
    upvar 0  state(state) current
    upvar 0  state(read)  input
    upvar 0  state(type)  type
    upvar 0  state(value) value
    upvar 0  state(pend)  pend
    upvar 0  state(exact) exact
    upvar 0  state(get)   get
    set chan $state(chan)

    #puts Parse/$current

    if {!$exact} {
	# Add all waiting characters to the buffer so that we can process as
	# much as is possible in one go.
	append input [read $chan]
    } else {
	# Exact reading. Usually one character, but when in the data
	# section for a string value we know for how many characters
	# we are looking for.

	append input [read $chan $get]
    }

    # We got nothing, do nothing.
    if {![string length $input]} return


    if {$current eq "data"} {
	# String data, this can be done faster, as we read longer
	# sequences of characters for this.
	set l [string length $input]
	if {$l < $get} {
	    # Not enough, wait for more.
	    append value $input
	    incr get -$l
	    return
	} elseif {$l == $get} {
	    # Got all, exactly. Prepare state machine for next value.

	    if {[Complete $token $value$input]} return

	    set current intro
	    set get 1
	    set value ""
	    set input ""

	    return
	} else {
	    # Got more than required (only for !exact).

	    incr get -1
	    if {[Complete $token $value[string range $input 0 $get]]} {return}

	    incr get
	    set input [string range $input $get end]
	    set get 1
	    set value ""
	    set current intro
	    # This now falls into the loop below.
	}
    }

    set where 0
    set n [string length $input]

    #puts Parse/$n

    while {$where < $n} {
	# Hardwired state machine. Get current character.
	set ch [string index $input $where]

	#puts Parse/@$where/$current/$ch/
	if {$current eq "intro"} {
	    # First character of a value.

	    if {$ch eq "i"} {
		# Begin reading integer.
		set type    integer
		set current signum
	    } elseif {$ch eq "l"} {
		# Begin a list.
		set type list
		lappend pend list {}
		#set current intro

	    } elseif {$ch eq "d"} {
		# Begin a dictionary.
		set type dict
		lappend pend dict {}
		#set current intro

	    } elseif {$ch eq "e"} {
		# Close a container. Throw an error if there is no
		# container to close.

		if {![llength $pend]} {
		    return -code error "End of container outside of container."
		}

		set v    [lindex $pend end]
		set t    [lindex $pend end-1]
		set pend [lrange $pend 0 end-2]

		if {$t eq "dict" && ([llength $v] % 2 == 1)} {
		    return -code error "Dictionary has to be of even length"
		}

		if {[Complete $token $v]} {return}
		set current intro

	    } elseif {[string match {[0-9]} $ch]} {
		# Begin reading a string, length section first.
		set type    string
		set current ldigit
		set value   $ch

	    } else {
		# Unknown type. Throw error.
		return -code error "Unknown bee-type \"$ch\""
	    }

	    # To next character.
	    incr where
	} elseif {$current eq "signum"} {
	    # Integer number, a minus sign, or a digit.
	    if {[string match {[-0-9]} $ch]} {
		append value $ch
		set current idigit
	    } else {
		return -code error "Syntax error in integer,\
			expected sign or digit, got \"$ch\""
	    }
	    incr where

	} elseif {$current eq "idigit"} {
	    # Integer number, digit or closing 'e'.

	    if {[string match {[-0-9]} $ch]} {
		append value $ch
	    } elseif {$ch eq "e"} {
		# Integer closes. Validate and report.
		#puts validate
		if {
		    [regexp {^-0+$} $value] ||
		    ![string is integer -strict $value] ||
		    (([string length $value] > 1) && [string match 0* $value])
		} {
		    return -code error "Expected integer number, got \"$value\""
		}

		if {[Complete $token $value]} {return}
		set value ""
		set current intro
	    } else {
		return -code error "Syntax error in integer,\
			expected digit, or 'e', got \"$ch\""
	    }
	    incr where

	} elseif {$current eq "ldigit"} {
	    # String, length section, digit, or :

	    if {[string match {[-0-9]} $ch]} {
		append value $ch

	    } elseif {$ch eq ":"} {
		# Length section closes, validate,
		# then perform data processing.

		set num $value
		if {
		    [regexp {^-0+$} $num] ||
		    ![string is integer -strict $num] ||
		    (([string length $num] > 1) && [string match 0* $num])
		} {
		    return -code error "Expected integer number as string length, got \"$num\""
		}

		set value ""

		# We may have already part of the data in
		# memory. Process that piece before looking for more.

		incr where
		set have [expr {$n - $where}]
		if {$num < $have} {
		    # More than enough in the buffer.

		    set  end $where
		    incr end $num
		    incr end -1

		    if {[Complete $token [string range $input $where $end]]} {return}

		    set where   $end ;# Further processing behind the string.
		    set current intro

		} elseif {$num == $have} {
		    # Just enough. 

		    if {[Complete $token [string range $input $where end]]} {return}

		    set where   $n
		    set current intro
		} else {
		    # Not enough. Initialize value with the data we
		    # have (after the colon) and stop processing for
		    # now.

		    set value   [string range $input $where end]
		    set current data
		    set get     $num
		    set input   ""
		    return
		}
	    } else {
		return -code error "Syntax error in string length,\
			expected digit, or ':', got \"$ch\""
	    }
	    incr where
	} else {
	    # unknown state = internal error
	    return -code error "Unknown decoder state \"$current\", internal error"
	}
    }

    set input ""
    return
}

# ::bee::Command --
#
#	Internal helper. Runs the decoder command callback.
#
# Arguments:
#	token	The decoder invoking its callback
#	how	Which method to invoke (value, error, eof)
#	args	Arguments for the method.
#
# Results:
#	A boolean flag. Set if further processing has to stop.

proc ::bee::Command {token how args} {
    variable $token
    upvar 0  $token state

    #puts Report/$token/$how/$args/

    set cmd  $state(cmd)
    set chan $state(chan)

    # We catch the fileevents because they will fail when this is
    # called from the 'Close'. The channel will already be gone in
    # that case.

    set stop 0
    if {($how eq "error") || ($how eq "eof")} {
	variable bee

	set stop 1
	fileevent $chan readable {}
	unset bee($chan)
	unset state

	if {$how eq "eof"} {
	    #puts \tclosing/$chan
	    close $chan
	}
    }

    lappend cmd $how $token
    foreach a $args {lappend cmd $a}
    uplevel #0 $cmd

    if {![info exists state]} {
	# The decoder token was killed by the callback, stop
	# processing.
	set stop 1
    }

    #puts /$stop/[file channels]
    return $stop
}

# ::bee::Complete --
#
#	Internal helper. Reports a completed value.
#
# Arguments:
#	token	The decoder reporting the value.
#	value	The value to report.
#
# Results:
#	A boolean flag. Set if further processing has to stop.

proc ::bee::Complete {token value} {
    variable $token
    upvar 0  $token state
    upvar 0   state(pend) pend

    if {[llength $pend]} {
	# The value is part of a container. Add the value to its end
	# and keep processing.

	set pend [lreplace $pend end end \
		[linsert [lindex $pend end] end \
		$value]]

	# Don't stop.
	return 0
    }

    # The value is at the top, report it. The callback determines if
    # we keep processing.

    return [Command $token value $value]
}

# ::bee::decodeCancel --
#
#	Destroys the decoder referenced by the token.
#
# Arguments:
#	token	The decoder to destroy.
#
# Results:
#	None.

proc ::bee::decodeCancel {token} {
    variable bee
    variable $token
    upvar 0  $token state
    unset bee($state(chan))
    unset state
    return
}

# ::bee::decodePush --
#
#	Push data into the decoder input buffer.
#
# Arguments:
#	token	The decoder to extend.
#	string	The characters to add.
#
# Results:
#	None.

proc ::bee::decodePush {token string} {
    variable $token
    upvar 0  $token state
    append state(read) $string
    return
}


package provide bee 0.1
