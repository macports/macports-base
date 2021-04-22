# matrix.tcl --
#
#	Implementation of a matrix data structure for Tcl.
#
# Copyright (c) 2001,2019 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# Heapsort code Copyright (c) 2003 by Edwin A. Suominen <ed@eepatents.com>,
# based on concepts in "Introduction to Algorithms" by Thomas H. Cormen et al.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.2

namespace eval ::struct {}

namespace eval ::struct::matrix {
    # Data storage in the matrix module
    # -------------------------------
    #
    # One namespace per object, containing
    #
    # - Two scalar variables containing the current number of rows and columns.
    # - Four array variables containing the array data, the caches for
    #   rowheights and columnwidths and the information about linked arrays.
    #
    # The variables are
    # - columns #columns in data
    # - rows    #rows in data
    # - data    cell contents
    # - colw    cache of columnwidths
    # - rowh    cache of rowheights
    # - link    information about linked arrays
    # - lock    boolean flag to disable MatTraceIn while in MatTraceOut [#532783]
    # - unset   string used to convey information about 'unset' traces from MatTraceIn to MatTraceOut.

    # counter is used to give a unique name for unnamed matrices
    variable counter 0

    # Only export one command, the one used to instantiate a new matrix
    namespace export matrix
}

# ::struct::matrix::matrix --
#
#	Create a new matrix with a given name; if no name is given, use
#	matrixX, where X is a number.
#
# Arguments:
#	name	Optional name of the matrix; if null or not given, generate one.
#
# Results:
#	name	Name of the matrix created

proc ::struct::matrix::matrix {{name ""}} {
    variable counter
    
    if { [llength [info level 0]] == 1 } {
	incr counter
	set name "matrix${counter}"
    }

    # FIRST, qualify the name.
    if {![string match "::*" $name]} {
        # Get caller's namespace; append :: if not global namespace.
        set ns [uplevel 1 namespace current]
        if {"::" != $ns} {
            append ns "::"
        }
        set name "$ns$name"
    }

    if { [llength [info commands $name]] } {
	return -code error "command \"$name\" already exists, unable to create matrix"
    }

    # Set up the namespace
    namespace eval $name {
	variable columns 0
	variable rows    0

	variable data
	variable colw
	variable rowh
	variable link
	variable lock
	variable unset

	array set data  {}
	array set colw  {}
	array set rowh  {}
	array set link  {}
	set       lock  0
	set       unset {}
    }

    # Create the command to manipulate the matrix
    interp alias {} $name {} ::struct::matrix::MatrixProc $name

    return $name
}

##########################
# Private functions follow

# ::struct::matrix::MatrixProc --
#
#	Command that processes all matrix object commands.
#
# Arguments:
#	name	Name of the matrix object to manipulate.
#	cmd	Subcommand to invoke.
#	args	Arguments for subcommand.
#
# Results:
#	Varies based on command to perform

proc ::struct::matrix::MatrixProc {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	return -code error "wrong # args: should be \"$name option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    set sub _$cmd
    if {[llength [info commands ::struct::matrix::$sub]] == 0} {
	set optlist [lsort [info commands ::struct::matrix::_*]]
	set xlist {}
	foreach p $optlist {
	    set p [namespace tail $p]
	    if {[string match __* $p]} {continue}
	    lappend xlist [string range $p 1 end]
	}
	set optlist [linsert [join $xlist ", "] "end-1" "or"]
	return -code error \
		"bad option \"$cmd\": must be $optlist"
    }
    uplevel 1 [linsert $args 0 ::struct::matrix::$sub $name]
}

# ::struct::matrix::_add --
#
#	Command that processes all 'add' subcommands.
#
# Arguments:
#	name	Name of the matrix object to manipulate.
#	cmd	Subcommand of 'add' to invoke.
#	args	Arguments for subcommand of 'add'.
#
# Results:
#	Varies based on command to perform

proc ::struct::matrix::_add {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	return -code error "wrong # args: should be \"$name add option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    set sub __add_$cmd
    if { [llength [info commands ::struct::matrix::$sub]] == 0 } {
	set optlist [lsort [info commands ::struct::matrix::__add_*]]
	set xlist {}
	foreach p $optlist {
	    set p [namespace tail $p]
	    lappend xlist [string range $p 6 end]
	}
	set optlist [linsert [join $xlist ", "] "end-1" "or"]
	return -code error \
		"bad option \"$cmd\": must be $optlist"
    }
    uplevel 1 [linsert $args 0 ::struct::matrix::$sub $name]
}

# ::struct::matrix::_delete --
#
#	Command that processes all 'delete' subcommands.
#
# Arguments:
#	name	Name of the matrix object to manipulate.
#	cmd	Subcommand of 'delete' to invoke.
#	args	Arguments for subcommand of 'delete'.
#
# Results:
#	Varies based on command to perform

proc ::struct::matrix::_delete {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	return -code error "wrong # args: should be \"$name delete option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    set sub __delete_$cmd
    if { [llength [info commands ::struct::matrix::$sub]] == 0 } {
	set optlist [lsort [info commands ::struct::matrix::__delete_*]]
	set xlist {}
	foreach p $optlist {
	    set p [namespace tail $p]
	    lappend xlist [string range $p 9 end]
	}
	set optlist [linsert [join $xlist ", "] "end-1" "or"]
	return -code error \
		"bad option \"$cmd\": must be $optlist"
    }
    uplevel 1 [linsert $args 0 ::struct::matrix::$sub $name]
}

# ::struct::matrix::_format --
#
#	Command that processes all 'format' subcommands.
#
# Arguments:
#	name	Name of the matrix object to manipulate.
#	cmd	Subcommand of 'format' to invoke.
#	args	Arguments for subcommand of 'format'.
#
# Results:
#	Varies based on command to perform

proc ::struct::matrix::_format {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	return -code error "wrong # args: should be \"$name format option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    set sub __format_$cmd
    if { [llength [info commands ::struct::matrix::$sub]] == 0 } {
	set optlist [lsort [info commands ::struct::matrix::__format_*]]
	set xlist {}
	foreach p $optlist {
	    set p [namespace tail $p]
	    lappend xlist [string range $p 9 end]
	}
	set optlist [linsert [join $xlist ", "] "end-1" "or"]
	return -code error \
		"bad option \"$cmd\": must be $optlist"
    }
    uplevel 1 [linsert $args 0 ::struct::matrix::$sub $name]
}

# ::struct::matrix::_get --
#
#	Command that processes all 'get' subcommands.
#
# Arguments:
#	name	Name of the matrix object to manipulate.
#	cmd	Subcommand of 'get' to invoke.
#	args	Arguments for subcommand of 'get'.
#
# Results:
#	Varies based on command to perform

proc ::struct::matrix::_get {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	return -code error "wrong # args: should be \"$name get option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    set sub __get_$cmd
    if { [llength [info commands ::struct::matrix::$sub]] == 0 } {
	set optlist [lsort [info commands ::struct::matrix::__get_*]]
	set xlist {}
	foreach p $optlist {
	    set p [namespace tail $p]
	    lappend xlist [string range $p 6 end]
	}
	set optlist [linsert [join $xlist ", "] "end-1" "or"]
	return -code error \
		"bad option \"$cmd\": must be $optlist"
    }
    uplevel 1 [linsert $args 0 ::struct::matrix::$sub $name]
}

# ::struct::matrix::_insert --
#
#	Command that processes all 'insert' subcommands.
#
# Arguments:
#	name	Name of the matrix object to manipulate.
#	cmd	Subcommand of 'insert' to invoke.
#	args	Arguments for subcommand of 'insert'.
#
# Results:
#	Varies based on command to perform

proc ::struct::matrix::_insert {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	return -code error "wrong # args: should be \"$name insert option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    set sub __insert_$cmd
    if { [llength [info commands ::struct::matrix::$sub]] == 0 } {
	set optlist [lsort [info commands ::struct::matrix::__insert_*]]
	set xlist {}
	foreach p $optlist {
	    set p [namespace tail $p]
	    lappend xlist [string range $p 9 end]
	}
	set optlist [linsert [join $xlist ", "] "end-1" "or"]
	return -code error \
		"bad option \"$cmd\": must be $optlist"
    }
    uplevel 1 [linsert $args 0 ::struct::matrix::$sub $name]
}

# ::struct::matrix::_search --
#
#	Command that processes all 'search' subcommands.
#
# Arguments:
#	name	Name of the matrix object to manipulate.
#	args	Arguments for search.
#
# Results:
#	Varies based on command to perform

proc ::struct::matrix::_search {name args} {
    set mode   exact
    set nocase 0

    while {1} {
	switch -glob -- [lindex $args 0] {
	    -exact - -glob - -regexp {
		set mode [string range [lindex $args 0] 1 end]
		set args [lrange $args 1 end]
	    }
	    -nocase {
		set nocase 1
	    }
	    -* {
		return -code error \
			"invalid option \"[lindex $args 0]\":\
			should be -nocase, -exact, -glob, or -regexp"
	    }
	    default {
		break
	    }
	}
    }

    # Possible argument signatures after option processing
    #
    # \ | args
    # --+--------------------------------------------------------
    # 2 | all pattern
    # 3 | row row pattern, column col pattern
    # 6 | rect ctl rtl cbr rbr pattern
    #
    # All range specifications are internally converted into a
    # rectangle.

    switch -exact -- [llength $args] {
	2 - 3 - 6 {}
	default {
	    return -code error \
		"wrong # args: should be\
		\"$name search ?option...? (all|row row|column col|rect c r c r) pattern\""
	}
    }

    set range   [lindex $args 0]
    set pattern [lindex $args end]
    set args    [lrange $args 1 end-1]

    variable ${name}::data
    variable ${name}::columns
    variable ${name}::rows

    switch -exact -- $range {
	all {
	    set ctl 0 ; set cbr $columns ; incr cbr -1
	    set rtl 0 ; set rbr $rows    ; incr rbr -1
	}
	column {
	    set ctl [ChkColumnIndex $name [lindex $args 0]]
	    set cbr $ctl
	    set rtl 0       ; set rbr $rows ; incr rbr -1
	}
	row {
	    set rtl [ChkRowIndex $name [lindex $args 0]]
	    set ctl 0    ; set cbr $columns ; incr cbr -1
	    set rbr $rtl
	}
	rect {
	    foreach {ctl rtl cbr rbr} $args break
	    set ctl [ChkColumnIndex $name $ctl]
	    set rtl [ChkRowIndex    $name $rtl]
	    set cbr [ChkColumnIndex $name $cbr]
	    set rbr [ChkRowIndex    $name $rbr]
	    if {($ctl > $cbr) || ($rtl > $rbr)} {
		return -code error "Invalid cell indices, wrong ordering"
	    }
	}
	default {
	    return -code error "invalid range spec \"$range\": should be all, column, row, or rect"
	}
    }

    if {$nocase} {
	set pattern [string tolower $pattern]
    }

    set matches [list]
    for {set r $rtl} {$r <= $rbr} {incr r} {
	for {set c $ctl} {$c <= $cbr} {incr c} {
	    set v  $data($c,$r)
	    if {$nocase} {
		set v [string tolower $v]
	    }
	    switch -exact -- $mode {
		exact  {set matched [string equal $pattern $v]}
		glob   {set matched [string match $pattern $v]}
		regexp {set matched [regexp --    $pattern $v]}
	    }
	    if {$matched} {
		lappend matches [list $c $r]
	    }
	}
    }
    return $matches
}

# ::struct::matrix::_set --
#
#	Command that processes all 'set' subcommands.
#
# Arguments:
#	name	Name of the matrix object to manipulate.
#	cmd	Subcommand of 'set' to invoke.
#	args	Arguments for subcommand of 'set'.
#
# Results:
#	Varies based on command to perform

proc ::struct::matrix::_set {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	return -code error "wrong # args: should be \"$name set option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    set sub __set_$cmd
    if { [llength [info commands ::struct::matrix::$sub]] == 0 } {
	set optlist [lsort [info commands ::struct::matrix::__set_*]]
	set xlist {}
	foreach p $optlist {
	    set p [namespace tail $p]
	    lappend xlist [string range $p 6 end]
	}
	set optlist [linsert [join $xlist ", "] "end-1" "or"]
	return -code error \
		"bad option \"$cmd\": must be $optlist"
    }
    uplevel 1 [linsert $args 0 ::struct::matrix::$sub $name]
}

# ::struct::matrix::_sort --
#
#	Command that processes all 'sort' subcommands.
#
# Arguments:
#	name	Name of the matrix object to manipulate.
#	cmd	Subcommand of 'sort' to invoke.
#	args	Arguments for subcommand of 'sort'.
#
# Results:
#	Varies based on command to perform

proc ::struct::matrix::_sort {name cmd args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	return -code error "wrong # args: should be \"$name sort option ?arg arg ...?\""
    }
    if {[string equal $cmd "rows"]} {
	set code   r
	set byrows 1
    } elseif {[string equal $cmd "columns"]} {
	set code   c
	set byrows 0
    } else {
	return -code error \
		"bad option \"$cmd\": must be columns, or rows"
    }

    set revers 0 ;# Default: -increasing
    while {1} {
	switch -glob -- [lindex $args 0] {
	    -increasing {set revers 0}
	    -decreasing {set revers 1}
	    default {
		if {[llength $args] > 1} {
		    return -code error \
			"invalid option \"[lindex $args 0]\":\
			should be -increasing, or -decreasing"
		}
		break
	    }
	}
	set args [lrange $args 1 end]
    }
    # ASSERT: [llength $args] == 1

    if {[llength $args] != 1} {
	return -code error "wrong # args: should be \"$name sort option ?arg arg ...?\""
    }

    set key [lindex $args 0]

    if {$byrows} {
	set key [ChkColumnIndex $name $key]
	variable ${name}::rows

	# Adapted by EAS from BUILD-MAX-HEAP(A) of CRLS 6.3
	set heapSize $rows
    } else {
	set key [ChkRowIndex $name $key]
	variable ${name}::columns

	# Adapted by EAS from BUILD-MAX-HEAP(A) of CRLS 6.3
	set heapSize $columns
    }

    for {set i [expr {int($heapSize/2)-1}]} {$i>=0} {incr i -1} {
	SortMaxHeapify $name $i $key $code $heapSize $revers
    }

    # Adapted by EAS from remainder of HEAPSORT(A) of CRLS 6.4
    for {set i [expr {$heapSize-1}]} {$i>=1} {incr i -1} {
	if {$byrows} {
	    SwapRows $name 0 $i
	} else {
	    SwapColumns $name 0 $i
	}
	incr heapSize -1
	SortMaxHeapify $name 0 $key $code $heapSize $revers
    }
    return
}

# ::struct::matrix::_swap --
#
#	Command that processes all 'swap' subcommands.
#
# Arguments:
#	name	Name of the matrix object to manipulate.
#	cmd	Subcommand of 'swap' to invoke.
#	args	Arguments for subcommand of 'swap'.
#
# Results:
#	Varies based on command to perform

proc ::struct::matrix::_swap {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	return -code error "wrong # args: should be \"$name swap option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    set sub __swap_$cmd
    if { [llength [info commands ::struct::matrix::$sub]] == 0 } {
	set optlist [lsort [info commands ::struct::matrix::__swap_*]]
	set xlist {}
	foreach p $optlist {
	    set p [namespace tail $p]
	    lappend xlist [string range $p 7 end]
	}
	set optlist [linsert [join $xlist ", "] "end-1" "or"]
	return -code error \
		"bad option \"$cmd\": must be $optlist"
    }
    uplevel 1 [linsert $args 0 ::struct::matrix::$sub $name]
}

# ::struct::matrix::__add_column --
#
#	Extends the matrix by one column and then acts like
#	"setcolumn" (see below) on this new column if there were
#	"values" supplied. Without "values" the new cells will be set
#	to the empty string. The new column is appended immediately
#	behind the last existing column.
#
# Arguments:
#	name	Name of the matrix object.
#	values	Optional values to set into the new row.
#
# Results:
#	None.

proc ::struct::matrix::__add_column {name {values {}}} {
    variable ${name}::data
    variable ${name}::columns
    variable ${name}::rows
    variable ${name}::rowh

    if {[set l [llength $values]] < $rows} {
	# Missing values. Fill up with empty strings

	for {} {$l < $rows} {incr l} {
	    lappend values {}
	}
    } elseif {[llength $values] > $rows} {
	# To many values. Remove the superfluous items
	set values [lrange $values 0 [expr {$rows - 1}]]
    }

    # "values" now contains the information to set into the array.
    # Regarding the width and height caches:

    # - The new column is not added to the width cache, the other
    #   columns are not touched, the cache therefore unchanged.
    # - The rows are either removed from the height cache or left
    #   unchanged, depending on the contents set into the cell.

    set r 0
    foreach v $values {
	if {$v != {}} {
	    # Data changed unpredictably, invalidate cache
	    catch {unset rowh($r)}
	} ; # {else leave the row unchanged}
	set data($columns,$r) $v
	incr r
    }
    incr columns
    return
}

# ::struct::matrix::__add_row --
#
#	Extends the matrix by one row and then acts like "setrow" (see
#	below) on this new row if there were "values"
#	supplied. Without "values" the new cells will be set to the
#	empty string. The new row is appended immediately behind the
#	last existing row.
#
# Arguments:
#	name	Name of the matrix object.
#	values	Optional values to set into the new row.
#
# Results:
#	None.

proc ::struct::matrix::__add_row {name {values {}}} {
    variable ${name}::data
    variable ${name}::columns
    variable ${name}::rows
    variable ${name}::colw

    if {[set l [llength $values]] < $columns} {
	# Missing values. Fill up with empty strings

	for {} {$l < $columns} {incr l} {
	    lappend values {}
	}
    } elseif {[llength $values] > $columns} {
	# To many values. Remove the superfluous items
	set values [lrange $values 0 [expr {$columns - 1}]]
    }

    # "values" now contains the information to set into the array.
    # Regarding the width and height caches:

    # - The new row is not added to the height cache, the other
    #   rows are not touched, the cache therefore unchanged.
    # - The columns are either removed from the width cache or left
    #   unchanged, depending on the contents set into the cell.

    set c 0
    foreach v $values {
	if {$v != {}} {
	    # Data changed unpredictably, invalidate cache
	    catch {unset colw($c)}
	} ; # {else leave the row unchanged}
	set data($c,$rows) $v
	incr c
    }
    incr rows
    return
}

# ::struct::matrix::__add_columns --
#
#	Extends the matrix by "n" columns. The new cells will be set
#	to the empty string. The new columns are appended immediately
#	behind the last existing column. A value of "n" equal to or
#	smaller than 0 is not allowed.
#
# Arguments:
#	name	Name of the matrix object.
#	n	The number of new columns to create.
#
# Results:
#	None.

proc ::struct::matrix::__add_columns {name n} {
    if {$n <= 0} {
	return -code error "A value of n <= 0 is not allowed"
    }

    variable ${name}::data
    variable ${name}::columns
    variable ${name}::rows

    # The new values set into the cell is always the empty
    # string. These have a length and height of 0, i.e. the don't
    # influence cached widths and heights as they are at least that
    # big. IOW there is no need to touch and change the width and
    # height caches.

    while {$n > 0} {
	for {set r 0} {$r < $rows} {incr r} {
	    set data($columns,$r) ""
	}
	incr columns
	incr n -1
    }

    return
}

# ::struct::matrix::__add_rows --
#
#	Extends the matrix by "n" rows. The new cells will be set to
#	the empty string. The new rows are appended immediately behind
#	the last existing row. A value of "n" equal to or smaller than
#	0 is not allowed.
#
# Arguments:
#	name	Name of the matrix object.
#	n	The number of new rows to create.
#
# Results:
#	None.

proc ::struct::matrix::__add_rows {name n} {
    if {$n <= 0} {
	return -code error "A value of n <= 0 is not allowed"
    }

    variable ${name}::data
    variable ${name}::columns
    variable ${name}::rows

    # The new values set into the cell is always the empty
    # string. These have a length and height of 0, i.e. the don't
    # influence cached widths and heights as they are at least that
    # big. IOW there is no need to touch and change the width and
    # height caches.

    while {$n > 0} {
	for {set c 0} {$c < $columns} {incr c} {
	    set data($c,$rows) ""
	}
	incr rows
	incr n -1
    }
    return
}

# ::struct::matrix::_cells --
#
#	Returns the number of cells currently managed by the
#	matrix. This is the product of "rows" and "columns".
#
# Arguments:
#	name	Name of the matrix object.
#
# Results:
#	The number of cells in the matrix.

proc ::struct::matrix::_cells {name} {
    variable ${name}::rows
    variable ${name}::columns
    return [expr {$rows * $columns}]
}

# ::struct::matrix::_cellsize --
#
#	Returns the length of the string representation of the value
#	currently contained in the addressed cell.
#
# Arguments:
#	name	Name of the matrix object.
#	column	Column index of the cell to query
#	row	Row index of the cell to query
#
# Results:
#	The number of cells in the matrix.

proc ::struct::matrix::_cellsize {name column row} {
    set column [ChkColumnIndex $name $column]
    set row    [ChkRowIndex    $name $row]

    variable ${name}::data
    return [string length $data($column,$row)]
}

# ::struct::matrix::_columns --
#
#	Returns the number of columns currently managed by the
#	matrix.
#
# Arguments:
#	name	Name of the matrix object.
#
# Results:
#	The number of columns in the matrix.

proc ::struct::matrix::_columns {name} {
    variable ${name}::columns
    return $columns
}

# ::struct::matrix::_columnwidth --
#
#	Returns the length of the longest string representation of all
#	the values currently contained in the cells of the addressed
#	column if these are all spanning only one line. For cell
#	values spanning multiple lines the length of their longest
#	line goes into the computation.
#
# Arguments:
#	name	Name of the matrix object.
#	column	The index of the column whose width is asked for.
#
# Results:
#	See description.

proc ::struct::matrix::_columnwidth {name column} {
    set column [ChkColumnIndex $name $column]

    variable ${name}::colw

    if {![info exists colw($column)]} {
	variable ${name}::rows
	variable ${name}::data

	set width 0
	for {set r 0} {$r < $rows} {incr r} {
	    foreach line [split $data($column,$r) \n] {
		set len [string length $line]
		if {$len > $width} {
		    set width $len
		}
	    }
	}

	set colw($column) $width
    }

    return $colw($column)
}

# ::struct::matrix::__delete_column --
#
#	Deletes the specified column from the matrix and shifts all
#	columns with higher indices one index down.
#
# Arguments:
#	name	Name of the matrix.
#	column	The index of the column to delete.
#
# Results:
#	None.

proc ::struct::matrix::__delete_column {name column} {
    set column [ChkColumnIndex $name $column]

    variable ${name}::data
    variable ${name}::rows
    variable ${name}::columns
    variable ${name}::colw
    variable ${name}::rowh

    # Move all data from the higher columns down and then delete the
    # superfluous data in the old last column. Move the data in the
    # width cache too, take partial fill into account there too.
    # Invalidate the height cache for all rows.

    for {set r 0} {$r < $rows} {incr r} {
	for {set c $column; set cn [expr {$c + 1}]} {$cn < $columns} {incr c ; incr cn} {
	    set data($c,$r) $data($cn,$r)
	    if {[info exists colw($cn)]} {
		set colw($c) $colw($cn)
		unset colw($cn)
	    }
	}
	unset data($c,$r)
	catch {unset rowh($r)}
    }
    incr columns -1
    return
}

# ::struct::matrix::__delete_row --
#
#	Deletes the specified row from the matrix and shifts all
#	row with higher indices one index down.
#
# Arguments:
#	name	Name of the matrix.
#	row	The index of the row to delete.
#
# Results:
#	None.

proc ::struct::matrix::__delete_row {name row} {
    set row [ChkRowIndex $name $row]

    variable ${name}::data
    variable ${name}::rows
    variable ${name}::columns
    variable ${name}::colw
    variable ${name}::rowh

    # Move all data from the higher rows down and then delete the
    # superfluous data in the old last row. Move the data in the
    # height cache too, take partial fill into account there too.
    # Invalidate the width cache for all columns.

    for {set c 0} {$c < $columns} {incr c} {
	for {set r $row; set rn [expr {$r + 1}]} {$rn < $rows} {incr r ; incr rn} {
	    set data($c,$r) $data($c,$rn)
	    if {[info exists rowh($rn)]} {
		set rowh($r) $rowh($rn)
		unset rowh($rn)
	    }
	}
	unset data($c,$r)
	catch {unset colw($c)}
    }
    incr rows -1
    return
}

# ::struct::matrix::_destroy --
#
#	Destroy a matrix, including its associated command and data storage.
#
# Arguments:
#	name	Name of the matrix to destroy.
#
# Results:
#	None.

proc ::struct::matrix::_destroy {name} {
    variable ${name}::link

    # Unlink all existing arrays before destroying the object so that
    # we don't leave dangling references / traces.

    foreach avar [array names link] {
	_unlink $name $avar
    }

    namespace delete $name
    interp alias {}  $name {}
}

# ::struct::matrix::__format_2string --
#
#	Formats the matrix using the specified report object and
#	returns the string containing the result of this
#	operation. The report has to support the "printmatrix" method.
#
# Arguments:
#	name	Name of the matrix.
#	report	Name of the report object specifying the formatting.
#
# Results:
#	A string containing the formatting result.

proc ::struct::matrix::__format_2string {name {report {}}} {
    if {$report == {}} {
	# Use an internal hardwired simple report to format the matrix.
	# 1. Go through all columns and compute the column widths.
	# 2. Then iterate through all rows and dump then into a
	#    string, formatted to the number of characters per columns

	array set cw {}
	set cols [_columns $name]
	for {set c 0} {$c < $cols} {incr c} {
	    set cw($c) [_columnwidth $name $c]
	}

	set result [list]
	set n [_rows $name]
	for {set r 0} {$r < $n} {incr r} {
	    set rh [_rowheight $name $r]
	    if {$rh < 2} {
		# Simple row.
		set line [list]
		for {set c 0} {$c < $cols} {incr c} {
		    set val [__get_cell $name $c $r]
		    lappend line "$val[string repeat " " [expr {$cw($c)-[string length $val]}]]"
		}
		lappend result [join $line " "]
	    } else {
		# Complex row, multiple passes
		for {set h 0} {$h < $rh} {incr h} {
		    set line [list]
		    for {set c 0} {$c < $cols} {incr c} {
			set val [lindex [split [__get_cell $name $c $r] \n] $h]
			lappend line "$val[string repeat " " [expr {$cw($c)-[string length $val]}]]"
		    }
		    lappend result [join $line " "]
		}
	    }
	}
	return [join $result \n]
    } else {
	return [$report printmatrix $name]
    }
}

# ::struct::matrix::__format_2chan --
#
#	Formats the matrix using the specified report object and
#	writes the string containing the result of this operation into
#	the channel. The report has to support the
#	"printmatrix2channel" method.
#
# Arguments:
#	name	Name of the matrix.
#	report	Name of the report object specifying the formatting.
#	chan	Handle of the channel to write to.
#
# Results:
#	None.

proc ::struct::matrix::__format_2chan {name {report {}} {chan stdout}} {
    if {$report == {}} {
	# Use an internal hardwired simple report to format the matrix.
	# We delegate this to the string formatter and print its result.
	puts -nonewline $chan [__format_2string $name]
    } else {
	$report printmatrix2channel $name $chan
    }
    return
}

# ::struct::matrix::__get_cell --
#
#	Returns the value currently contained in the cell identified
#	by row and column index.
#
# Arguments:
#	name	Name of the matrix.
#	column	Column index of the addressed cell.
#	row	Row index of the addressed cell.
#
# Results:
#	value	Value currently stored in the addressed cell.

proc ::struct::matrix::__get_cell {name column row} {
    set column [ChkColumnIndex $name $column]
    set row    [ChkRowIndex    $name $row]

    variable ${name}::data
    return $data($column,$row)
}

# ::struct::matrix::__get_column --
#
#	Returns a list containing the values from all cells in the
#	column identified by the index. The contents of the cell in
#	row 0 are stored as the first element of this list.
#
# Arguments:
#	name	Name of the matrix.
#	column	Column index of the addressed cell.
#
# Results:
#	List of values stored in the addressed row.

proc ::struct::matrix::__get_column {name column} {
    set column [ChkColumnIndex $name $column]
    return     [GetColumn      $name $column]
}

proc ::struct::matrix::GetColumn {name column} {
    variable ${name}::data
    variable ${name}::rows

    set result [list]
    for {set r 0} {$r < $rows} {incr r} {
	lappend result $data($column,$r)
    }
    return $result
}

# ::struct::matrix::__get_rect --
#
#	Returns a list of lists of cell values. The values stored in
#	the result come from the submatrix whose top-left and
#	bottom-right cells are specified by "column_tl", "row_tl" and
#	"column_br", "row_br" resp. Note that the following equations
#	have to be true: column_tl <= column_br and row_tl <= row_br.
#	The result is organized as follows: The outer list is the list
#	of rows, its elements are lists representing a single row. The
#	row with the smallest index is the first element of the outer
#	list. The elements of the row lists represent the selected
#	cell values. The cell with the smallest index is the first
#	element in each row list.
#
# Arguments:
#	name		Name of the matrix.
#	column_tl	Column index of the top-left cell of the area.
#	row_tl		Row index of the top-left cell of the the area
#	column_br	Column index of the bottom-right cell of the area.
#	row_br		Row index of the bottom-right cell of the the area
#
# Results:
#	List of a list of values stored in the addressed area.

proc ::struct::matrix::__get_rect {name column_tl row_tl column_br row_br} {
    set column_tl [ChkColumnIndex $name $column_tl]
    set row_tl    [ChkRowIndex    $name $row_tl]
    set column_br [ChkColumnIndex $name $column_br]
    set row_br    [ChkRowIndex    $name $row_br]

    if {
	($column_tl > $column_br) ||
	($row_tl    > $row_br)
    } {
	return -code error "Invalid cell indices, wrong ordering"
    }

    variable ${name}::data
    set result [list]

    for {set r $row_tl} {$r <= $row_br} {incr r} {
	set row [list]
	for {set c $column_tl} {$c <= $column_br} {incr c} {
	    lappend row $data($c,$r)
	}
	lappend result $row
    }

    return $result
}

# ::struct::matrix::__get_row --
#
#	Returns a list containing the values from all cells in the
#	row identified by the index. The contents of the cell in
#	column 0 are stored as the first element of this list.
#
# Arguments:
#	name	Name of the matrix.
#	row	Row index of the addressed cell.
#
# Results:
#	List of values stored in the addressed row.

proc ::struct::matrix::__get_row {name row} {
    set row [ChkRowIndex $name $row]
    return  [GetRow      $name $row]
}

proc ::struct::matrix::GetRow {name row} {
    variable ${name}::data
    variable ${name}::columns

    set result [list]
    for {set c 0} {$c < $columns} {incr c} {
	lappend result $data($c,$row)
    }
    return $result
}

# ::struct::matrix::__insert_column --
#
#	Extends the matrix by one column and then acts like
#	"setcolumn" (see below) on this new column if there were
#	"values" supplied. Without "values" the new cells will be set
#	to the empty string. The new column is inserted just before
#	the column specified by the given index. This means, if
#	"column" is less than or equal to zero, then the new column is
#	inserted at the beginning of the matrix, before the first
#	column. If "column" has the value "Bend", or if it is greater
#	than or equal to the number of columns in the matrix, then the
#	new column is appended to the matrix, behind the last
#	column. The old column at the chosen index and all columns
#	with higher indices are shifted one index upward.
#
# Arguments:
#	name	Name of the matrix.
#	column	Index of the column where to insert.
#	values	Optional values to set the cells to.
#
# Results:
#	None.

proc ::struct::matrix::__insert_column {name column {values {}}} {
    # Allow both negative and too big indices.
    set column [ChkColumnIndexAll $name $column]

    variable ${name}::columns

    if {$column > $columns} {
	# Same as 'addcolumn'
	__add_column $name $values
	return
    }

    variable ${name}::data
    variable ${name}::rows
    variable ${name}::rowh
    variable ${name}::colw

    set firstcol $column
    if {$firstcol < 0} {
	set firstcol 0
    }

    if {[set l [llength $values]] < $rows} {
	# Missing values. Fill up with empty strings

	for {} {$l < $rows} {incr l} {
	    lappend values {}
	}
    } elseif {[llength $values] > $rows} {
	# To many values. Remove the superfluous items
	set values [lrange $values 0 [expr {$rows - 1}]]
    }

    # "values" now contains the information to set into the array.
    # Regarding the width and height caches:
    # Invalidate all rows, move all columns

    # Move all data from the higher columns one up and then insert the
    # new data into the freed space. Move the data in the
    # width cache too, take partial fill into account there too.
    # Invalidate the height cache for all rows.

    for {set r 0} {$r < $rows} {incr r} {
	for {set cn $columns ; set c [expr {$cn - 1}]} {$c >= $firstcol} {incr c -1 ; incr cn -1} {
	    set data($cn,$r) $data($c,$r)
	    if {[info exists colw($c)]} {
		set colw($cn) $colw($c)
		unset colw($c)
	    }
	}
	set data($firstcol,$r) [lindex $values $r]
	catch {unset rowh($r)}
    }
    incr columns
    return
}

# ::struct::matrix::__insert_row --
#
#	Extends the matrix by one row and then acts like "setrow" (see
#	below) on this new row if there were "values"
#	supplied. Without "values" the new cells will be set to the
#	empty string. The new row is inserted just before the row
#	specified by the given index. This means, if "row" is less
#	than or equal to zero, then the new row is inserted at the
#	beginning of the matrix, before the first row. If "row" has
#	the value "end", or if it is greater than or equal to the
#	number of rows in the matrix, then the new row is appended to
#	the matrix, behind the last row. The old row at that index and
#	all rows with higher indices are shifted one index upward.
#
# Arguments:
#	name	Name of the matrix.
#	row	Index of the row where to insert.
#	values	Optional values to set the cells to.
#
# Results:
#	None.

proc ::struct::matrix::__insert_row {name row {values {}}} {
    # Allow both negative and too big indices.
    set row [ChkRowIndexAll $name $row]

    variable ${name}::rows

    if {$row > $rows} {
	# Same as 'addrow'
	__add_row $name $values
	return
    }

    variable ${name}::data
    variable ${name}::columns
    variable ${name}::rowh
    variable ${name}::colw

    set firstrow $row
    if {$firstrow < 0} {
	set firstrow 0
    }

    if {[set l [llength $values]] < $columns} {
	# Missing values. Fill up with empty strings

	for {} {$l < $columns} {incr l} {
	    lappend values {}
	}
    } elseif {[llength $values] > $columns} {
	# To many values. Remove the superfluous items
	set values [lrange $values 0 [expr {$columns - 1}]]
    }

    # "values" now contains the information to set into the array.
    # Regarding the width and height caches:
    # Invalidate all columns, move all rows

    # Move all data from the higher rows one up and then insert the
    # new data into the freed space. Move the data in the
    # height cache too, take partial fill into account there too.
    # Invalidate the width cache for all columns.

    for {set c 0} {$c < $columns} {incr c} {
	for {set rn $rows ; set r [expr {$rn - 1}]} {$r >= $firstrow} {incr r -1 ; incr rn -1} {
	    set data($c,$rn) $data($c,$r)
	    if {[info exists rowh($r)]} {
		set rowh($rn) $rowh($r)
		unset rowh($r)
	    }
	}
	set data($c,$firstrow) [lindex $values $c]
	catch {unset colw($c)}
    }
    incr rows
    return
}

# ::struct::matrix::_link --
#
#	Links the matrix to the specified array variable. This means
#	that the contents of all cells in the matrix is stored in the
#	array too, with all changes to the matrix propagated there
#	too. The contents of the cell "(column,row)" is stored in the
#	array using the key "column,row". If the option "-transpose"
#	is specified the key "row,column" will be used instead. It is
#	possible to link the matrix to more than one array. Note that
#	the link is bidirectional, i.e. changes to the array are
#	mirrored in the matrix too.
#
# Arguments:
#	name	Name of the matrix object.
#	option	Either empty of '-transpose'.
#	avar	Name of the variable to link to
#
# Results:
#	None

proc ::struct::matrix::_link {name args} {
    switch -exact -- [llength $args] {
	0 {
	    return -code error "$name: wrong # args: link ?-transpose? arrayvariable"
	}
	1 {
	    set transpose 0
	    set variable  [lindex $args 0]
	}
	2 {
	    foreach {t variable} $args break
	    if {[string compare $t -transpose]} {
		return -code error "$name: illegal syntax: link ?-transpose? arrayvariable"
	    }
	    set transpose 1
	}
	default {
	    return -code error "$name: wrong # args: link ?-transpose? arrayvariable"
	}
    }

    variable ${name}::link

    if {[info exists link($variable)]} {
	return -code error "$name link: Variable \"$variable\" already linked to matrix"
    }

    # Ok, a new variable we are linked to. Record this information,
    # dump our current contents into the array, at last generate the
    # traces actually performing the link.

    set link($variable) $transpose

    upvar #0 $variable array
    variable ${name}::data

    foreach key [array names data] {
	foreach {c r} [split $key ,] break
	if {$transpose} {
	    set array($r,$c) $data($key)
	} else {
	    set array($c,$r) $data($key)
	}
    }

    trace variable array wu [list ::struct::matrix::MatTraceIn  $variable $name]
    trace variable data  w  [list ::struct::matrix::MatTraceOut $variable $name]
    return
}

# ::struct::matrix::_links --
#
#	Retrieves the names of all array variable the matrix is
#	officialy linked to.
#
# Arguments:
#	name	Name of the matrix object.
#
# Results:
#	List of variables the matrix is linked to.

proc ::struct::matrix::_links {name} {
    variable ${name}::link
    return [array names link]
}

# ::struct::matrix::_rowheight --
#
#	Returns the height of the specified row in lines. This is the
#	highest number of lines spanned by a cell over all cells in
#	the row.
#
# Arguments:
#	name	Name of the matrix
#	row	Index of the row queried for its height
#
# Results:
#	The height of the specified row in lines.

proc ::struct::matrix::_rowheight {name row} {
    set row [ChkRowIndex $name $row]

    variable ${name}::rowh

    if {![info exists rowh($row)]} {
	variable ${name}::columns
	variable ${name}::data

	set height 1
	for {set c 0} {$c < $columns} {incr c} {
	    set cheight [llength [split $data($c,$row) \n]]
	    if {$cheight > $height} {
		set height $cheight
	    }
	}

	set rowh($row) $height
    }
    return $rowh($row)
}

# ::struct::matrix::_rows --
#
#	Returns the number of rows currently managed by the matrix.
#
# Arguments:
#	name	Name of the matrix object.
#
# Results:
#	The number of rows in the matrix.

proc ::struct::matrix::_rows {name} {
    variable ${name}::rows
    return $rows
}

# ::struct::matrix::__set_cell --
#
#	Sets the value in the cell identified by row and column index
#	to the data in the third argument.
#
# Arguments:
#	name	Name of the matrix object.
#	column	Column index of the cell to set.
#	row	Row index of the cell to set.
#	value	THe new value of the cell.
#
# Results:
#	None.
 
proc ::struct::matrix::__set_cell {name column row value} {
    set column [ChkColumnIndex $name $column]
    set row    [ChkRowIndex    $name $row]

    variable ${name}::data

    if {![string compare $value $data($column,$row)]} {
	# No change, ignore call!
	return
    }

    set data($column,$row) $value

    if {$value != {}} {
	variable ${name}::colw
	variable ${name}::rowh
	catch {unset colw($column)}
	catch {unset rowh($row)}
    }
    return
}

# ::struct::matrix::__set_column --
#
#	Sets the values in the cells identified by the column index to
#	the elements of the list provided as the third argument. Each
#	element of the list is assigned to one cell, with the first
#	element going into the cell in row 0 and then upward. If there
#	are less values in the list than there are rows the remaining
#	rows are set to the empty string. If there are more values in
#	the list than there are rows the superfluous elements are
#	ignored. The matrix is not extended by this operation.
#
# Arguments:
#	name	Name of the matrix.
#	column	Index of the column to set.
#	values	Values to set into the column.
#
# Results:
#	None.

proc ::struct::matrix::__set_column {name column values} {
    set column [ChkColumnIndex $name $column]

    variable ${name}::data
    variable ${name}::columns
    variable ${name}::rows
    variable ${name}::rowh
    variable ${name}::colw

    if {[set l [llength $values]] < $rows} {
	# Missing values. Fill up with empty strings

	for {} {$l < $rows} {incr l} {
	    lappend values {}
	}
    } elseif {[llength $values] > $rows} {
	# To many values. Remove the superfluous items
	set values [lrange $values 0 [expr {$rows - 1}]]
    }

    # "values" now contains the information to set into the array.
    # Regarding the width and height caches:

    # - Invalidate the column in the width cache.
    # - The rows are either removed from the height cache or left
    #   unchanged, depending on the contents set into the cell.

    set r 0
    foreach v $values {
	if {$v != {}} {
	    # Data changed unpredictably, invalidate cache
	    catch {unset rowh($r)}
	} ; # {else leave the row unchanged}
	set data($column,$r) $v
	incr r
    }
    catch {unset colw($column)}
    return
}

# ::struct::matrix::__set_rect --
#
#	Takes a list of lists of cell values and writes them into the
#	submatrix whose top-left cell is specified by the two
#	indices. If the sublists of the outerlist are not of equal
#	length the shorter sublists will be filled with empty strings
#	to the length of the longest sublist. If the submatrix
#	specified by the top-left cell and the number of rows and
#	columns in the "values" extends beyond the matrix we are
#	modifying the over-extending parts of the values are ignored,
#	i.e. essentially cut off. This subcommand expects its input in
#	the format as returned by "getrect".
#
# Arguments:
#	name	Name of the matrix object.
#	column	Column index of the topleft cell to set.
#	row	Row index of the topleft cell to set.
#	values	Values to set.
#
# Results:
#	None.

proc ::struct::matrix::__set_rect {name column row values} {
    # Allow negative indices!
    set column [ChkColumnIndexNeg $name $column]
    set row    [ChkRowIndexNeg    $name $row]

    variable ${name}::data
    variable ${name}::columns
    variable ${name}::rows
    variable ${name}::colw
    variable ${name}::rowh

    if {$row < 0} {
	# Remove rows from the head of values to restrict it to the
	# overlapping area.

	set values [lrange $values [expr {0 - $row}] end]
	set row 0
    }

    # Restrict it at the end too.
    if {($row + [llength $values]) > $rows} {
	set values [lrange $values 0 [expr {$rows - $row - 1}]]
    }

    # Same for columns, but store it in some vars as this is required
    # in a loop.
    set firstcol 0
    if {$column < 0} {
	set firstcol [expr {0 - $column}]
	set column 0
    }

    # Now pan through values and area and copy the external data into
    # the matrix.

    set r $row
    foreach line $values {
	set line [lrange $line $firstcol end]

	set l [expr {$column + [llength $line]}]
	if {$l > $columns} {
	    set line [lrange $line 0 [expr {$columns - $column - 1}]]
	} elseif {$l < [expr {$columns - $firstcol}]} {
	    # We have to take the offset into the line into account
	    # or we add fillers we don't need, overwriting part of the
	    # data array we shouldn't.

	    for {} {$l < [expr {$columns - $firstcol}]} {incr l} {
		lappend line {}
	    }
	}

	set c $column
	foreach cell $line {
	    if {$cell != {}} {
		catch {unset rowh($r)}
		catch {unset colw($c)}
	    }
	    set data($c,$r) $cell
	    incr c
	}
	incr r
    }
    return
}

# ::struct::matrix::__set_row --
#
#	Sets the values in the cells identified by the row index to
#	the elements of the list provided as the third argument. Each
#	element of the list is assigned to one cell, with the first
#	element going into the cell in column 0 and then upward. If
#	there are less values in the list than there are columns the
#	remaining columns are set to the empty string. If there are
#	more values in the list than there are columns the superfluous
#	elements are ignored. The matrix is not extended by this
#	operation.
#
# Arguments:
#	name	Name of the matrix.
#	row	Index of the row to set.
#	values	Values to set into the row.
#
# Results:
#	None.

proc ::struct::matrix::__set_row {name row values} {
    set row [ChkRowIndex $name $row]

    variable ${name}::data
    variable ${name}::columns
    variable ${name}::rows
    variable ${name}::colw
    variable ${name}::rowh

    if {[set l [llength $values]] < $columns} {
	# Missing values. Fill up with empty strings

	for {} {$l < $columns} {incr l} {
	    lappend values {}
	}
    } elseif {[llength $values] > $columns} {
	# To many values. Remove the superfluous items
	set values [lrange $values 0 [expr {$columns - 1}]]
    }

    # "values" now contains the information to set into the array.
    # Regarding the width and height caches:

    # - Invalidate the row in the height cache.
    # - The columns are either removed from the width cache or left
    #   unchanged, depending on the contents set into the cell.

    set c 0
    foreach v $values {
	if {$v != {}} {
	    # Data changed unpredictably, invalidate cache
	    catch {unset colw($c)}
	} ; # {else leave the row unchanged}
	set data($c,$row) $v
	incr c
    }
    catch {unset rowh($row)}
    return
}

# ::struct::matrix::__swap_columns --
#
#	Swaps the contents of the two specified columns.
#
# Arguments:
#	name		Name of the matrix.
#	column_a	Index of the first column to swap
#	column_b	Index of the second column to swap
#
# Results:
#	None.

proc ::struct::matrix::__swap_columns {name column_a column_b} {
    set column_a [ChkColumnIndex $name $column_a]
    set column_b [ChkColumnIndex $name $column_b]
    return [SwapColumns $name $column_a $column_b]
}

proc ::struct::matrix::SwapColumns {name column_a column_b} {
    variable ${name}::data
    variable ${name}::rows
    variable ${name}::colw

    # Note: This operation does not influence the height cache for all
    # rows and the width cache only insofar as its contents has to be
    # swapped too for the two columns we are touching. Note that the
    # cache might be partially filled or not at all, so we don't have
    # to "swap" in some situations.

    for {set r 0} {$r < $rows} {incr r} {
	set tmp                $data($column_a,$r)
	set data($column_a,$r) $data($column_b,$r)
	set data($column_b,$r) $tmp
    }

    set cwa [info exists colw($column_a)]
    set cwb [info exists colw($column_b)]

    if {$cwa && $cwb} {
	set tmp             $colw($column_a)
	set colw($column_a) $colw($column_b)
	set colw($column_b) $tmp
    } elseif {$cwa} {
	# Move contents, don't swap.
	set   colw($column_b) $colw($column_a)
	unset colw($column_a)
    } elseif {$cwb} {
	# Move contents, don't swap.
	set   colw($column_a) $colw($column_b)
	unset colw($column_b)
    } ; # else {nothing to do at all}
    return
}

# ::struct::matrix::__swap_rows --
#
#	Swaps the contents of the two specified rows.
#
# Arguments:
#	name	Name of the matrix.
#	row_a	Index of the first row to swap
#	row_b	Index of the second row to swap
#
# Results:
#	None.

proc ::struct::matrix::__swap_rows {name row_a row_b} {
    set row_a [ChkRowIndex $name $row_a]
    set row_b [ChkRowIndex $name $row_b]
    return [SwapRows $name $row_a $row_b]
}

proc ::struct::matrix::SwapRows {name row_a row_b} {
    variable ${name}::data
    variable ${name}::columns
    variable ${name}::rowh

    # Note: This operation does not influence the width cache for all
    # columns and the height cache only insofar as its contents has to be
    # swapped too for the two rows we are touching. Note that the
    # cache might be partially filled or not at all, so we don't have
    # to "swap" in some situations.

    for {set c 0} {$c < $columns} {incr c} {
	set tmp             $data($c,$row_a)
	set data($c,$row_a) $data($c,$row_b)
	set data($c,$row_b) $tmp
    }

    set rha [info exists rowh($row_a)]
    set rhb [info exists rowh($row_b)]

    if {$rha && $rhb} {
	set tmp          $rowh($row_a)
	set rowh($row_a) $rowh($row_b)
	set rowh($row_b) $tmp
    } elseif {$rha} {
	# Move contents, don't swap.
	set   rowh($row_b) $rowh($row_a)
	unset rowh($row_a)
    } elseif {$rhb} {
	# Move contents, don't swap.
	set   rowh($row_a) $rowh($row_b)
	unset rowh($row_b)
    } ; # else {nothing to do at all}
    return
}

# ::struct::matrix::_unlink --
#
#	Removes the link between the matrix and the specified
#	arrayvariable, if there is one.
#
# Arguments:
#	name	Name of the matrix.
#	avar	Name of the linked array.
#
# Results:
#	None.

proc ::struct::matrix::_unlink {name avar} {

    variable ${name}::link

    if {![info exists link($avar)]} {
	# Ignore unlinking of unkown variables.
	return
    }

    # Delete the traces first, then remove the link management
    # information from the object.

    upvar #0 $avar    array
    variable ${name}::data

    trace vdelete array wu [list ::struct::matrix::MatTraceIn  $avar $name]
    trace vdelete date  w  [list ::struct::matrix::MatTraceOut $avar $name]

    unset link($avar)
    return
}

# ::struct::matrix::ChkColumnIndex --
#
#	Helper to check and transform column indices. Returns the
#	absolute index number belonging to the specified
#	index. Rejects indices out of the valid range of columns.
#
# Arguments:
#	matrix	Matrix to look at
#	column	The incoming index to check and transform
#
# Results:
#	The absolute index to the column

proc ::struct::matrix::ChkColumnIndex {name column} {
    variable ${name}::columns

    switch -regex -- $column {
	{end-[0-9]+} {
	    set column [string map {end- ""} $column]
	    set cc [expr {$columns - 1 - $column}]
	    if {($cc < 0) || ($cc >= $columns)} {
		return -code error "bad column index end-$column, column does not exist"
	    }
	    return $cc
	}
	end {
	    if {$columns <= 0} {
		return -code error "bad column index $column, column does not exist"
	    }
	    return [expr {$columns - 1}]
	}
	{[0-9]+} {
	    if {($column < 0) || ($column >= $columns)} {
		return -code error "bad column index $column, column does not exist"
	    }
	    return $column
	}
	default {
	    return -code error "bad column index \"$column\", syntax error"
	}
    }
    # Will not come to this place
}

# ::struct::matrix::ChkRowIndex --
#
#	Helper to check and transform row indices. Returns the
#	absolute index number belonging to the specified
#	index. Rejects indices out of the valid range of rows.
#
# Arguments:
#	matrix	Matrix to look at
#	row	The incoming index to check and transform
#
# Results:
#	The absolute index to the row

proc ::struct::matrix::ChkRowIndex {name row} {
    variable ${name}::rows

    switch -regex -- $row {
	{end-[0-9]+} {
	    set row [string map {end- ""} $row]
	    set rr [expr {$rows - 1 - $row}]
	    if {($rr < 0) || ($rr >= $rows)} {
		return -code error "bad row index end-$row, row does not exist"
	    }
	    return $rr
	}
	end {
	    if {$rows <= 0} {
		return -code error "bad row index $row, row does not exist"
	    }
	    return [expr {$rows - 1}]
	}
	{[0-9]+} {
	    if {($row < 0) || ($row >= $rows)} {
		return -code error "bad row index $row, row does not exist"
	    }
	    return $row
	}
	default {
	    return -code error "bad row index \"$row\", syntax error"
	}
    }
    # Will not come to this place
}

# ::struct::matrix::ChkColumnIndexNeg --
#
#	Helper to check and transform column indices. Returns the
#	absolute index number belonging to the specified
#	index. Rejects indices out of the valid range of columns
#	(Accepts negative indices).
#
# Arguments:
#	matrix	Matrix to look at
#	column	The incoming index to check and transform
#
# Results:
#	The absolute index to the column

proc ::struct::matrix::ChkColumnIndexNeg {name column} {
    variable ${name}::columns

    switch -regex -- $column {
	{end-[0-9]+} {
	    set column [string map {end- ""} $column]
	    set cc [expr {$columns - 1 - $column}]
	    if {$cc >= $columns} {
		return -code error "bad column index end-$column, column does not exist"
	    }
	    return $cc
	}
	end {
	    return [expr {$columns - 1}]
	}
	{[0-9]+} {
	    if {$column >= $columns} {
		return -code error "bad column index $column, column does not exist"
	    }
	    return $column
	}
	default {
	    return -code error "bad column index \"$column\", syntax error"
	}
    }
    # Will not come to this place
}

# ::struct::matrix::ChkRowIndexNeg --
#
#	Helper to check and transform row indices. Returns the
#	absolute index number belonging to the specified
#	index. Rejects indices out of the valid range of rows
#	(Accepts negative indices).
#
# Arguments:
#	matrix	Matrix to look at
#	row	The incoming index to check and transform
#
# Results:
#	The absolute index to the row

proc ::struct::matrix::ChkRowIndexNeg {name row} {
    variable ${name}::rows

    switch -regex -- $row {
	{end-[0-9]+} {
	    set row [string map {end- ""} $row]
	    set rr [expr {$rows - 1 - $row}]
	    if {$rr >= $rows} {
		return -code error "bad row index end-$row, row does not exist"
	    }
	    return $rr
	}
	end {
	    return [expr {$rows - 1}]
	}
	{[0-9]+} {
	    if {$row >= $rows} {
		return -code error "bad row index $row, row does not exist"
	    }
	    return $row
	}
	default {
	    return -code error "bad row index \"$row\", syntax error"
	}
    }
    # Will not come to this place
}

# ::struct::matrix::ChkColumnIndexAll --
#
#	Helper to transform column indices. Returns the
#	absolute index number belonging to the specified
#	index.
#
# Arguments:
#	matrix	Matrix to look at
#	column	The incoming index to check and transform
#
# Results:
#	The absolute index to the column

proc ::struct::matrix::ChkColumnIndexAll {name column} {
    variable ${name}::columns

    switch -regex -- $column {
	{end-[0-9]+} {
	    set column [string map {end- ""} $column]
	    set cc [expr {$columns - 1 - $column}]
	    return $cc
	}
	end {
	    return $columns
	}
	{[0-9]+} {
	    return $column
	}
	default {
	    return -code error "bad column index \"$column\", syntax error"
	}
    }
    # Will not come to this place
}

# ::struct::matrix::ChkRowIndexAll --
#
#	Helper to transform row indices. Returns the
#	absolute index number belonging to the specified
#	index.
#
# Arguments:
#	matrix	Matrix to look at
#	row	The incoming index to check and transform
#
# Results:
#	The absolute index to the row

proc ::struct::matrix::ChkRowIndexAll {name row} {
    variable ${name}::rows

    switch -regex -- $row {
	{end-[0-9]+} {
	    set row [string map {end- ""} $row]
	    set rr [expr {$rows - 1 - $row}]
	    return $rr
	}
	end {
	    return $rows
	}
	{[0-9]+} {
	    return $row
	}
	default {
	    return -code error "bad row index \"$row\", syntax error"
	}
    }
    # Will not come to this place
}

# ::struct::matrix::MatTraceIn --
#
#	Helper propagating changes made to an array
#	into the matrix the array is linked to.
#
# Arguments:
#	avar		Name of the array which was changed.
#	name		Matrix to write the changes to.
#	var,idx,op	Standard trace arguments
#
# Results:
#	None.

proc ::struct::matrix::MatTraceIn {avar name var idx op} {
    # Propagate changes in the linked array back into the matrix.

    variable ${name}::lock
    if {$lock} {return}

    # We have to cover two possibilities when encountering an "unset" operation ...
    # 1. The external array was destroyed: perform automatic unlink.
    # 2. An individual element was unset:  Set the corresponding cell to the empty string.
    #    See SF Tcllib Bug #532791.

    if {(![string compare $op u]) && ($idx == {})} {
	# Possibility 1: Array was destroyed
	$name unlink $avar
	return
    }

    upvar #0 $avar    array
    variable ${name}::data
    variable ${name}::link

    set transpose $link($avar)
    if {$transpose} {
	foreach {r c} [split $idx ,] break
    } else {
	foreach {c r} [split $idx ,] break
    }

    # Use standard method to propagate the change.
    # => Get automatically index checks, cache updates, ...

    if {![string compare $op u]} {
	# Unset possibility 2: Element was unset.
	# Note: Setting the cell to the empty string will
	# invoke MatTraceOut for this array and thus try
	# to recreate the destroyed element of the array.
	# We don't want this. But we do want to propagate
	# the change to other arrays, as "unset". To do
	# all of this we use another state variable to
	# signal this situation.

	variable ${name}::unset
	set unset $avar

	$name set cell $c $r ""

	set unset {}
	return
    }

    $name set cell $c $r $array($idx)
    return
}

# ::struct::matrix::MatTraceOut --
#
#	Helper propagating changes made to the matrix into the linked arrays.
#
# Arguments:
#	avar		Name of the array to write the changes to.
#	name		Matrix which was changed.
#	var,idx,op	Standard trace arguments
#
# Results:
#	None.

proc ::struct::matrix::MatTraceOut {avar name var idx op} {
    # Propagate changes in the matrix data array into the linked array.

    variable ${name}::unset

    if {![string compare $avar $unset]} {
	# Do not change the variable currently unsetting
	# one of its elements.
	return
    }

    variable ${name}::lock
    set lock 1 ; # Disable MatTraceIn [#532783]

    upvar #0 $avar    array
    variable ${name}::data
    variable ${name}::link

    set transpose $link($avar)

    if {$transpose} {
	foreach {r c} [split $idx ,] break
    } else {
	foreach {c r} [split $idx ,] break
    }

    if {$unset != {}} {
	# We are currently propagating the unset of an
	# element in a different linked array to this
	# array. We make sure that this is an unset too.

	unset array($c,$r)
    } else {
	set array($c,$r) $data($idx)
    }
    set lock 0
    return
}

# ::struct::matrix::SortMaxHeapify --
#
#	Helper for the 'sort' method. Performs the central algorithm
#	which converts the matrix into a heap, easily sortable.
#
# Arguments:
#	name	Matrix object which is sorted.
#	i	Index of the row/column currently being sorted.
#	key	Index of the column/row to sort the rows/columns by.
#	rowCol	Indicator if we are sorting rows ('r'), or columns ('c').
#	heapSize Number of rows/columns to sort.
#	rev	Boolean flag, set if sorting is done revers (-decreasing).
#
# Sideeffects:
#	Transforms the matrix into a heap of rows/columns,
#	swapping them around.
#
# Results:
#	None.

proc ::struct::matrix::SortMaxHeapify {name i key rowCol heapSize {rev 0}} {
    # MAX-HEAPIFY, adapted by EAS from CLRS 6.2
    switch  $rowCol {
	r { set A [GetColumn $name $key] }
	c { set A [GetRow    $name $key] }
    }
    # Weird expressions below for clarity, as CLRS uses A[1...n]
    # format and TCL uses A[0...n-1]
    set left  [expr {int(2*($i+1)    -1)}]
    set right [expr {int(2*($i+1)+1  -1)}]

    # left, right are tested as < rather than <= because they are
    # in A[0...n-1]
    if {
	$left < $heapSize &&
	( !$rev && [lindex $A $left] > [lindex $A $i] ||
	   $rev && [lindex $A $left] < [lindex $A $i] )
    } {
	set largest $left
    } else {
	set largest $i
    }

    if {
	$right < $heapSize &&
	( !$rev && [lindex $A $right] > [lindex $A $largest] ||
	   $rev && [lindex $A $right] < [lindex $A $largest] )
    } {
	set largest $right
    }

    if { $largest != $i } {
	switch $rowCol {
	    r { SwapRows    $name $i $largest }
	    c { SwapColumns $name $i $largest }
	}
	SortMaxHeapify $name $largest $key $rowCol $heapSize $rev
    }
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Get 'matrix::matrix' into the general structure namespace.
    namespace import -force matrix::matrix
    namespace export matrix
}
package provide struct::matrix 1.2.2
