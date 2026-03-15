# -*- tcl -*-
# STUBS handling -- Container.
#
# (c) 2011,2022-2023 Andreas Kupries http://wiki.tcl.tk/andreas%20kupries

# A stubs table is represented by a dictionary value.
# A container is a variable holding a stubs table value.

# stubs table dictionary keys
#
# library --
#
#	The name of the entire library.  This value is used to compute
#	the USE_*_STUB_PROCS macro and the name of the init file.
#
# interfaces --
#
#	A dictionary indexed by interface name that is used to maintain
#	the set of valid interfaces. The value is empty.
#
# scspec --
#
#	Storage class specifier for external function declarations.
#	Normally "EXTERN", may be set to something like XYZAPI
#
# epoch, revision --
#
#	The epoch and revision numbers of the interface currently being defined.
#   (@@@TODO: should be an array mapping interface names -> numbers)
#
# hooks --
#
#	A dictionary indexed by interface name that contains the set of
#	subinterfaces that should be defined for a given interface.
#
# stubs --
#
#	This three dimensional dictionary is indexed first by interface
#	name, second by platform name, and third by a numeric
#	offset. Each numeric offset contains the C function
#	specification that should be used for the given entry in the
#	table. The specification consists of a list in the form returned
#	by ParseDecl in the stubs reader package, i.e.
#
#	decl      = list (return-type fun-name arguments)
#	arguments = void | list (arg-info ...)
#	arg-info  = list (type name ?array?)
#	array = '[]'
#
# last --
#
#	This two dimensional dictionary is indexed first by interface name,
#	and second by platform name. The associated entry contains the
#	largest numeric offset used for a given interface/platform
#	combo.

# # ## ### ##### ######## #############
## Requisites

package require Tcl 8.6 9

namespace eval ::stubs::container {}

# # ## ### ##### ######## #############
## Implementation.

proc ::stubs::container::new {} {
    return {
	library    "UNKNOWN"
	interfaces {}
	hooks      {}
	stubs      {}
	last       {}
	scspec     "EXTERN"
	epoch      {}
	revision   0
    }
}

# Methods to incrementally fill the container with data. Strongly
# related to the API commands of the stubs reader package.

proc ::stubs::container::library {tablevar name} {
    upvar 1 $tablevar t
    dict set t library $name
    return
}

proc ::stubs::container::interface {tablevar name} {
    upvar 1 $tablevar t
    if {[dict exists $t interfaces $name]} {
	return -code error "Duplicate declaration of interface \"$name\""
    }
    dict set t interfaces $name {}
    return
}

proc ::stubs::container::scspec {tablevar value} {
    upvar 1 $tablevar t
    dict set t scspec $value
    return
}

proc ::stubs::container::epoch {tablevar value} {
    upvar 1 $tablevar t

    if {![string is integer -strict $value]} {
	return -code error "Expected integer for epoch, but got \"$value\""
    }

    dict set t epoch $value
    return
}

proc ::stubs::container::hooks {tablevar interface names} {
    upvar 1 $tablevar t
    dict set t hooks $interface $names
    return
}

proc ::stubs::container::declare {tablevar interface index platforms decl} {
    variable legalplatforms
    upvar 1 $tablevar t

    #puts "DECLARE ($interface $index) \[$platforms\] =\n\t'[join $decl "'\n\t'"]'"

    if {![dict exists $t interfaces $interface]} {
	return -code error "Unknown interface \"$interface\""
    }
    if {![string is integer -strict $index]} {
	return -code error "Bad index \"$index\", expected integer"
    }

    # legal platform codes
    # - unix, win, macosx, x11, aqua

    # Check for duplicate declarations, then add the declaration and
    # bump the lastNum counter if necessary.

    foreach platform $platforms {
	if {![dict exists $legalplatforms $platform]} {
	    set expected [linsert [join [lsort -dict [dict keys $legalplatforms]] {, }] end-1 or]
	    return -code error "Bad platform \"$platform\", expected one of $expected"
	}

	set key $interface,$platform,$index
	if {[dict exists $t stubs $key]} {
	    return -code error \
		"Duplicate entry: declare $interface $index $platforms $decl"
	}
    }

    if {![llength $decl]} return

    dict incr t revision

    foreach platform $platforms {
	set group $interface,$platform
	set key   $interface,$platform,$index

	dict set t stubs $key $decl
	if {![dict exists $t last $group] ||
	    ($index > [dict get $t last $group])} {
	    dict set t last $group $index
	}
    }
    return
}

# # ## ### ##### ######## #############
# Testing methods.

proc ::stubs::container::library? {table} {
    return [dict get $table library]
}

proc ::stubs::container::hooks? {table interface} {
    if {![dict exists $table interfaces $interface]} {
	return -code error "Unknown interface \"$interface\""
    }
    return [dict exists $table hooks $interface]
}

proc ::stubs::container::slot? {table interface platform at} {
    if {![dict exists $table interfaces $interface]} {
	return -code error "Unknown interface \"$interface\""
    }
    return [dict exists $table stubs $interface,$platform,$at]
}

proc ::stubs::container::scspec? {table} {
    return [dict get $table scspec]
}

proc ::stubs::container::revision? {table} {
    return [dict get $table revision]
}

proc ::stubs::container::epoch? {table} {
    return [dict get $table epoch]
}

# # ## ### ##### ######## #############
# Accessor methods.

proc ::stubs::container::interfaces {table} {
    return [dict keys [dict get $table interfaces]]
}

proc ::stubs::container::hooksof {table interface} {
    if {![dict exists $table interfaces $interface]} {
	return -code error "Unknown interface \"$interface\""
    }
    if {![dict exists $table hooks $interface]} {
	return {}
    }
    return [dict get $table hooks $interface]
}

proc ::stubs::container::platforms {table interface} {
    if {![dict exists $table interfaces $interface]} {
	return -code error "Unknown interface \"$interface\""
    }
    set res {}
    #checker exclude warnArgWrite
    dict with table {
	#checker -scope block exclude warnUndefinedVar
	# 'last' is dict element.
	foreach k [dict keys $last $interface,*] {
	    lappend res [lindex [split $k ,] end]
	}
    }
    return $res
}

proc ::stubs::container::lastof {table interface {platform {}}} {
    if {![dict exists $table interfaces $interface]} {
	return -code error "Unknown interface \"$interface\""
    }
    if {[llength [info level 0]] == 4} {
	set key $interface,$platform
	if {![dict exists $table last $key]} {
	    return -1
	}
	return [dict get $table last $key]
    }

    set res {}
    #checker exclude warnArgWrite
    dict with table {
	#checker -scope block exclude warnUndefinedVar
	# 'last' is dict element.
	foreach k [dict keys $last $interface,*] {
	    lappend res [dict get $last $k]
	}
    }
    return $res
}

proc ::stubs::container::slotplatforms {table interface at} {
    if {![dict exists $table interfaces $interface]} {
	return -code error "Unknown interface \"$interface\""
    }
    set res {}
    #checker exclude warnArgWrite
    dict with table {
	#checker -scope block exclude warnUndefinedVar
	# 'stubs' is dict element.
	foreach k [dict keys $stubs $interface,*,$at] {
	    lappend res [lindex [split $k ,] 1]
	}
    }
    return $res
}

proc ::stubs::container::slot {table interface platform at} {
    if {![dict exists $table interfaces $interface]} {
	return -code error "Unknown interface \"$interface\""
    }
    if {![dict exists $table stubs $interface,$platform,$at]} {
	return -code error "Unknown slot \"$platform,$at\""
    }
    return [dict get $table stubs $interface,$platform,$at]
}

# # ## ### ##### ######## #############
## Serialize, also nicely formatted for readability.

proc ::stubs::container::print {table} {

    lappend lines "stubs [list [library? $table]] \{"
    lappend lines "    scspec   [list [scspec? $table]]"
    lappend lines "    epoch    [list [epoch? $table]]"
    lappend lines "    revision [list [revision? $table]]"

    foreach if [interfaces $table] {
	lappend lines "    interface [list $if] \{"
	lappend lines "        hooks [list [hooksof $table $if]]"

	set n -1
	foreach l [lastof $table $if] {
	    if {$l > $n} { set n $l }
	}
	# n = max lastof for the interface.

	for {set at 0} {$at <= $n} {incr at} {

	    set pl [slotplatforms $table $if $at]
	    if {![llength $pl]} continue

	    foreach p $pl {
		lappend d $p [slot $table $if $p $at]
		#puts  |[lindex $d end-1]|[lindex $d end]|
	    }
	    # d = list of decls for the slot, per platform.
	    # invert and collapse...

	    foreach {d plist} [Invert $d] {
		#puts |$d|
		#puts <$plist>

		# d = list (rtype fname arguments)
		# arguments = list (argdef)
		# argdef = list (atype aname arrayflag)
		#        | list (atype aname)
		#        | list (atype)

		lassign $d rtype fname fargs

		lappend lines "        declare $at [list $plist] \{"
		lappend lines "            function [list $fname]"
		lappend lines "            return [list $rtype]"
		foreach a $fargs {
		    lappend lines "            argument [list $a]"
		}
		lappend lines "        \}"
	    }
	}

	lappend lines "    \}"
    }

    lappend lines "\}"

    return [join $lines \n]
}

proc ::stubs::container::Invert {dict} {
    # input       dict : key -> list(value)
    # result is a dict : value -> list(key)

    array set res {}
    foreach {k v} $dict {
	lappend res($v) $k
    }
    #parray res
    set final {}
    foreach k [lsort -dict [array names res]] {
	lappend final $k [lsort -dict $res($k)]
    }
    return $final
}

# # ## ### ##### ######## #############
## API

namespace eval ::stubs::container {
    variable legalplatforms {
	generic .
	unix    .
	win     .
	macosx  .
	x11     .
	aqua    .
    }

    namespace export \
	new library interface scspec epoch hooks declare \
	library? hooks? slot? scspec? revision? epoch? \
	interfaces hooksof platforms lastof slotplatforms slot
}

# # ## ### #####
package provide stubs::container 1.1.1
return
