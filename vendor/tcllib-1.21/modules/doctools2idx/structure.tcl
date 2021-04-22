# -*- tcl -*-
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>

# Verification of serialized indices, and conversion between
# serialized indices and other data structures.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.4              ; # Required runtime.
package require snit                 ; # OO system.

# # ## ### ##### ######## ############# #####################
##

snit::type ::doctools::idx::structure {
    # # ## ### ##### ######## #############
    ## Public API

    # Check that the proposed serialization of a keyword index is
    # indeed such.

    typemethod verify {serial {canonvar {}}} {
	# Basic syntax: Length and outer type code
	if {[llength $serial] != 2} {
	    return -code error $ourprefix$ourshort
	}

	foreach {tag contents} $serial break
	#struct::list assign $serial tag contents

	if {$tag ne $ourcode} {
	    return -code error $ourprefix[format $ourtag $tag]
	}

	if {[llength $contents] != 8} {
	    return -code error $ourprefix$ourcshort
	}

	# Unpack the contents, then check that all necessary keys are
	# present. Together with the length check we can then also be
	# sure that no other key is present either.
	array set idx $contents

	foreach k {label title keywords references} {
	    if {[info exists idx($k)]} continue
	    return -code error $ourprefix[format $ourmiss $k]
	}

	# Pull the keys and check their use (n duplicates allowed). At
	# the same time we collect the references they are associated
	# with.

	set refs {}
	set keys {}
	array set kw {}

	foreach {k reflist} $idx(keywords) {
	    lappend keys $k
	    set kw($k) {}
	    foreach r $reflist { lappend refs $r }
	}

	# Fail if keys are duplicated
	if {[llength [array names kw]] != [llength $keys]} {
	    return -code error $ourprefix$ourkdup
	}

	# Pull the references and check their values, and use.
	array set rd {}
	set refids {}
	foreach {id rdef} $idx(references) {
	    if {[llength $rdef] != 2} {
		return -code error $ourprefix$ourrshort
	    }
	    set rtag [lindex $rdef 0]
	    if {($rtag ne "manpage") && ($rtag ne "url")} {
		return -code error $ourprefix[format $ourrtag $rtag]
	    }
	    lappend refids $id
	    set rd($id) {}
	}

	# Fail if reference ids are duplicated
	if {[llength [array names rd]] != [llength $refids]} {
	    return -code error $ourprefix$ourrdup
	}

	# Fail if we have references in keys without decl, or
	# references not used by any key.
	if {[lsort -dict [lsort -unique $refs]] ne [lsort -dict $refids]} {
	    return -code error $ourprefix$ourrmismatch
	}

	if {$canonvar ne {}} {
	    upvar 1 $canonvar iscanonical

	    # Now various checks if the keys and identifiers are
	    # properly sorted to make this a canonical serialization.
	    set iscanonical 1

	    foreach {a _ b _ c _ d _} $contents break
	    #struct::list assign $contents a _ b _ c _ d _
	    if {
		([list $a $b $c $d] ne {label keywords references title}) ||
		($keys   ne [lsort -dict [array names kw]]) ||
		($refids ne [lsort -dict [array names rd]])
	    } {
		set iscanonical 0
	    }
	}

	# Everything checked out.
	return
    }

    typemethod verify-as-canonical {serial} {
	$type verify $serial iscanonical
	if {!$iscanonical} {
	    #puts <$kw>\n<[lsort -dict [lsort -unique $kw]]>
	    return -code error $ourprefix$ourdupsort
	}
	return
    }

    typemethod canonicalize {serial} {
	$type verify $serial iscanonical
	if {$iscanonical} { return $serial }

	# Unpack the serialization.
	array set idx $serial
	array set idx $idx(doctools::idx)
	unset     idx(doctools::idx)
	array set k $idx(keywords)
	array set r $idx(references)

	# Scan and reorder ...
	set keywords {}
	foreach kw [lsort -dict [array names k]] {
	    # Sort references in a keyword by their _labels_.
	    set tmp {}
	    foreach rid $k($kw) { lappend tmp [list $rid [lindex $r($rid) 1]] }
	    set refs {}
	    foreach item [lsort -dict -index 1 $tmp] {
		lappend refs [lindex $item 0]
	    }
	    lappend keywords $kw $refs
	}

	set references {}
	foreach rid [lsort -dict [array names r]] {
	    lappend references $rid $r($rid)
	}

	# Construct result
	set serial [list doctools::idx \
			[list \
			     label      $idx(label) \
			     keywords   $keywords \
			     references $references \
			     title      $idx(title)]]

	return $serial
    }

    # Merge the serialization of two indices into a new serialization.

    typemethod merge {seriala serialb} {
	$type verify $seriala
	$type verify $serialb

	# Merge using title and label of the second index, and the new
	# key definitions come after the existing, overriding as
	# needed.

	# Unpack the definitions...

	array set a $seriala ; array set a $a(doctools::idx) ; unset a(doctools::idx)
	array set b $serialb ; array set a $b(doctools::idx) ; unset b(doctools::idx)

	# Merge keywords...

	array set k $a(keywords)
	foreach {kw reflist} $b(keywords) {
	    if {![info exists k($kw)]} { set k($kw) {} }
	    foreach r $reflist { lappend k($kw) }
	}

	# Merge references... Here we may have conflicting
	# declarations for the same id.

	array set r $a(references)
	foreach {rid rdecl} $b(references) {
	    if {[info exists r($rid)]} {
		if {$r($rid) ne $rdecl} {
		    return -code error [format $ourmergeerr $r($rid) $rdecl $rid]
		}
		continue
	    }
	    set r($rid) $decl
	}

	# Now construct the result, from the inside out, with proper
	# sorting at all levels.

	set keywords {}
	foreach kw [lsort -dict [array names k]] {
	    # Sort references in a keyword by their _labels_.
	    set tmp {}
	    foreach rid $k($kw) { lappend tmp [list $rid [lindex $r($rid) 1]] }
	    set refs {}
	    foreach item [lsort -dict -index 1 $tmp] {
		lappend refs [lindex $item 0]
	    }
	    lappend keywords $kw $refs
	}

	set references {}
	foreach rid [lsort -dict [array names r]] {
	    lappend references $rid $r($rid)
	}

	set serial [list doctools::idx \
			[list \
			     label      $b(label) \
			     keywords   $keywords \
			     references $references \
			     title      $b(title)]]

	# Caller has to verify, ensure contract.
	#$type verify-as-canonical $serial
	return $serial
    }

    # Converts an index serialization into a human readable string for
    # test results. It assumes that the serialization is at least
    # structurally sound.

    typemethod print {serial} {
	array set i $serial
	array set i $i(doctools::idx)
	array set r $i(references)
	set lines {}
	lappend lines [list doctools::idx $i(label) $i(title)]
	foreach {key reflist} $i(keywords) {
	    lappend lines ....$key
	    foreach ref $reflist {
		lappend lines ........[linsert $r($ref) end $ref]
	    }
	}
	return [join $lines \n]
    }

    # # ## ### ##### ######## #############

    typevariable ourcode      doctools::idx
    typevariable ourprefix    {error in serialization:}
    #                                                                               # Test cases (doctools-idx-structure-)
    typevariable ourshort     { dictionary too short, expected exactly one key}   ; # 6.0
    typevariable ourtag       { bad type tag "%s"}                                ; # 6.1
    typevariable ourcshort    { dictionary too short, expected exactly four keys} ; # 6.2
    typevariable ourmiss      { missing expected key "%s"}                        ; # 6.3, 6.4, 6.5, 6.6
    typevariable ourkdup      { duplicate keywords}                               ; # 6.8
    typevariable ourrshort    { reference list wrong, need exactly 2}             ; # 6.12
    typevariable ourrtag      { bad reference tag "%s"}                           ; # 6.13
    typevariable ourrdup      { duplicate reference identifiers}                  ; # 6.14
    typevariable ourrmismatch { use and declaration of references not matching}   ; # 6.10, 6.11
    # Message for non-canonical serialization when expecting canonical form
    typevariable ourdupsort   { duplicate and/or unsorted keywords/identifiers}   ; # 6.7, 6.9, 6.15

    typevariable ourmergeerr  {Mismatching declarations '%s' vs. '%s' for '%s'}

    # # ## ### ##### ######## #############
    ## Configuration

    pragma -hasinstances   no ; # singleton
    pragma -hastypeinfo    no ; # no introspection
    pragma -hastypedestroy no ; # immortal

    ##
    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide doctools::idx::structure 0.1
return
