# report.tcl --
#
#	Implementation of report objects for Tcl.
#
# Copyright (c) 2001-2014 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: report.tcl,v 1.8 2004/01/15 06:36:13 andreas_kupries Exp $

package require Tcl 8.2
package provide report 0.3.2

namespace eval ::report {
    # Data storage in the report module
    # -------------------------------
    #
    # One namespace per object, containing
    #  1) An array mapping from template codes to templates
    #  2) An array mapping from template codes and columns to horizontal template items
    #  3) An array mapping from template codes and columns to vertical template items
    #  4) ... deleted, local to formatting
    #  5) An array mapping from columns to left padding
    #  6) An array mapping from columns to right padding
    #  7) An array mapping from columns to column size
    #  8) An array mapping from columns to justification
    #  9) A scalar containing the number of columns in the report.
    # 10) An array mapping from template codes to enabledness
    # 11) A scalar containing the size of the top caption
    # 12) A scalar containing the size of the bottom caption
    #
    # 1 - template		5 - lpad	 9 - columns
    # 2 - hTemplate		6 - rpad	10 - enabled
    # 3 - vTemplate		7 - csize	11 - tcaption
    # 4 - fullHTemplate		8 - cjust	12 - bcaption

    # commands is the list of subcommands recognized by the report
    variable commands [list		\
	    "bcaption"			\
	    "botcapsep"			\
	    "botdata"			\
	    "botdatasep"		\
	    "bottom"			\
	    "columns"			\
	    "data"			\
	    "datasep"			\
	    "justify"			\
	    "pad"			\
	    "printmatrix"		\
	    "printmatrix2channel"	\
	    "size"			\
	    "sizes"			\
	    "tcaption"			\
	    "top"			\
	    "topcapsep"			\
	    "topdata"			\
	    "topdatasep"
	    ]

    # Only export the toplevel commands
    namespace export report defstyle rmstyle stylearguments stylebody

    # Global data, style definitions

    variable styles [list plain]
    variable styleargs
    variable stylebody

    array set styleargs {plain {}}
    array set stylebody {plain {}}

    # Global data, template codes, for easy checking

    variable  tcode
    array set tcode {
	topdata    0	data       0
	botdata    0	top        1
	topdatasep 1	topcapsep  1
	datasep    1	botcapsep  1
	botdatasep 1	bottom     1
    }
}

# ::report::report --
#
#	Create a new report with a given name
#
# Arguments:
#	name	Optional name of the report; if null or not given, generate one.
#
# Results:
#	name	Name of the report created

proc ::report::report {name columns args} {
    variable styleargs

    if { [llength [info commands ::$name]] } {
	error "command \"$name\" already exists, unable to create report"
    }
    if {![string is integer $columns]} {
	return -code error "columns: expected integer greater than zero, got \"$columns\""
    } elseif {$columns <= 0} {
	return -code error "columns: expected integer greater than zero, got \"$columns\""
    }

    set styleName ""
    switch -exact -- [llength $args] {
	0 {# No style was specied. This is OK}
	1 {
	    # We possibly got the "style" keyword, but everything behind is missing
	    return -code error "wrong # args: report name columns ?\"style\" styleName ?arg...??"
	}
	default {
	    # Break tail apart, check for correct keyword, ensure that style is known too.
	    # Don't forget to check the actual against the formal arguments.

	    foreach {dummy styleName} $args break
	    set args [lrange $args 2 end]

	    if {![string equal $dummy style]} {
		return -code error "wrong # args: report name columns ?\"style\" styleName ?arg...??"
	    }
	    if {![info exists styleargs($styleName)]} {
		return -code error "style \"$styleName\" is not known"
	    }
	    CheckStyleArguments $styleName $args
	}
    }

    # The arguments seem to be ok, setup the namespace for the object
    # and configure it to style "plain".

    namespace eval ::report::report$name "variable columns $columns"
    namespace eval ::report::report$name {
	variable tcaption 0
	variable bcaption 0
	variable template
	variable enabled
	variable hTemplate
	variable vTemplate
	variable lpad
	variable rpad
	variable csize
	variable cjust

	variable t
	variable i
	variable dt [list]
	variable st [list]
	for {set i 0} {$i < $columns} {incr i} {
	    set lpad($i) ""
	    set rpad($i) ""
	    set csize($i) dyn
	    set cjust($i) left
	    lappend dt {}
	    lappend st {} {}
	}
	lappend dt {}
	lappend st {}

	foreach t {
	    topdata data botdata
	} {
	    set enabled($t) 1
	    set template($t) $dt
	    for {set i 0} {$i <= $columns} {incr i} {
		set vTemplate($t,$i) {}
	    }
	}
	foreach t {
	    top topdatasep topcapsep
	    datasep
	    botcapsep botdatasep bottom
	} {
	    set enabled($t) 0
	    set template($t) $st
	    for {set i 0} {$i < $columns} {incr i} {
		set hTemplate($t,$i) {}
	    }
	    for {set i 0} {$i <= $columns} {incr i} {
		set vTemplate($t,$i) {}
	    }
	}

	unset t i dt st
    }

    # Create the command to manipulate the report
    #                 $name -> ::report::ReportProc $name
    interp alias {} ::$name {} ::report::ReportProc $name

    # If a style was specified execute it now, before the oobject is
    # handed back to the user.

    if {$styleName != {}} {
	ExecuteStyle $name $styleName $args
    }

    return $name
}

# ::report::defstyle --
#
#	Defines a new named style, with arguments and defining script.
#
# Arguments:
#	styleName	Name of the new style.
#	arguments	Formal arguments of the style, some format as for proc.
#	body		The script actually defining the style.
#
# Results:
#	None.

proc ::report::defstyle {styleName arguments body} {
    variable styleargs
    variable stylebody
    variable styles

    if {[info exists styleargs($styleName)]} {
	return -code error "Cannot create style \"$styleName\", already exists"
    }

    # Check the formal arguments
    # 1. Arguments without default may not follow an argument with a
    #    default. The special "args" is no exception!
    # 2. Compute the minimal number of arguments required by the proc.

    set min 0
    set def 0
    set ca  0

    foreach v $arguments {
	switch -- [llength $v] {
	    1 {
		if {$def} {
		    return -code error \
			    "Found argument without default after arguments having defaults"
		}
		incr min
	    }
	    2 {
		set def 1
	    }
	    default {
		error "Illegal length of value \"$v\""
	    }
	}
    }
    if {[string equal args [lindex $arguments end]]} {
	# Correct requirements if we have a catch-all at the end.
	incr min -1
	set  ca 1
    }

    # Now we are allowed to extend the internal database

    set styleargs($styleName) [list $min $ca $arguments]
    set stylebody($styleName) $body
    lappend styles $styleName
    return
}

# ::report::rmstyle --
#
#	Deletes the specified style.
#
# Arguments:
#	styleName	Name of the style to destroy.
#
# Results:
#	None.

proc ::report::rmstyle {styleName} {
    variable styleargs
    variable stylebody
    variable styles

    if {![info exists styleargs($styleName)]} {
	return -code error "cannot delete unknown style \"$styleName\""
    }
    if {[string equal $styleName plain]} {
	return -code error {cannot delete builtin style "plain"}
    }

    unset styleargs($styleName)
    unset stylebody($styleName)

    set pos    [lsearch -exact $styles $styleName]
    set styles [lreplace $styles $pos $pos]
    return
}

# ::report::_stylearguments --
#
#	Introspection, returns the list of formal arguments of the
#	specified style.
#
# Arguments:
#	styleName	Name of the style to query.
#
# Results:
#	A list containing the formal argument of the style

proc ::report::stylearguments {styleName} {
    variable styleargs
    if {![info exists styleargs($styleName)]} {
	return -code error "style \"$styleName\" is not known"
    }
    return [lindex $styleargs($styleName) 2]
}

# ::report::_stylebody --
#
#	Introspection, returns the body/script of the
#	specified style.
#
# Arguments:
#	styleName	Name of the style to query.
#
# Results:
#	A script, the body of the style.

proc ::report::stylebody {styleName} {
    variable stylebody
    if {![info exists stylebody($styleName)]} {
	return -code error "style \"$styleName\" is not known"
    }
    return $stylebody($styleName)
}

# ::report::_styles --
#
#	Returns alist containing the names of all known styles.
#
# Arguments:
#	None.
#
# Results:
#	A list containing the names of all known styles

proc ::report::styles {} {
    variable styles
    return  $styles
}

##########################
# Private functions follow

# ::report::CheckStyleArguments --
#
#	Internal helper. Used to check actual arguments of a style against the formal ones.
#
# Arguments:
#	styleName	Name of the style in question
#	arguments	Actual arguments for the style.
#
# Results:
#	None, or an error in case of problems.

proc ::report::CheckStyleArguments {styleName arguments} {
    variable styleargs

    # Match formal and actual arguments, error out in case of problems.
    foreach {min catchall formal} $styleargs($styleName) break

    if {[llength $arguments] < $min} {
	# Determine the name of the first formal parameter which did not get a value.
	set firstmissing [lindex $formal [llength $arguments]]
	return -code error "no value given for parameter \"$firstmissing\" to style \"$styleName\""
    } elseif {[llength $arguments] > $min} {
	if {!$catchall && ([llength $arguments] > [llength $formal])} {
	    # More actual arguments than formals, without catch-all argument, error
	    return -code error "called style \"$styleName\" with too many arguments"
	}
    }
}

# ::report::ExecuteStyle --
#
#	Internal helper. Applies a named style to the specified report object.
#
# Arguments:
#	name		Name of the report the style is applied to.
#	styleName	Name of the style to apply
#	arguments	Actual arguments for the style.
#
# Results:
#	None.

proc ::report::ExecuteStyle {name styleName arguments} {
    variable styleargs
    variable stylebody
    variable styles
    variable commands

    CheckStyleArguments $styleName $arguments
    foreach {min catchall formal} $styleargs($styleName) break

    array set a {}

    if {([llength $arguments] > $min) && $catchall} {
	# #min = number of formal arguments - 1
	set a(args) [lrange $arguments $min end]
	set formal  [lrange $formal 0 end-1]
	incr min -1
	set arguments [lrange $arguments 0 $min]

	# arguments and formal are now of equal length and we also
	# know that there are no arguments having a default value.
	foreach v $formal aval $arguments {
	    set a($v) $aval
	}
    }

    # More arguments than minimally required, but no more than formal
    # arguments! Proceed to standard matching: Go through the actual
    # values and associate them with a formal argument. Then fill the
    # remaining formal arguments with their default values.

    foreach aval $arguments {
	set v      [lindex $formal 0]
	set formal [lrange $formal 1 end]
	if {[llength $v] > 1} {set v [lindex $v 0]}
	set a($v) $aval
    }

    foreach vd $formal {
	foreach {var default} $vd {
	    set a($var) $default
	}
    }

    # Create and initialize a safe interpreter, execute the style and
    # then break everything down again.

    set ip [interp create -safe]

    # -- Report methods --

    foreach m $commands {
	# safe-ip method --> here report method
	interp alias $ip $m {} $name $m
    }

    # -- Styles defined before this one --

    foreach s $styles {
	if {[string equal $s $styleName]} {break}
	interp alias $ip $s {} ::report::LinkExec $name $s
    }

    # -- Arguments as variables --

    foreach {var val} [array get a] {
	$ip eval [list set $var $val]
    }

    # Finally execute / apply the style.

    $ip eval $stylebody($styleName)
    interp delete $ip
    return
}

# ::report::_LinkExec --
#
#	Internal helper. Used for application of styles from within
#	another style script. Collects the formal arguments into the
#	one list which is expected by "ExecuteStyle".
#
# Arguments:
#	name		Name of the report the style is applied to.
#	styleName	Name of the style to apply
#	args		Actual arguments for the style.
#
# Results:
#	None.

proc ::report::LinkExec {name styleName args} {
    ExecuteStyle $name $styleName $args
}

# ::report::ReportProc --
#
#	Command that processes all report object commands.
#
# Arguments:
#	name	Name of the report object to manipulate.
#	cmd	Subcommand to invoke.
#	args	Arguments for subcommand.
#
# Results:
#	Varies based on command to perform

proc ::report::ReportProc {name {cmd ""} args} {
    variable tcode

    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	error "wrong # args: should be \"$name option ?arg arg ...?\""
    }
    
    # Split the args into command and args components

    if {[info exists tcode($cmd)]} {
	# Template codes are a bit special
	eval [list ::report::_tAction $name $cmd] $args
    } else {
	if { [llength [info commands ::report::_$cmd]] == 0 } {
	    variable commands
	    set optlist [join $commands ", "]
	    set optlist [linsert $optlist "end-1" "or"]
	    error "bad option \"$cmd\": must be $optlist"
	}
	eval [list ::report::_$cmd $name] $args
    }
}

# ::report::CheckColumn --
#
#	Helper to check and transform column indices. Returns the
#	absolute index number belonging to the specified
#	index. Rejects indices out of the valid range of columns.
#
# Arguments:
#	columns Number of columns
#	column	The incoming index to check and transform
#
# Results:
#	The absolute index to the column

proc ::report::CheckColumn {columns column} {
    switch -regex -- $column {
	{end-[0-9]+} {
	    regsub -- {end-} $column {} column
	    set cc [expr {$columns - 1 - $column}]
	    if {($cc < 0) || ($cc >= $columns)} {
		return -code error "column: index \"end-$column\" out of range"
	    }
	    return $cc
	}
	end {
	    if {$columns <= 0} {
		return -code error "column: index \"$column\" out of range"
	    }
	    return [expr {$columns - 1}]
	}
	{[0-9]+} {
	    if {($column < 0) || ($column >= $columns)} {
		return -code error "column: index \"$column\" out of range"
	    }
	    return $column
	}
	default {
	    return -code error "column: syntax error in index \"$column\""
	}
    }
}

# ::report::CheckVerticals --
#
#	Internal helper. Used to check the consistency of all active
#	templates with respect to the generated vertical separators
#	(Same length).
#
# Arguments:
#	name	Name of the report object to check.
#
# Results:
#	None.

proc ::report::CheckVerticals {name} {
    upvar ::report::report${name}::vTemplate vTemplate
    upvar ::report::report${name}::enabled   enabled
    upvar ::report::report${name}::columns   columns
    upvar ::report::report${name}::tcaption  tcaption
    upvar ::report::report${name}::bcaption  bcaption

    for {set c 0} {$c <= $columns} {incr c} {
	# Collect all lengths for a column in a list, sort that and
	# compare first against last element. If they are not equal we
	# have found an inconsistent definition.

	set     res [list]
	lappend res [string length $vTemplate(data,$c)]

	if {$tcaption > 0} {
	    lappend res [string length $vTemplate(topdata,$c)]
	    if {($tcaption > 1) && $enabled(topdatasep)} {
		lappend res [string length $vTemplate(topdatasep,$c)]
	    }
	    if {$enabled(topcapsep)} {
		lappend res [string length $vTemplate(topcapsep,$c)]
	    }
	}
	if {$bcaption > 0} {
	    lappend res [string length $vTemplate(botdata,$c)]
	    if {($bcaption > 1) && $enabled(botdatasep)} {
		lappend res [string length $vTemplate(botdatasep,$c)]
	    }
	    if {$enabled(botcapsep)} {
		lappend res [string length $vTemplate(botcapsep,$c)]
	    }
	}
	foreach t {top datasep bottom} {
	    if {$enabled($t)} {
		lappend res [string length $vTemplate($t,$c)]
	    }
	}

	set res [lsort $res]

	if {[lindex $res 0] != [lindex $res end]} {
	    return -code error "inconsistent verticals in report"
	}
    }
}

# ::report::_tAction --
#
#	Implements the actions on templates (set, get, enable, disable, enabled)
#
# Arguments:
#	name		Name of the report object.
#	template	Name of the template to query or manipulate.
#	cmd		The action applied to the template
#	args		Additional arguments per action, see documentation.
#
# Results:
#	None.

proc ::report::_tAction {name template cmd args} {
    # When coming in here we know that $template contains a legal
    # template code. No need to check again. We need 'tcode'
    # nevertheless to distinguish between separator (1) and data
    # templates (0).

    variable tcode

    switch -exact -- $cmd {
	set {
	    if {[llength $args] != 1} {
		return -code error "Wrong # args: $name $template $cmd template"
	    }
	    set templval [lindex $args 0]

	    upvar ::report::report${name}::columns   columns
	    upvar ::report::report${name}::template  tpl
	    upvar ::report::report${name}::hTemplate hTemplate
	    upvar ::report::report${name}::vTemplate vTemplate
	    upvar ::report::report${name}::enabled   enabled	    

	    if {$tcode($template)} {
		# Separator template, expected size = 2*colums+1
		if {[llength $templval] > (2*$columns+1)} {
		    return -code error {template to long for number of columns in report}
		} elseif {[llength $templval] < (2*$columns+1)} {
		    return -code error {template to short for number of columns in report}
		}

		set tpl($template) $templval

		set even 1
		set c1   0
		set c2   0
		foreach item $templval {
		    if {$even} {
			set vTemplate($template,$c1) $item
			incr c1
			set even 0
		    } else {
			set hTemplate($template,$c2) $item
			incr c2
			set even 1
		    }
		}
	    } else {
		# Data template, expected size = columns+1
		if {[llength $templval] > ($columns+1)} {
		    return -code error {template to long for number of columns in report}
		} elseif {[llength $templval] < ($columns+1)} {
		    return -code error {template to short for number of columns in report}
		}

		set tpl($template) $templval

		set c 0
		foreach item $templval {
		    set vTemplate($template,$c) $item
		    incr c
		}
	    }
	    if {$enabled($template)} {
		# Perform checks for active separator templates and
		# all data templates.
		CheckVerticals $name
	    }
	}
	get -
	enable -
	disable -
	enabled {
	    if {[llength $args] > 0} {
		return -code error "Wrong # args: $name $template $cmd"
	    }
	    switch -exact -- $cmd {
		get {
		    upvar ::report::report${name}::template  tpl
		    return $tpl($template)
		}
		enable {
		    if {!$tcode($template)} {
			# Data template, can't be enabled.
			return -code error "Cannot enable data template \"$template\""
		    }

		    upvar ::report::report${name}::enabled enabled

		    if {!$enabled($template)} {
			set enabled($template) 1
			CheckVerticals $name
		    }

		}
		disable {
		    if {!$tcode($template)} {
			# Data template, can't be disabled.
			return -code error "Cannot disable data template \"$template\""
		    }

		    upvar ::report::report${name}::enabled enabled
		    if {$enabled($template)} {
			set enabled($template) 0
		    }
		}
		enabled {
		    if {!$tcode($template)} {
			# Data template, can't be disabled.
			return -code error "Cannot query state of data template \"$template\""
		    }

		    upvar ::report::report${name}::enabled enabled
		    return $enabled($template)
		}
		default {error "Can't happen, panic, run, shout"}
	    }
	}
	default {
	    return -code error "Unknown template command \"$cmd\""
	}
    }
    return ""
}

# ::report::_tcaption --
#
#	Sets or queries the size of the top caption region of the report.
#
# Arguments:
#	name	Name of the report object.
#	size	The new size, if not empty. Emptiness indicates that a
#		query was requested
#
# Results:
#	None, or the current size of the top caption region

proc ::report::_tcaption {name {size {}}} {
    upvar ::report::report${name}::tcaption tcaption

    if {$size == {}} {
	return $tcaption
    }
    if {![string is integer $size]} {
	return -code error "size: expected integer greater than or equal to zero, got \"$size\""
    }
    if {$size < 0} {
	return -code error "size: expected integer greater than or equal to zero, got \"$size\""
    }
    if {$size == $tcaption} {
	# No change, nothing to do
	return ""
    }
    if {($size > 0) && ($tcaption == 0)} {
	# Perform a consistency check after the assignment, the
	# template might have been changed.
	set tcaption $size
	CheckVerticals $name
    } else {
	set tcaption $size
    }
    return ""
}

# ::report::_bcaption --
#
#	Sets or queries the size of the bottom caption region of the report.
#
# Arguments:
#	name	Name of the report object.
#	size	The new size, if not empty. Emptiness indicates that a
#		query was requested
#
# Results:
#	None, or the current size of the bottom caption region

proc ::report::_bcaption {name {size {}}} {
    upvar ::report::report${name}::bcaption bcaption

    if {$size == {}} {
	return $bcaption
    }
    if {![string is integer $size]} {
	return -code error "size: expected integer greater than or equal to zero, got \"$size\""
    }
    if {$size < 0} {
	return -code error "size: expected integer greater than or equal to zero, got \"$size\""
    }
    if {$size == $bcaption} {
	# No change, nothing to do
	return ""
    }
    if {($size > 0) && ($bcaption == 0)} {
	# Perform a consistency check after the assignment, the
	# template might have been changed.
	set bcaption $size
	CheckVerticals $name
    } else {
	set bcaption $size
    }
    return ""
}

# ::report::_size --
#
#	Sets or queries the size of the specified column.
#
# Arguments:
#	name	Name of the report object.
#	column	Index of the column to manipulate or query
#	size	The new size, if not empty. Emptiness indicates that a
#		query was requested
#
# Results:
#	None, or the current size of the column

proc ::report::_size {name column {size {}}} {
    upvar ::report::report${name}::columns columns
    upvar ::report::report${name}::csize   csize

    set column [CheckColumn $columns $column]

    if {$size == {}} {
	return $csize($column)
    }
    if {[string equal $size dyn]} {
	set csize($column) $size
	return ""
    }
    if {![string is integer $size]} {
	return -code error "expected integer greater than zero, got \"$size\""
    }
    if {$size <= 0} {
	return -code error "expected integer greater than zero, got \"$size\""
    }
    set csize($column) $size
    return ""
}

# ::report::_sizes --
#
#	Sets or queries the sizes of all columns.
#
# Arguments:
#	name	Name of the report object.
#	sizes	The new sizes, if not empty. Emptiness indicates that a
#		query was requested
#
# Results:
#	None, or a list containing the sizes of all columns.

proc ::report::_sizes {name {sizes {}}} {
    upvar ::report::report${name}::columns columns
    upvar ::report::report${name}::csize   csize

    if {$sizes == {}} {
	set res [list]
	foreach k [lsort -integer [array names csize]] {
	    lappend res $csize($k)
	}
	return $res
    }
    if {[llength $sizes] != $columns} {
	return -code error "Wrong # number of column sizes"
    }
    foreach size $sizes {
	if {[string equal $size dyn]} {
	    continue
	}
	if {![string is integer $size]} {
	    return -code error "expected integer greater than zero, got \"$size\""
	}
	if {$size <= 0} {
	    return -code error "expected integer greater than zero, got \"$size\""
	}
    }

    set i 0
    foreach s $sizes {
	set csize($i) $s
	incr i
    }
    return ""
}

# ::report::_pad --
#
#	Sets or queries the padding for the specified column.
#
# Arguments:
#	name	Name of the report object.
#	column	Index of the column to manipulate or query
#	where	Where to place the padding. Emptiness indicates
#		that a query was requested.
#
# Results:
#	None, or the padding for the specified column.

proc ::report::_pad {name column {where {}} {string { }}} {
    upvar ::report::report${name}::columns columns
    upvar ::report::report${name}::lpad   lpad
    upvar ::report::report${name}::rpad   rpad

    set column [CheckColumn $columns $column]

    if {$where == {}} {
	return [list $lpad($column) $rpad($column)]
    }

    switch -exact -- $where {
	left {
	    set lpad($column) $string
	}
	right {
	    set rpad($column) $string
	}
	both {
	    set lpad($column) $string
	    set rpad($column) $string
	}
	default {
	    return -code error "where: expected left, right, or both, got \"$where\""
	}
    }
    return ""
}

# ::report::_justify --
#
#	Sets or queries the justification for the specified column.
#
# Arguments:
#	name	Name of the report object.
#	column	Index of the column to manipulate or query
#	jvalue	Justification to set. Emptiness indicates
#		that a query was requested
#
# Results:
#	None, or the current justication for the specified column

proc ::report::_justify {name column {jvalue {}}} {
    upvar ::report::report${name}::columns columns
    upvar ::report::report${name}::cjust   cjust

    set column [CheckColumn $columns $column]

    if {$jvalue == {}} {
	return $cjust($column)
    }
    switch -exact -- $jvalue {
	left - right - center {
	    set cjust($column) $jvalue
	    return ""
	}
	default {
	    return -code error "justification: expected, left, right, or center, got \"$jvalue\""
	}
    }
}

# ::report::_printmatrix --
#
#	Format the specified matrix according to the configuration of
#	the report.
#
# Arguments:
#	name	Name of the report object.
#	matrix	Name of the matrix object to format.
#
# Results:
#	A string containing the formatted matrix.

proc ::report::_printmatrix {name matrix} {
    CheckMatrix $name $matrix
    ColumnSizes $name $matrix state

    upvar ::report::report${name}::tcaption tcaption
    upvar ::report::report${name}::bcaption bcaption

    set    row 0
    set    out ""
    append out [Separator top $name $matrix state]
    if {$tcaption > 0} {
	set n $tcaption
	while {$n > 0} {
	    append out [FormatData topdata $name state [$matrix get row $row] [$matrix rowheight $row]]
	    if {$n > 1} {
		append out [Separator topdatasep $name $matrix state]
	    }
	    incr n -1
	    incr row
	}
	append out [Separator topcapsep $name $matrix state]
    }

    set n [expr {[$matrix rows] - $bcaption}]

    while {$row < $n} {
	append out [FormatData data $name state [$matrix get row $row] [$matrix rowheight $row]]
	incr row
	if {$row < $n} {
	    append out [Separator datasep $name $matrix state]
	}
    }

    if {$bcaption > 0} {
	append out [Separator botcapsep $name $matrix state]
	set n $bcaption
	while {$n > 0} {
	    append out [FormatData botdata $name state [$matrix get row $row] [$matrix rowheight $row]]
	    if {$n > 1} {
		append out [Separator botdatasep $name $matrix state]
	    }
	    incr n -1
	    incr row
	}
    }

    append out [Separator bottom $name $matrix state]

    #parray state
    return $out
}

# ::report::_printmatrix2channel --
#
#	Format the specified matrix according to the configuration of
#	the report.
#
# Arguments:
#	name	Name of the report.
#	matrix	Name of the matrix object to format.
#	chan	Handle of the channel to write the formatting result into.
#
# Results:
#	None.

proc ::report::_printmatrix2channel {name matrix chan} {
    CheckMatrix $name $matrix
    ColumnSizes $name $matrix state

    upvar ::report::report${name}::tcaption tcaption
    upvar ::report::report${name}::bcaption bcaption

    set    row 0
    puts -nonewline $chan [Separator top $name $matrix state]
    if {$tcaption > 0} {
	set n $tcaption
	while {$n > 0} {
	    puts -nonewline $chan \
		    [FormatData topdata $name state [$matrix get row $row] [$matrix rowheight $row]]
	    if {$n > 1} {
		puts -nonewline $chan [Separator topdatasep $name $matrix state]
	    }
	    incr n -1
	    incr row
	}
	puts -nonewline $chan [Separator topcapsep $name $matrix state]
    }

    set n [expr {[$matrix rows] - $bcaption}]

    while {$row < $n} {
	puts -nonewline $chan \
		[FormatData data $name state [$matrix get row $row] [$matrix rowheight $row]]
	incr row
	if {$row < $n} {
	    puts -nonewline $chan [Separator datasep $name $matrix state]
	}
    }

    if {$bcaption > 0} {
	puts -nonewline $chan [Separator botcapsep $name $matrix state]
	set n $bcaption
	while {$n > 0} {
	    puts -nonewline $chan \
		    [FormatData botdata $name state [$matrix get row $row] [$matrix rowheight $row]]
	    if {$n > 1} {
		puts -nonewline $chan [Separator botdatasep $name $matrix state]
	    }
	    incr n -1
	    incr row
	}
    }

    puts -nonewline $chan [Separator bottom $name $matrix state]
    return
}

# ::report::_columns --
#
#	Retrieves the number of columns in the report.
#
# Arguments:
#	name	Name of the report queried
#
# Results:
#	A number

proc ::report::_columns {name} {
    upvar ::report::report${name}::columns columns
    return $columns
}

# ::report::_destroy --
#
#	Destroy a report, including its associated command and data storage.
#
# Arguments:
#	name	Name of the report to destroy.
#
# Results:
#	None.

proc ::report::_destroy {name} {
    namespace delete ::report::report$name
    interp alias {} ::$name {}
    return
}

# ::report::CheckMatrix --
#
#	Internal helper for the "print" methods. Checks that the
#	supplied matrix can be formatted by the specified report.
#
# Arguments:
#	name	Name of the report to use for the formatting
#	matrix	Name of the matrix to format.
#
# Results:
#	None, or an error in case of problems.

proc ::report::CheckMatrix {name matrix} {
    upvar ::report::report${name}::columns  columns
    upvar ::report::report${name}::tcaption tcaption
    upvar ::report::report${name}::bcaption bcaption

    if {$columns != [$matrix columns]} {
	return -code error "report/matrix mismatch in number of columns"
    }
    if {($tcaption + $bcaption) > [$matrix rows]} {
	return -code error "matrix too small, top and bottom captions overlap"
    }
}

# ::report::ColumnSizes --
#
#	Internal helper for the "print" methods. Computes the final
#	column sizes (with and without padding) and stores them in
#	the print-state
#
# Arguments:
#	name		Name of the report used for the formatting
#	matrix		Name of the matrix to format.
#	statevar	Name of the array variable holding the state
#			of the formatter.
#
# Results:
#	None.

proc ::report::ColumnSizes {name matrix statevar} {
    # Calculate the final column sizes with and without padding and
    # store them in the local state.

    upvar $statevar state

    upvar ::report::report${name}::columns  columns
    upvar ::report::report${name}::csize    csize
    upvar ::report::report${name}::lpad     lpad
    upvar ::report::report${name}::rpad     rpad

    for {set c 0} {$c < $columns} {incr c} {
	if {[string equal dyn $csize($c)]} {
	    set size [$matrix columnwidth $c]
	} else {
	    set size $csize($c)
	}

	set state(s,$c) $size

	incr size [string length $lpad($c)]
	incr size [string length $rpad($c)]

	set state(s/pad,$c) $size
    }

    return
}

# ::report::Separator --
#
#	Internal helper for the "print" methods. Computes the final
#	shape of the various separators using the column sizes with
#	padding found in the print state. Uses also the print state as
#	a cache to avoid costly recomputation for the separators which
#	are used multiple times.
#
# Arguments:
#	tcode		Code of the separator to compute / template to use
#	name		Name of the report used for the formatting
#	matrix		Name of the matrix to format.
#	statevar	Name of the array variable holding the state
#			of the formatter.
#
# Results:
#	The final separator string. Empty for disabled separators.

proc ::report::Separator {tcode name matrix statevar} {
    upvar ::report::report${name}::enabled  e
    if {!$e($tcode)} {return ""}
    upvar $statevar state
    if {![info exists state($tcode)]} {
	upvar ::report::report${name}::vTemplate vt
	upvar ::report::report${name}::hTemplate ht
	upvar ::report::report${name}::columns   cs
	set str ""
	for {set c 0} {$c < $cs} {incr c} {
	    append str $vt($tcode,$c)
	    set fill $ht($tcode,$c)
	    set flen [string length $fill]
	    set rep  [expr {($state(s/pad,$c)/$flen)+1}]
	    append str [string range [string repeat $fill $rep] 0 [expr {$state(s/pad,$c)-1}]]
	}
	append str $vt($tcode,$cs)
	set state($tcode) $str
    }
    return $state($tcode)\n
}

# ::report::FormatData --
#
#	Internal helper for the "print" methods. Computes the output
#	for one row in the matrix, given its values, the rowheight,
#	padding and justification.
#
# Arguments:
#	tcode		Code of the data template to use
#	name		Name of the report used for the formatting
#	statevar	Name of the array variable holding the state
#			of the formatter.
#	line		List containing the values to format
#	rh		Height of the row (line) in lines.
#
# Results:
#	The formatted string for the supplied row.

proc ::report::FormatData {tcode name statevar line rh} {
    upvar $statevar state
    upvar ::report::report${name}::vTemplate vt
    upvar ::report::report${name}::columns   cs
    upvar ::report::report${name}::lpad      lpad
    upvar ::report::report${name}::rpad      rpad
    upvar ::report::report${name}::cjust     cjust

    if {$rh == 1} {
	set str ""
	set c 0
	foreach cell $line {
	    # prefix, cell (pad-l, value, pad-r)
	    append str $vt($tcode,$c)$lpad($c)[FormatCell $cell $state(s,$c) $cjust($c)]$rpad($c)
	    incr c
	}
	append str $vt($tcode,$cs)\n
	return $str
    } else {
	array set str {}
	for {set l 1} {$l <= $rh} {incr l} {set str($l) ""}

	# - Future - Vertical justification of cells less tall than rowheight
	# - Future - Vertical cutff aftert n lines, auto-repeat of captions
	# - Future - => Higher level, not here, use virtual matrices for this
	# - Future -  and count the generated lines

	set c 0
	foreach fcell $line {
	    set fcell [split $fcell \n]
	    for {set l 1; set lo 0} {$l <= $rh} {incr l; incr lo} {
		append str($l) $vt($tcode,$c)$lpad($c)[FormatCell \
			[lindex $fcell $lo] $state(s,$c) $cjust($c)]$rpad($c)
	    }
	    incr c
	}
	set strout ""
	for {set l 1} {$l <= $rh} {incr l} {
	    append strout $str($l)$vt($tcode,$cs)\n
	}
	return $strout
    }
}

# ::report::FormatCell --
#
#	Internal helper for the "print" methods. Formats the value of
#	a single cell according to column size and justification.
#
# Arguments:
#	value	The value to format
#	size	The size of the column, without padding
#	just	The justification for the current cell/column
#
# Results:
#	The formatted string for the supplied cell.

proc ::report::FormatCell {value size just} {
    set vlen [string length [StripAnsiColor $value]]

    if {$vlen == $size} {
	# Value fits exactly, justification is irrelevant
	return $value
    }

    # - Future - Other fill characters ...
    # - Future - Different fill characters per class of value => regex/glob pattern|functions
    # - Future - Wraparound - interacts with rowheight!

    switch -exact -- $just {
	left {
	    if {$vlen < $size} {
		return $value[string repeat " " [expr {$size - $vlen}]]
	    }
	    return [string range $value [expr {$vlen - $size}] end]
	}
	right {
	    if {$vlen < $size} {
		return [string repeat " " [expr {$size - $vlen}]]$value
	    }
	    incr size -1
	    return [string range $value 0 $size]
	}
	center {
	    if {$vlen < $size} {
		set fill  [expr {$size - $vlen}]
		set rfill [expr {$fill / 2}]
		set lfill [expr {$fill - $rfill}]
		return [string repeat " " $lfill]$value[string repeat " " $rfill]
	    }

	    set cut  [expr {$vlen - $size}]
	    set lcut [expr {$cut / 2}]
	    set rcut [expr {$cut - $lcut}]

	    return [string range $value $lcut end-$rcut]
	}
	default {
	    error "Can't happen, panic, run, shout"
	}
    }
}

proc ::report::StripAnsiColor {string} {
    # Look for ANSI color control sequences and remove them. Avoid
    # counting their characters as such sequences as a whole represent
    # a state change, and are logically of zero/no width.
    regsub -all "\033\\\[\[0-9;\]*m" $string {} string
    return $string
}