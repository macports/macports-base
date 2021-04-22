# -*- tcl -*-
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>

# Verification of serialized tables of contents, and conversion
# between serialized tables of contents and other data structures.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.4              ; # Required runtime.
package require snit                 ; # OO system.

# # ## ### ##### ######## ############# #####################
##

snit::type ::doctools::toc::structure {
    # # ## ### ##### ######## #############
    ## Public API

    # Check that the proposed serialization of a table of contents is
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

	if {[llength $contents] != 6} {
	    return -code error $ourprefix$ourcshort
	}

	# Unpack the contents, then check that all necessary keys are
	# present. Together with the length check we can then also be
	# sure that no other key is present either.
	array set toc $contents

	foreach k {label title items} {
	    if {[info exists toc($k)]} continue
	    return -code error $ourprefix[format $ourmiss $k]
	}

	if {$canonvar eq {}} {
	    VerifyDivision $toc(items)
	} else {
	    upvar 1 $canonvar iscanonical

	    set iscanonical 1
	    VerifyDivision $toc(items) iscanonical

	    # Quick exit if the inner structure was already
	    # non-canonical.
	    if {!$iscanonical} return

	    # Now various checks if the keys and identifiers are
	    # properly sorted to make this a canonical serialization.

	    foreach {a _ b _ c _} $contents break
	    #struct::list assign $contents a _ b _ c _
	    if {[list $a $b $c] ne {items label title}} {
		set iscanonical 0
	    }
	}

	# Everything checked out.
	return
    }

    typemethod verify-as-canonical {serial} {
	$type verify $serial iscanonical
	if {!$iscanonical} {
	    return -code error $ourprefix$ourdupsort
	}
	return
    }

    typemethod canonicalize {serial} {
	$type verify $serial iscanonical
	if {$iscanonical} { return $serial }

	# Unpack the serialization.
	array set toc $serial
	array set toc $toc(doctools::toc)
	unset     toc(doctools::toc)

	# Construct result
	set serial [list doctools::toc \
			[list \
			     items  [CanonicalizeDivision $toc(items)] \
			     label  $toc(label) \
			     title  $toc(title)]]
	return $serial
    }

    # Merge the serialization of two indices into a new serialization.

    typemethod merge {seriala serialb} {
	$type verify $seriala
	$type verify $serialb

	# Merge using title and label of the second toc, and the new
	# elements come after the existing.

	# Unpack the definitions...
	array set a $seriala ; array set a $a(doctools::toc) ; unset a(doctools::toc)
	array set b $serialb ; array set a $b(doctools::toc) ; unset b(doctools::toc)

	# Construct result
	set serial [list doctools::toc \
			[list \
			     items  [MergeDivisions $a(items) $b(items)] \
			     label  $b(label) \
			     title  $b(title)]]

	# Caller has to verify, ensure contract.
	#$type verify-as-canonical $serial
	return $serial
    }

    # Converts a toc serialization into a human readable string for
    # test results. It assumes that the serialization is at least
    # structurally sound.

    typemethod print {serial} {
	# Unpack the serialization.
	array set toc $serial
	array set toc $toc(doctools::toc)
	unset     toc(doctools::toc)
	# Print
	set lines {}
	lappend lines [list doctools::toc $toc(label) $toc(title)]
	PrintDivision lines $toc(items) .... ....
	return [join $lines \n]
    }

    # # ## ### ##### ######## #############

    proc VerifyDivision {items {canonvar {}}} {
	if {$canonvar ne {}} {
	    upvar 1 $canonvar iscanonical
	}

	array set label {}

	foreach element $items {
	    if {[llength $element] != 2} {
		return -code error $ourprefix$oureshort
	    }
	    foreach {etype edata} $element break
	    #struct::list assign $element etype edata

	    switch -exact -- $etype {
		reference {
		    # edata = dict (id, label, desc)
		    if {[llength $edata] != 6} {
			return -code error $ourprefix$ourcshort
		    }
		    array set toc $edata
		    foreach k {id label desc} {
			if {[info exists toc($k)]} continue
			return -code error $ourprefix[format $ourmiss $k]
		    }
		    lappend label($toc(label)) .
		    if {$canonvar ne {}} {
			foreach {a _ b _ c _} $edata break
			#struct::list assign $edata a _ b _ c _
			if {[list $a $b $c] ne {desc id label}} {
			    set iscanonical 0
			}
		    }
		}
		division {
		    # edata = dict (id?, label, items)
		    if {([llength $edata] != 4) && ([llength $edata] != 6)} {
			return -code error $ourprefix$ourdshort
		    }
		    array set toc $edata
		    foreach k {label items} {
			if {[info exists toc($k)]} continue
			return -code error $ourprefix[format $ourmiss $k]
		    }
		    lappend label($toc(label)) .
		    if {$canonvar eq {}} {
			VerifyDivision $toc(items)
		    } else {
			VerifyDivision $toc(items) iscanonical
			if {$iscanonical} {
			    if {[info exists toc(id)]} {
				foreach {a _ b _ c _} $edata break
				#struct::list assign $edata a _ b _ c _
				if {[list $a $b $c] ne {id items label}} {
				    set iscanonical 0
				}
			    } else {
				foreach {a _ b _} $edata break
				#struct::list assign $edata a _ b _
				if {[list $a $b] ne {items label}} {
				    set iscanonical 0
				}
			    }
			}
		    }
		}
		default {
		    return -code error $ourprefix[format $ouretag $etype]
		}
	    }
	    unset toc
	}

	# Fail if labels are duplicated.
	foreach k [array names label] {
	    if {[llength $label($k)] > 1} {
		return -code error $ourprefix$ourldup
	    }
	}

	return
    }

    proc CanonicalizeDivision {items} {
	set result {}
	foreach element $items {
	    foreach {etype edata} $element break
	    #struct::list assign $element etype edata

	    array set toc $edata
	    switch -exact -- $etype {
		reference {
		    set element \
			[list \
			     desc  $toc(desc) \
			     id    $toc(id) \
			     label $toc(label)]
		}
		division {
		    set element {}
		    if {[info exists toc(id)]} {
			lappend element id $toc(id)
		    }
		    lappend element \
			items [CanonicalizeDivision $toc(items)] \
			label $toc(label)
		}
	    }
	    unset toc
	    lappend result [list $etype $element]
	}
	return $result
    }

    proc PrintDivision {lv items prefix increment} {
	upvar 1 $lv lines

	foreach element $items {
	    foreach {etype edata} $element break
	    #struct::list assign $element etype edata
	    array set toc $edata
	    switch -exact -- $etype {
		reference {
		    lappend lines $prefix[list $toc(id) $toc(label) $toc(desc)]
		}
		division {
		    set buf {}
		    if {[info exists toc(id)]} {
			lappend buf  $toc(id)
		    }
		    lappend buf $toc(label)
		    lappend lines $prefix$buf
		    PrintDivision lines $toc(items) $prefix$increment $increment
		}
	    }
	    unset toc
	}
	return
    }

    proc MergeDivisions {aitems bitems} {

	# Unpack the b-items for easy access when looping over a.
	array set b
	foreach element $bitems {
	    foreach {etype edata} $element break
	    array set toc $edata
	    set b($toc(label)) [list $etype $edata]
	    unset toc
	}

	set items {}

	# Unification loop...
	foreach element $aitems {
	    foreach {etype edata} $element break
	    array set toc $edata
	    set label $toc(label)
	    if {![info exists b($label)]} {
		# Nothing in b, keep entry as is.
		lappend items $element
	    } else {
		# Unify. Type dependent. And throw an if the types do
		# not match.
		foreach {btype bdata} $b($label) break
		if {$etype ne $btype} {
		    # TODO :: More details in error message to show
		    # where the mismatch is.
		    return -code error "Merge error"
		}
		switch -exact -- $etype {
		    reference {
			# Unification by taking the b-information.
			lappend items $b($label)
		    }
		    division {
			# Unification by taking the b-information
			# where possible, and merging the sub-ordinate
			# items.
			array set btoc $bdata
			set element {}
			if {[info exists btoc(id)]} {
			    lappend element id $btoc(id)
			} elseif {[info exists toc(id)]} {
			    lappend element id $toc(id)
			}
			lappend element \
			    items [MergeDivisions $toc(items) $btoc(items)] \
			    label $btoc(label)
			unset btoc
			lappend items [list $etype $element]
		    }
		}
		unset b($label)
	    }
	    unset toc
	}

	# Appending loop. Now we add everything from b which was not
	# unified with data in a.
	foreach element $bitems {
	    foreach {etype edata} $element break
	    array set toc $edata
	    set label $toc(label)
	    if {![info exists b($label)]} continue
	    lappend items $element
	}

	return $items
    }

    # # ## ### ##### ######## #############

    typevariable ourcode      doctools::toc
    typevariable ourprefix    {error in serialization:}
    #                                                                                # Test cases (doctools-toc-structure-)
    typevariable ourshort     { dictionary too short, expected exactly one key}    ; # 6.0
    typevariable ourtag       { bad type tag "%s"}                                 ; # 6.1
    typevariable ourcshort    { dictionary too short, expected exactly three keys} ; # 6.2, 6.9
    typevariable ourdshort    { dictionary too short, expected two or three keys}  ; # 6.14
    typevariable ourmiss      { missing expected key "%s"}                         ; # 6.3, 6.4, 6.5, 6.10, 6.11, 6.12, 6.15, 6.16 (XXX + inner: div)
    typevariable ourldup      { duplicate labels}                                  ; # 6.19, 6.20, 6.21
    typevariable oureshort    { element list wrong, need exactly 2}                ; # 6.7
    typevariable ouretag      { bad element tag "%s"}                              ; # 6.8
    # Message for non-canonical serialization when expecting canonical form
    typevariable ourdupsort   { duplicate and/or unsorted keywords}                 ; # 6.6, 6.13, 6.17, 6.18
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

package provide doctools::toc::structure 0.1
return
