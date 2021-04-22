# doctoc.tcl --
#
#	Implementation of doctoc objects for Tcl. v2.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: container.tcl,v 1.2 2009/11/15 05:50:03 andreas_kupries Exp $

# Each object manages one table of contents, with methods to add and
# remove entries and divisions, singly, or in bulk. The bulk methods
# accept various forms of textual serializations, among them text
# using the doctoc markup language.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4
package require doctools::toc::structure
package require snit
package require struct::tree

# ### ### ### ######### ######### #########
## API

snit::type ::doctools::toc {

    # Concepts:
    # - A table of contents consists of an ordered set of elements,
    #   references and divisions.
    # - Both type of elements within the table are identified by their
    #   label.
    # - A reference has two additional pieces of information,
    #   the id of the document it references, and a textual description.
    # - A division may have the id of a document.
    # - The main data of a division is an ordered set of elements,
    #   references and divisions.
    # - Both type of elements within the division are identified by
    #   their label.
    # - The definitions above define a tree of elements, with
    #   references as leafs, and divisions as the inner nodes.
    # - Regarding identification, the full label of each element is
    #   the list of per-node labels on the path from the root of the
    #   tree to the element itself.

    # ### ### ### ######### ######### #########
    ## Options

    ## None

    # ### ### ### ######### ######### #########
    ## Methods

    constructor {} {
	install mytree using struct::tree ${selfns}::T
	# Root is a fake division
	set myroot [$mytree rootname]
	$mytree set $myroot type division
	$mytree set $myroot label {}
	$mytree set $myroot labelindex {}
	return
    }

    # Default destructor.

    # ### ### ### ######### ######### #########

    method invalidate {} {
	array unset mytoc *
	return
    }

    # ### ### ### ######### ######### #########

    method title {{text {}}} {
	if {[llength [info level 0]] == 6} {
	    set mytitle $text
	}
	return $mytitle
    }

    method label {{text {}}} {
	if {[llength [info level 0]] == 6} {
	    set mylabel $text
	    $mytree set $myroot label $text
	}
	return $mylabel
    }

    method exporter {{object {}}} {
	# TODO :: unlink/link change notification callbacks on the
	# config/include components so that we can invalidate our
	# cache when the settings change.

	if {[llength [info level 0]] == 6} {
	    set myexporter $object
	}
	return $myexporter
    }

    method importer {{object {}}} {
	if {[llength [info level 0]] == 6} {
	    set myimporter $object
	}
	return $myimporter
    }

    # ### ### ### ######### ######### #########
    ## Direct manipulation of the table of contents.

    method {+ reference} {pid label docid desc} {
	CheckDiv $pid
	if {$docid eq {}} {
	    return -code error "Illegal empty document reference for reference entry"
	}

	array set l [$mytree get $pid labelindex]
	if {[info exists l($label)]} {
	    return -code error "Redefinition of label '$label' in '[$self full-label $pid]'"
	}

	set new [$mytree insert $pid end]
	set l($label) $new
	$mytree set $pid labelindex [array get l]

	$mytree set $new type        reference
	$mytree set $new label       $label
	$mytree set $new document    $docid
	$mytree set $new description $desc

	array unset mytoc *
	return $new
    }

    method {+ division} {pid label {docid {}}} {
	CheckDiv $pid

	array set l [$mytree get $pid labelindex]
	if {[info exists l($label)]} {
	    return -code error "Redefinition of label '$label' in '[$self full-label $pid]'"
	}

	set new [$mytree insert $pid end]
	set l($label) $new
	$mytree set $pid labelindex [array get l]

	$mytree set $new type  division
	$mytree set $new label $label
	if {$docid ne {}} {
	    $mytree set $new document $docid
	}
	$mytree set $new labelindex {}

	array unset mytoc *
	return $new
    }

    method remove {id} {
	Check $id
	if {$id eq $myroot} {
	    return -code error {Unable to remove root}
	}
	set pid   [$mytree parent $id]
	set label [$mytree get $id label]

	array set l [$mytree get $pid labelindex]
	unset l($label)
	$mytree set $pid labelindex [array get l]
	$mytree delete $id

	array unset mytoc *
	return
    }

    # ### ### ### ######### ######### #########

    method up {id} {
	Check $id
	return [$mytree parent $id]
    }

    method next {id} {
	Check $id
	set n [$mytree next $id]
	if {$n eq {}} { set n [$mytree parent $id] }
	return $n
    }

    method prev {id} {
	Check $id
	set n [$mytree previous $id]
	if {$n eq {}} { set n [$mytree parent $id] }
	return $n
    }

    method child {id label args} {
	CheckDiv $id
	# Find the id of the element with the given labels, in the
	# parent element id.
	foreach label [linsert $args 0 $label] {
	    array set l [$mytree get $id labelindex]
	    if {![info exists l($label)]} {
		return -code error "Bad label '$label' in '[$self full-label $id]'"
	    }
	    set id $l($label)
	    unset l
	}
	return $id
    }

    method element {args} {
	if {![llength $args]} { return $myroot }
	# 8.5: $self child $myroot {*}$args
	return [eval [linsert $args 0 $self child $myroot]]
    }

    method children {id} {
	CheckDiv $id
	return [$mytree children $id]
    }

    # ### ### ### ######### ######### #########

    method type {id} {
	Check $id
	return [$mytree get $id type]
    }

    method full-label {id} {
	Check $id
	set result {}
	foreach node [struct::list reverse [lrange [$mytree ancestors $id] 0 end-1]] {
	    lappend result [$mytree get $node label]
	}
	lappend result [$mytree get $id label]

	return $result
    }

    method elabel {id {newlabel {}}} {
	Check $id
	set thelabel [$mytree get $id label]
	if {
	    ([llength [info level 0]] == 7) &&
	    ($newlabel ne $thelabel)
	} {
	    # Handle only calls which change the label

	    set parent [$mytree parent $id]
	    array set l [$mytree get $parent labelindex]

	    if {[info exists l($newlabel)]} {
		return -code error "Redefinition of label '$newlabel' in '[$self full-label $parent]'"
	    }

	    # Copy node information and re-label.
	    set   l($newlabel) $l($thelabel)
	    unset l($thelabel)
	    $mytree set $id label $newlabel
	    $mytree set $parent labelindex [array get l]

	    if {$id eq $myroot} {
		set mylabel $newlabel
	    }

	    set thelabel $newlabel
	}
	return $thelabel
    }

    method description {id {newdesc {}}} {
	Check $id
	if {[$mytree get $id type] eq "division"} {
	    return -code error "Divisions have no description"
	}
	set thedescription [$mytree get $id description]
	if {
	    ([llength [info level 0]] == 7) &&
	    ($newdesc ne $thedescription)
	} {
	    # Handle only calls which change the description
	    $mytree set $id description $newdesc

	    set thedescription $newdesc
	}
	return $thedescription
    }

    method document {id {newdocid {}}} {
	Check $id
	set thedocid {}
	catch {
	    set thedocid [$mytree get $id document]
	}
	if {
	    ([llength [info level 0]] == 7) &&
	    ($newdocid ne $thedocid)
	} {
	    # Handle only calls which change the document
	    if {$newdocid eq {}} {
		if {[$mytree get $id type] eq "division"} {
		    $mytree unset $id document
		} else {
		    return -code error "Illegal to unset document reference in reference entry"
		}
	    } else {
		$mytree set $id document $newdocid
	    }
	    set thedocid $newdocid
	}
	return $thedocid
    }

    # ### ### ### ######### ######### #########
    ## Public methods. Bulk loading and merging.

    method {deserialize =} {data {format {}}} {
	# Default format is the regular toc serialization
	if {$format eq {}} {
	    set format serial
	}

	if {$format ne "serial"} {
	    set data [$self Import $format $data]
	    # doctools::toc::structure verify-as-canonical $data
	    # ImportSerial verifies.
	}

	$self ImportSerial $data
	return
    }

    method {deserialize +=} {data {format {}}} {
	# Default format is the regular toc serialization
	if {$format eq {}} {
	    set format serial
	}

	if {$format ne "serial"} {
	    set data [$self Import $format $data]
	    # doctools::toc::structure verify-as-canonical $data
	    # merge or ImportSerial verify the structure.
	}

	set data [doctools::toc::structure merge [$self serialize] $data]
	# doctools::toc::structure verify-as-canonical $data
	# ImportSerial verifies.

	$self ImportSerial $data
	return
    }

    # ### ### ### ######### ######### #########

    method serialize {{format {}}} {
	# Default format is the regular toc serialization
	if {$format eq {}} {
	    set format serial
	}

	# First check the cache for a remebered representation of the
	# toc for the chosen format, and return it, if such is known.

	if {[info exists mytoc($format)]} {
	    return $mytoc($format)
	}

	# If there is no cached representation we have to generate it
	# from it from our internal representation.

	if {$format eq "serial"} {
	    return [$self GenerateSerial]
	} else {
	    return [$self Generate $format]
	}

	return -code error "Internal error, reached unreachable location"
    }

    # ### ### ### ######### ######### #########
    ## Internal methods

    proc Check {id} {
	upvar 1 mytree mytree
	if {![$mytree exists $id]} {
	    return -code error "Bad toc element handle '$id'"
	}
	return
    }

    proc CheckDiv {id} {
	upvar 1 mytree mytree
	Check $id
	if {[$mytree get $id type] ne "division"} {
	    return -code error "toc element handle '$id' does not refer to a division"
	}
    }

    method GenerateSerial {} {
	# We can generate the list serialization easily from the
	# internal representation.

	# Construct result
	set serial [list doctools::toc \
			[list \
			     items [$self GenerateDivision $myroot] \
			     label $mylabel \
			     title $mytitle]]

	# This is just present to assert that the code above creates
	# correct serializations.
	doctools::toc::structure verify-as-canonical $serial

	set mytoc(serial) $serial
	return $serial
    }

    method GenerateDivision {root} {
	upvar 1 mytree mytree
	set div {}
	foreach id [$mytree children $root] {
	    set etype [$mytree get $id type]
	    set edata {}
	    switch -exact -- $etype {
		reference {
		    lappend edata \
			desc  [$mytree get $id description] \
			id    [$mytree get $id document] \
			label [$mytree get $id label]
		}
		division {
		    if {[$mytree keyexists $id document]} {
			lappend edata id [$mytree get $id document]
		    }
		    lappend edata \
			items [$self GenerateDivision $id] \
			label [$mytree get $id label]
		}
	    }
	    lappend div [list $etype $edata]
	}
	return $div
    }

    method Generate {format} {
	if {$myexporter eq {}} {
	    return -code error "Unable to export from \"$format\", no exporter configured"
	}
	set res [$myexporter export object $self $format]
	set mytoc($format) $res
	return $res
    }

    method ImportSerial {serial} {
	doctools::toc::structure verify $serial iscanonical

	# Kill existing content
	foreach id [$mytree children $myroot] {
	    $mytree delete $id
	}

	# Unpack the serialization.
	array set toc $serial
	array set toc $toc(doctools::toc)
	unset     toc(doctools::toc)

	# We are setting the relevant variables directly instead of
	# going through the accessor methods.

	set mytitle $toc(title)
	set mylabel $toc(label)

	$self ImportDivision $toc(items) $myroot

	# Extend cache (only if canonical, as we return only canonical
	# data).
	if {$iscanonical} {
	    set mytoc(serial) $serial
	}
	return
    }

    method ImportDivision {items root} {
	foreach element $items {
	    foreach {etype edata} $element break
	    #struct::list assign $element etype edata
	    array set toc $edata
	    switch -exact -- $etype {
		reference {
		    $self + reference $root \
			$toc(label) $toc(id) $toc(desc)
		}
		division {
		    if {[info exists toc(id)]} {
			set div [$self + division $root $toc(label) $toc(id)]
		    } else {
			set div [$self + division $root $toc(label)]
		    }
		    $self ImportDivision $toc(items) $div
		}
	    }
	    unset toc
	}
	return
    }

    method Import {format data} {
	if {$myimporter eq {}} {
	    return -code error "Unable to import from \"$format\", no importer configured"
	}

	return [$myimporter import text $data $format]
    }

    # ### ### ### ######### ######### #########
    ## State

    # References to export/import managers extending the
    # (de)serialization abilities of the table of contents.
    variable myexporter {}
    variable myimporter {}

    # Internal representation of the table of contents.

    variable mytitle           {} ; # 
    variable mylabel           {} ; # 
    variable mytree            {} ; # Tree object holding the toc.
    variable myroot            {} ; # Name of the tree root node.

    # Array serving as cache holding alternative representations of
    # the toc generated via 'serialize', i.e. data export.

    variable mytoc -array {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide doctools::toc 2
return
