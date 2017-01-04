# log.tcl --
#
#	Tcl implementation of a general logging facility
#	(Reaped from Pool_Base and modified to fit into tcllib)
#
# Copyright (c) 2001 by ActiveState Tool Corp.
# See the file license.terms.

package require Tcl 8
package provide log 1.3

# ### ### ### ######### ######### #########

namespace eval ::log {
    namespace export levels lv2longform lv2color lv2priority 
    namespace export lv2cmd lv2channel lvCompare
    namespace export lvSuppress lvSuppressLE lvIsSuppressed
    namespace export lvCmd lvCmdForall
    namespace export lvChannel lvChannelForall lvColor lvColorForall
    namespace export log logMsg logError

    # The known log-levels.

    variable levels [list \
	    emergency \
	    alert \
	    critical \
	    error \
	    warning \
	    notice \
	    info \
	    debug]

    # Array mapping from all unique prefixes for log levels to their
    # corresponding long form.

    # *future* Use a procedure from 'textutil' to calculate the
    #          prefixes and to fill the map.

    variable  levelMap
    array set levelMap {
	a		alert
	al		alert
	ale		alert
	aler		alert
	alert		alert
	c		critical
	cr		critical
	cri		critical
	crit		critical
	criti		critical
	critic		critical
	critica		critical
	critical	critical
	d		debug
	de		debug
	deb		debug
	debu		debug
	debug		debug
	em		emergency
	eme		emergency
	emer		emergency
	emerg		emergency
	emerge		emergency
	emergen		emergency
	emergenc	emergency
	emergency	emergency
	er		error
	err		error
	erro		error
	error		error
	i		info
	in		info
	inf		info
	info		info
	n		notice
	no		notice
	not		notice
	noti		notice
	notic		notice
	notice		notice
	w		warning
	wa		warning
	war		warning
	warn		warning
	warni		warning
	warnin		warning
	warning		warning
    }

    # Map from log-levels to the commands to execute when a message
    # with that level arrives in the system. The standard command for
    # all levels is '::log::Puts' which writes the message to either
    # stdout or stderr, depending on the level. The decision about the
    # channel is stored in another map and modifiable by the user of
    # the package.

    variable  cmdMap
    array set cmdMap {}

    variable lv
    foreach  lv $levels {set cmdMap($lv) ::log::Puts}
    unset    lv

    # Map from log-levels to the channels ::log::Puts shall write
    # messages with that level to. The map can be queried and changed
    # by the user.

    variable  channelMap
    array set channelMap {
	emergency  stderr
	alert      stderr
	critical   stderr
	error      stderr
	warning    stdout
	notice     stdout
	info       stdout
	debug      stdout
    }

    # Graphical user interfaces may want to colorize messages based
    # upon their level. The following array stores a map from levels
    # to colors. The map can be queried and changed by the user.

    variable  colorMap
    array set colorMap {
	emergency red
	alert     red
	critical  red
	error     red
	warning   yellow
	notice    seagreen
	info      {}
	debug     lightsteelblue
    }

    # To allow an easy comparison of the relative importance of a
    # level the following array maps from levels to a numerical
    # priority. The higher the number the more important the
    # level. The user cannot change this map (for now). This package
    # uses the priorities to allow the user to supress messages based
    # upon their levels.

    variable  priorityMap
    array set priorityMap {
	emergency 7
	alert     6
	critical  5
	error     4
	warning   3
	notice    2
	info      1
	debug     0
    }

    # The following array is internal and holds the information about
    # which levels are suppressed, i.e. may not be written.
    #
    # 0 - messages with with level are written out.
    # 1 - messages with this level are suppressed.

    # Note: This initialization is partially overridden via
    # 'log::lvSuppressLE' at the bottom of this file.

    variable  suppressed
    array set suppressed {
	emergency 0
	alert     0
	critical  0
	error     0
	warning   0
	notice    0
	info      0
	debug     0
    }

    # Internal static information. Map from levels to a string of
    # spaces. The number of spaces in each string is just enough to
    # make all level names together with their string of the same
    # length.

    variable  fill
    array set fill {
	emergency ""	alert "    "	critical " "	error "    "
	warning "  "	notice "   "	info "     "	debug "    "
    }
}


# log::levels --
#
#	Retrieves the names of all known levels.
#
# Arguments:
#	None.
#
# Side Effects:
#	None.
#
# Results:
#	A list containing the names of all known levels,
#	alphabetically sorted.

proc ::log::levels {} {
    variable levels
    return [lsort $levels]
}

# log::lv2longform --
#
#	Converts any unique abbreviation of a level name to the full
#	level name.
#
# Arguments:
#	level	The prefix of a level name to convert.
#
# Side Effects:
#	None.
#
# Results:
#	Returns the full name to the specified abbreviation or an
#	error.

proc ::log::lv2longform {level} {
    variable levelMap

    if {[info exists levelMap($level)]} {
	return $levelMap($level)
    }

    return -code error "bad level \"$level\": must be [join [lreplace [levels] end end "or [lindex [levels] end]"] ", "]."
}

# log::lv2color --
#
#	Converts any level name including unique abbreviations to the
#	corresponding color.
#
# Arguments:
#	level	The level to convert into a color.
#
# Side Effects:
#	None.
#
# Results:
#	The name of a color or an error.

proc ::log::lv2color {level} {
    variable colorMap
    set level [lv2longform $level]
    return $colorMap($level)
}

# log::lv2priority --
#
#	Converts any level name including unique abbreviations to the
#	corresponding priority.
#
# Arguments:
#	level	The level to convert into a priority.
#
# Side Effects:
#	None.
#
# Results:
#	The numerical priority of the level or an error.

proc ::log::lv2priority {level} {
    variable priorityMap
    set level [lv2longform $level]
    return $priorityMap($level)
}

# log::lv2cmd --
#
#	Converts any level name including unique abbreviations to the
#	command prefix used to write messages with that level.
#
# Arguments:
#	level	The level to convert into a command prefix.
#
# Side Effects:
#	None.
#
# Results:
#	A string containing a command prefix or an error.

proc ::log::lv2cmd {level} {
    variable cmdMap
    set level [lv2longform $level]
    return $cmdMap($level)
}

# log::lv2channel --
#
#	Converts any level name including unique abbreviations to the
#	channel used by ::log::Puts to write messages with that level.
#
# Arguments:
#	level	The level to convert into a channel.
#
# Side Effects:
#	None.
#
# Results:
#	A string containing a channel handle or an error.

proc ::log::lv2channel {level} {
    variable channelMap
    set level [lv2longform $level]
    return $channelMap($level)
}

# log::lvCompare --
#
#	Compares two levels (including unique abbreviations) with
#	respect to their priority. This command can be used by the
#	-command option of lsort.
#
# Arguments:
#	level1	The first of the levels to compare.
#	level2	The second of the levels to compare.
#
# Side Effects:
#	None.
#
# Results:
#	One of -1, 0 or 1 or an error. A result of -1 signals that
#	level1 is of less priority than level2. 0 signals that both
#	levels have the same priority. 1 signals that level1 has
#	higher priority than level2.

proc ::log::lvCompare {level1 level2} {
    variable priorityMap

    set level1 $priorityMap([lv2longform $level1])
    set level2 $priorityMap([lv2longform $level2])

    if {$level1 < $level2} {
	return -1
    } elseif {$level1 > $level2} {
	return 1
    } else {
	return 0
    }
}

# log::lvSuppress --
#
#	(Un)suppresses the output of messages having the specified
#	level. Unique abbreviations for the level are allowed here
#	too.
#
# Arguments:
#	level		The name of the level to suppress or
#			unsuppress. Unique abbreviations are allowed
#			too.
#	suppress	Boolean flag. Optional. Defaults to the value
#			1, which means to suppress the level. The
#			value 0 on the other hand unsuppresses the
#			level.
#
# Side Effects:
#	See above.
#
# Results:
#	None.

proc ::log::lvSuppress {level {suppress 1}} {
    variable suppressed
    set level [lv2longform $level]

    switch -exact -- $suppress {
	0 - 1 {} default {
	    return -code error "\"$suppress\" is not a member of \{0, 1\}"
	}
    }

    set suppressed($level) $suppress
    return
}

# log::lvSuppressLE --
#
#	(Un)suppresses the output of messages having the specified
#	level or one of lesser priority. Unique abbreviations for the
#	level are allowed here too.
#
# Arguments:
#	level		The name of the level to suppress or
#			unsuppress. Unique abbreviations are allowed
#			too.
#	suppress	Boolean flag. Optional. Defaults to the value
#			1, which means to suppress the specified
#			levels. The value 0 on the other hand
#			unsuppresses the levels.
#
# Side Effects:
#	See above.
#
# Results:
#	None.

proc ::log::lvSuppressLE {level {suppress 1}} {
    variable suppressed
    variable levels
    variable priorityMap

    set level [lv2longform $level]

    switch -exact -- $suppress {
	0 - 1 {} default {
	    return -code error "\"$suppress\" is not a member of \{0, 1\}"
	}
    }

    set prio  [lv2priority $level]

    foreach l $levels {
	if {$priorityMap($l) <= $prio} {
	    set suppressed($l) $suppress
	}
    }
    return
}

# log::lvIsSuppressed --
#
#	Asks the package wether the specified level is currently
#	suppressed. Unique abbreviations of level names are allowed.
#
# Arguments:
#	level	The level to query.
#
# Side Effects:
#	None.
#
# Results:
#	None.

proc ::log::lvIsSuppressed {level} {
    variable suppressed
    set level [lv2longform $level]
    return $suppressed($level)
}

# log::lvCmd --
#
#	Defines for the specified level with which command to write
#	the messages having this level. Unique abbreviations of level
#	names are allowed. The command is actually a command prefix
#	and this facility will append 2 arguments before calling it,
#	the level of the message and the message itself, in this
#	order.
#
# Arguments:
#	level	The level the command prefix is for.
#	cmd	The command prefix to use for the specified level.
#
# Side Effects:
#	See above.
#
# Results:
#	None.

proc ::log::lvCmd {level cmd} {
    variable cmdMap
    set level [lv2longform $level]
    set cmdMap($level) $cmd
    return
}

# log::lvCmdForall --
#
#	Defines for all known levels with which command to write the
#	messages having this level. The command is actually a command
#	prefix and this facility will append 2 arguments before
#	calling it, the level of the message and the message itself,
#	in this order.
#
# Arguments:
#	cmd	The command prefix to use for all levels.
#
# Side Effects:
#	See above.
#
# Results:
#	None.

proc ::log::lvCmdForall {cmd} {
    variable cmdMap
    variable levels

    foreach l $levels {
	set cmdMap($l) $cmd
    }
    return
}

# log::lvChannel --
#
#	Defines for the specified level into which channel ::log::Puts
#	(the standard command) shall write the messages having this
#	level. Unique abbreviations of level names are allowed. The
#	command is actually a command prefix and this facility will
#	append 2 arguments before calling it, the level of the message
#	and the message itself, in this order.
#
# Arguments:
#	level	The level the channel is for.
#	chan	The channel to use for the specified level.
#
# Side Effects:
#	See above.
#
# Results:
#	None.

proc ::log::lvChannel {level chan} {
    variable channelMap
    set level [lv2longform $level]
    set channelMap($level) $chan
    return
}

# log::lvChannelForall --
#
#	Defines for all known levels with which which channel
#	::log::Puts (the standard command) shall write the messages
#	having this level. The command is actually a command prefix
#	and this facility will append 2 arguments before calling it,
#	the level of the message and the message itself, in this
#	order.
#
# Arguments:
#	chan	The channel to use for all levels.
#
# Side Effects:
#	See above.
#
# Results:
#	None.

proc ::log::lvChannelForall {chan} {
    variable channelMap
    variable levels

    foreach l $levels {
	set channelMap($l) $chan
    }
    return
}

# log::lvColor --
#
#	Defines for the specified level the color to return for it in
#	a call to ::log::lv2color. Unique abbreviations of level names
#	are allowed.
#
# Arguments:
#	level	The level the color is for.
#	color	The color to use for the specified level.
#
# Side Effects:
#	See above.
#
# Results:
#	None.

proc ::log::lvColor {level color} {
    variable colorMap
    set level [lv2longform $level]
    set colorMap($level) $color
    return
}

# log::lvColorForall --
#
#	Defines for all known levels the color to return for it in a
#	call to ::log::lv2color. Unique abbreviations of level names
#	are allowed.
#
# Arguments:
#	color	The color to use for all levels.
#
# Side Effects:
#	See above.
#
# Results:
#	None.

proc ::log::lvColorForall {color} {
    variable colorMap
    variable levels

    foreach l $levels {
	set colorMap($l) $color
    }
    return
}

# log::logarray --
#
#	Similar to parray, except that the contents of the array
#	printed out through the log system instead of directly
#	to stdout.
#
#	See also 'log::log' for a general explanation
#
# Arguments:
#	level		The level of the message.
#	arrayvar	The name of the array varaibe to dump
#	pattern		Optional pattern to restrict the dump
#			to certain elements in the array.
#
# Side Effects:
#	See above.
#
# Results:
#	None.

proc ::log::logarray {level arrayvar {pattern *}} {
    variable cmdMap

    if {[lvIsSuppressed $level]} {
	# Ignore messages for suppressed levels.
	return
    }

    set level [lv2longform $level]

    set cmd $cmdMap($level)
    if {$cmd == {}} {
	# Ignore messages for levels without a command
	return
    }

    upvar 1 $arrayvar array
    if {![array exists array]} {
        error "\"$arrayvar\" isn't an array"
    }
    set maxl 0
    foreach name [lsort [array names array $pattern]] {
        if {[string length $name] > $maxl} {
            set maxl [string length $name]
        }
    }
    set maxl [expr {$maxl + [string length $arrayvar] + 2}]
    foreach name [lsort [array names array $pattern]] {
        set nameString [format %s(%s) $arrayvar $name]

	eval [linsert $cmd end $level \
		[format "%-*s = %s" $maxl $nameString $array($name)]]
    }
    return
}

# log::loghex --
#
#	Like 'log::log', except that the logged data is assumed to
#	be binary and is logged as a block of hex numbers.
#
#	See also 'log::log' for a general explanation
#
# Arguments:
#	level	The level of the message.
#	text	Message printed before the hex block
#	data	Binary data to show as hex.
#
# Side Effects:
#	See above.
#
# Results:
#	None.

proc ::log::loghex {level text data} {
    variable cmdMap

    if {[lvIsSuppressed $level]} {
	# Ignore messages for suppressed levels.
	return
    }

    set level [lv2longform $level]

    set cmd $cmdMap($level)
    if {$cmd == {}} {
	# Ignore messages for levels without a command
	return
    }

    # Format the messages and print them.

    set len [string length $data]

    eval [linsert $cmd end $level "$text ($len bytes):"]

    set address ""
    set hexnums ""
    set ascii   ""

    for {set i 0} {$i < $len} {incr i} {
        set v [string index $data $i]
        binary scan $v H2 hex
        binary scan $v c  num
        set num [expr {($num + 0x100) % 0x100}]

        set text .
        if {$num > 31} {set text $v} 

        if {($i % 16) == 0} {
            if {$address != ""} {
                eval [linsert $cmd end $level [format "%4s  %-48s  |%s|" $address $hexnums $ascii]]
                set address ""
                set hexnums ""
                set ascii   ""
            }
            append address [format "%04d" $i]
        }
        append hexnums "$hex "
        append ascii   $text
    }
    if {$address != ""} {
	eval [linsert $cmd end $level [format "%4s  %-48s  |%s|" $address $hexnums $ascii]]
    }
    eval [linsert $cmd end $level ""]
    return
}

# log::log --
#
#	Log a message according to the specifications for commands,
#	channels and suppression. In other words: The command will do
#	nothing if the specified level is suppressed. If it is not
#	suppressed the actual logging is delegated to the specified
#	command. If there is no command specified for the level the
#	message won't be logged. The standard command ::log::Puts will
#	write the message to the channel specified for the given
#	level. If no channel is specified for the level the message
#	won't be logged. Unique abbreviations of level names are
#	allowed. Errors in the actual logging command are *not*
#	catched, but propagated to the caller, as they may indicate
#	misconfigurations of the log facility or errors in the callers
#	code itself.
#
# Arguments:
#	level	The level of the message.
#	text	The message to log.
#
# Side Effects:
#	See above.
#
# Results:
#	None.

proc ::log::log {level text} {
    variable cmdMap

    if {[lvIsSuppressed $level]} {
	# Ignore messages for suppressed levels.
	return
    }

    set level [lv2longform $level]

    set cmd $cmdMap($level)
    if {$cmd == {}} {
	# Ignore messages for levels without a command
	return
    }

    # Delegate actual logging to the command.
    # Handle multi-line messages correctly.

    foreach line [split $text \n] {
	eval [linsert $cmd end $level $line]
    }
    return
}

# log::logMsg --
#
#	Convenience wrapper around ::log::log. Equivalent to
#	'::log::log info text'.
#
# Arguments:
#	text	The message to log.
#
# Side Effects:
#	See ::log::log.
#
# Results:
#	None.

proc ::log::logMsg {text} {
    log info $text
}

# log::logError --
#
#	Convenience wrapper around ::log::log. Equivalent to
#	'::log::log error text'.
#
# Arguments:
#	text	The message to log.
#
# Side Effects:
#	See ::log::log.
#
# Results:
#	None.

proc ::log::logError {text} {
    log error $text
}


# log::Puts --
#
#	Standard log command, writing messages and levels to
#	user-specified channels. Assumes that the supression checks
#	were done by the caller. Expects full level names,
#	abbreviations are *not allowed*.
#
# Arguments:
#	level	The level of the message. 
#	text	The message to log.
#
# Side Effects:
#	Writes into channels.
#
# Results:
#	None.

proc ::log::Puts {level text} {
    variable channelMap
    variable fill

    set chan $channelMap($level)
    if {$chan == {}} {
	# Ignore levels without channel.
	return
    }

    puts  $chan "$level$fill($level) $text"
    flush $chan
    return
}

# ### ### ### ######### ######### #########
## Initialization code. Disable logging for the lower levels by
## default.

## log::lvSuppressLE emergency
log::lvSuppressLE warning
