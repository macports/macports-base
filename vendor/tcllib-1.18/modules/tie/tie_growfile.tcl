# tie_growfile.tcl --
#
#	Data source: Files.
#
# Copyright (c) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: tie_growfile.tcl,v 1.1 2006/03/08 04:55:58 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Requisites

package require snit
package require tie

# ### ### ### ######### ######### #########
## Implementation

snit::type ::tie::std::growfile {
    # ### ### ### ######### ######### #########
    ## Notes

    ## This data source is geared towards the storage of arrays which
    ## will never shrink over time. Data is always appended to the
    ## files associated with this driver. Nothing is ever
    ## removed. Compaction does not happen either, so modification of
    ## array entries will keep the old information around in the history.

    # ### ### ### ######### ######### #########
    ## Specials

    pragma -hastypemethods no
    pragma -hasinfo        no
    pragma -simpledispatch yes

    # ### ### ### ######### ######### #########
    ## API : Construction & Destruction

    constructor {thepath} {
	# Locate and open the journal file.

	set path [file normalize $thepath]
	if {[file exists $path]} {
	    set chan [open $path {RDWR EXCL APPEND}]
	} else {
	    set chan [open $path {RDWR EXCL CREAT APPEND}]
	}
	fconfigure $chan -buffering none -encoding utf-8
	return
    }

    destructor {
	# Release the channel to the journal file, should it be open.
	if {$chan ne ""} {close $chan}
	return
    }

    # ### ### ### ######### ######### #########
    ## API : Data source methods

    method get {} {
	if {![file size $path]} {return {}}
	$self LoadJournal
	return [array get cache]
    }

    method names {} {
	if {![file size $path]} {return {}}
	$self LoadJournal
	return [array names cache]
    }

    method size {} {
	if {![file size $path]} {return 0}
	$self LoadJournal
	return [array size cache]
    }

    method getv {index} {
	if {![file size $path]} {
	    return -code error "can't read \"$index\": no such variable"
	}
	$self LoadJournal
	return $cache($index)
    }

    method set {dict} {
	puts  -nonewline $chan $dict
	puts  -nonewline $chan { }
	flush            $chan
	return
    }

    method setv {index value} {
	puts  -nonewline $chan [list $index $value]
	puts  -nonewline $chan { }
	flush            $chan
	return
    }

    method unset {{pattern *}} {
	return -code error \
		"Deletion of entries is not allowed by this data source"
    }

    method unsetv {index} {
	return -code error \
		"Deletion of entries is not allowed by this data source"
    }

    # ### ### ### ######### ######### #########
    ## Internal : Instance data

    variable chan {} ; # Channel to write the journal.
    variable path {} ; # Path to journal file.

    # Journal loading, and cache.

    variable count 0         ; # #Operations in the journal.
    variable cvalid 0        ; # Validity of the cache.
    variable cache -array {} ; # Cache for journal

    # Management of the cache: See notes at beginning.

    # ### ### ### ######### ######### #########
    ## Internal: Loading from the journal.

    method LoadJournal {} {
	if {$cvalid} return
	set cvalid 1

	set in [open $path r]
	array set cache [read $in]
	close $in
	return
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready to go

::tie::register ::tie::std::growfile as growfile
package provide   tie::std::growfile 1.0
