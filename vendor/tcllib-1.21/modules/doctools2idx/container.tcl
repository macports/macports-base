# docidx.tcl --
#
#	Implementation of docidx objects for Tcl. v2.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: container.tcl,v 1.3 2009/08/11 22:52:47 andreas_kupries Exp $

# Each object manages one index, with methods to add and remove keys
# and references, singly, or in bulk. The bulk methods accept various
# forms of textual serializations, among them text using the docidx
# markup language.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4
package require doctools::idx::structure
package require snit

# ### ### ### ######### ######### #########
## API

snit::type ::doctools::idx {

    # Concepts:
    # - An index consists of a (possibly empty) set of keys, 
    # - Each key in the set is identified by its name.
    # - Each key has a (possibly empty) set of references.
    # - Each reference is identified by its target, specified as
    #   either url or symbolic filename, depending on the type of
    #   reference (url, or manpage).
    # - A reference can be in the sets of more than one key.
    # - A reference outside of the sets of all keys is not possible
    #   however.
    # - A reference carries not only its identifying target, but also
    #   a descriptive label (*). This label is however not unique per
    #   reference, but only per a pair of key and reference in that
    #   key.
    # - The type of a reference (url, or manpage) is however bound to
    #   the reference itself.
    # - (*) For keys the identifying feature is identical to its
    #   label.

    # Note: url and manpage references share a namespace for their
    # identifiers. This should be no problem with manpage identifiers
    # being symbolic filenames and as such they should never look like
    # urls.

    # ### ### ### ######### ######### #########
    ## Options

    ## None

    # ### ### ### ######### ######### #########
    ## Methods

    # Default constructor.
    # Default destructor.

    # ### ### ### ######### ######### #########

    method invalidate {} {
	array unset myidx *
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
    ## Direct manipulation of the index contents.

    method {key add} {key} {
	# Ignore addition of an already known key
	if {[info exists mykey($key)]} return
	set mykey($key) {}
	array unset myidx *
	return
    }

    method {key remove} {key} {
	# Ignore removal of a key already gone
	if {![info exists mykey($key)]} return
	set references $mykey($key)
	unset mykey($key)
	foreach name $references {
	    # Remove key from the list of users for all references it
	    # contains.
	    set pos [lsearch -exact $myrefuse($name) $key]
	    set myrefuse($name) [lreplace $myrefuse($name) $pos $pos]
	    if {[llength $myrefuse($name)]} continue
	    # Last use of this reference is gone, delete it.
	    unset myrefuse($name)
	    unset myref($name)
	}
	array unset myidx *
	return
    }

    method keys {} {
	return [array names mykey]
    }

    method {key references} {key} {
	if {![info exists mykey($key)]} {
	    return -code error "Unknown key '$key'"
	}
	return $mykey($key)
    }

    method {reference add} {reftype key name label} {
	if {![info exists mykey($key)]} {
	    return -code error "Unknown key '$key'"
	}
	if {[info exists myref($name)] && ([lindex $myref($name) 0] ne $reftype)} {
	    return -code error "Cannot add $reftype reference '$name', is a [lindex $myref($name) 0] reference already"
	}
	if {($reftype ne "url") && ($reftype ne "manpage")} {
	    return -code error "Bad reference type '$reftype'"
	}
	set myref($name) [list $reftype $label]
	if {![info exists myrefuse($name)]} {
	    set myrefuse($name) {}
	}
	if {![info exists mylink([list $name $key])]} {
	    # reference was not used by the key yet.
	    lappend mykey($key) $name
	    lappend myrefuse($name) $key
	    set mylink([list $name $key]) .
	}
	array unset myidx *
	return
    }

    method {reference remove} {name} {
	# Ignore removal of already unknown reference
	if {![info exists myrefuse($name)]} return
	foreach key $myrefuse($name) {
	    unset mylink([list $name $key])
	    set pos   [lsearch -exact $mykey($key) $name]
	    set mykey($key) [lreplace $mykey($key) $pos $pos]
	}
	unset myref($name)
	unset myrefuse($name)
	array unset myidx *
	return
    }

    method {reference label} {name} {
	if {![info exists myref($name)]} {
	    return -code error "Unknown reference '$name'"
	}
	return [lindex $myref($name) 1]
    }

    method {reference type} {name} {
	if {![info exists myref($name)]} {
	    return -code error "Unknown reference '$name'"
	}
	return [lindex $myref($name) 0]
    }

    method {reference keys} {name} {
	if {![info exists myrefuse($name)]} {
	    return -code error "Unknown reference '$name'"
	}
	return $myrefuse($name)
    }

    method references {} {
	return [array names myrefuse]
    }

    # ### ### ### ######### ######### #########
    ## Public methods. Bulk loading and merging.

    method {deserialize =} {data {format {}}} {
	# Default format is the regular index serialization
	if {$format eq {}} {
	    set format serial
	}

	if {$format ne "serial"} {
	    set data [$self Import $format $data]
	    # doctools::idx::structure verify-as-canonical $data
	    # ImportSerial verifies.
	}

	$self ImportSerial $data
	return
    }

    method {deserialize +=} {data {format {}}} {
	# Default format is the regular index serialization
	if {$format eq {}} {
	    set format serial
	}

	if {$format ne "serial"} {
	    set data [$self Import $format $data]
	    # doctools::idx::structure verify-as-canonical $data
	    # merge or ImportSerial verify the structure.
	}

	set data [doctools::idx::structure merge [$self serialize] $data]
	# doctools::idx::structure verify-as-canonical $data
	# ImportSerial verifies.

	$self ImportSerial $data
	return
    }

    # ### ### ### ######### ######### #########

    method serialize {{format {}}} {
	# Default format is the regular index serialization
	if {$format eq {}} {
	    set format serial
	}

	# First check the cache for a remebered representation of the
	# index for the chosen format, and return it, if such is
	# known.

	if {[info exists myidx($format)]} {
	    return $myidx($format)
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

    method GenerateSerial {} {
	# We can generate the list serialization easily from the
	# internal representation.

	# Scan and reorder ...
	set keywords {}
	foreach kw [lsort -dict [array names mykey]] {
	    # Sort the references in a keyword by their _labels_.
	    set tmp {}
	    foreach rid $mykey($kw) { lappend tmp [list $rid [lindex $myref($rid) 1]] }
	    set refs {}
	    foreach item [lsort -dict -index 1 $tmp] {
		lappend refs [lindex $item 0]
	    }
	    lappend keywords $kw $refs
	}

	set references {}
	foreach rid [lsort -dict [array names myrefuse]] {
	    lappend references $rid $myref($rid)
	}

	# Construct result
	set serial [list doctools::idx \
			[list \
			     label      $mylabel \
			     keywords   $keywords \
			     references $references \
			     title      $mytitle]]

	# This is just present to assert that the code above creates
	# correct serializations.
	doctools::idx::structure verify-as-canonical $serial

	set myidx(serial) $serial
	return $serial
    }

    method Generate {format} {
	if {$myexporter eq {}} {
	    return -code error "Unable to export from \"$format\", no exporter configured"
	}
	set res [$myexporter export object $self $format]
	set myidx($format) $res
	return $res
    }

    method ImportSerial {serial} {
	doctools::idx::structure verify $serial iscanonical

	array unset myidx    *
	array unset mykey    *
	array unset myrefuse *
	array unset myref    *
	array unset mylink   *

	# Unpack the serialization.
	array set idx $serial
	array set idx $idx(doctools::idx)
	unset     idx(doctools::idx)

	# We are setting the relevant variables directly instead of
	# going through the accessor methods.
	# I. Label and title
	# II. Keys and references
	# III. Back index references -> keys.

	set mytitle $idx(title)
	set mylabel $idx(label)

	array set mykey $idx(keywords)
	array set myref $idx(references)

	foreach k [array names mykey] {
	    foreach r $mykey($k) {
		lappend myrefuse($r) $k
		set mylink([list $r $k]) .
	    }
	}

	# Extend cache (only if canonical, as we return only canonical
	# data).
	if {$iscanonical} {
	    set myidx(serial) $serial
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
    # (de)serialization abilities of the index.
    variable myexporter {}
    variable myimporter {}

    # Internal representation of the index.

    variable mytitle           {} ; # 
    variable mylabel           {} ; # 
    variable mykey      -array {} ; # key -> list of references
    variable myref      -array {} ; # reference -> (type, label)
    variable myrefuse   -array {} ; # reference -> list of keys using the reference
    variable mylink     -array {} ; # reference x key -> exists if the reference is used by key.

    # Array serving as cache holding alternative representations of
    # the index generated via 'serialize', i.e. data export.

    variable myidx -array {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide doctools::idx 2
return
