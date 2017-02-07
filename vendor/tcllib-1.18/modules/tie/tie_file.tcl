# tie_file.tcl --
#
#	Data source: Files.
#
# Copyright (c) 2004 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: tie_file.tcl,v 1.11 2008/02/28 06:19:56 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Requisites

package require snit
package require tie

# ### ### ### ######### ######### #########
## Implementation

snit::type ::tie::std::file {
    # ### ### ### ######### ######### #########
    ## Notes

    ## This data source maintains an internal cache for higher
    ## efficiency, i.e. to avoid having to go out to the slow file.

    ## This cache is handled as follows
    ##
    ## - All write operations invalidate the cache and write directly
    ##   to the file.
    ##
    ## - All read operations load from the file if the cache is
    ##   invalid, and from the cache otherwise

    ## This scheme works well in the following situations:

    ## (a) The data source is created, and then only read from.
    ## (b) The data source is created, and then only written to.
    ## (c) The data source is created, read once, and then only
    ##     written to.

    ## This scheme works badly if the data source is opened and then
    ## randomly read from and written to. The cache is useless, as it
    ## is continuously invalidated and reloaded.

    ## This no problem from this developers POV of view however.
    ## Consider the context. If you have this situation just tie the
    ## DS to an array A after creation. The tie framework operates on
    ## the DS in mode (c) and A becomes an explicit cache for the DS
    ## which is not invalidated by writing to it. IOW this covers
    ## exactly the situation the DS by itself is not working well for.

    # ### ### ### ######### ######### #########
    ## Specials

    pragma -hastypemethods no
    pragma -hasinfo        no
    pragma -simpledispatch yes

    # ### ### ### ######### ######### #########
    ## API : Construction & Destruction

    constructor {thepath} {
	# Locate and open the journal file.

	set path [::file normalize $thepath]
	if {[::file exists $path]} {
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
	if {![::file size $path]} {return {}}
	$self LoadJournal
	return [array get cache]
    }

    method set {dict} {
	puts $chan [list array set $dict]
	$self Invalidate
	return
    }

    method unset {{pattern *}} {
	puts $chan [list array unset $pattern]
	$self Invalidate
	return
    }

    method names {} {
	if {![::file size $path]} {return {}}
	$self LoadJournal
	return [array names cache]
    }

    method size {} {
	if {![::file size $path]} {return 0}
	$self LoadJournal
	return [array size cache]
    }

    method getv {index} {
	if {![::file size $path]} {
	    return -code error "can't read \"$index\": no such variable"
	}
	$self LoadJournal
	return $cache($index)
    }

    method setv {index value} {
	puts $chan [list set $index $value]
	$self Invalidate
	return
    }

    method unsetv {index} {
	puts $chan [list unset $index]
	$self Invalidate
	return
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
	$self Replay
	$self Compact
	return
    }

    method Replay {} {
	# Use a safe interp for the evaluation of the journal file.
	# (Empty safe for the hidden commands and the aliases we insert).

	# Called for !cvalid, implies cache does not exist

	set ip [interp create -safe]
	foreach c [$ip eval {info commands}] {
	    if {$c eq "rename"} continue
	    $ip eval [list rename $c {}]
	}
	$ip eval {rename rename {}}

	interp alias $ip set   {} $self Set
	interp alias $ip unset {} $self Unset
	interp alias $ip array {} $self Array

	array set cache {}
	set       count 0

	set jchan [open $path r]
	fconfigure $jchan -encoding utf-8
	set data [read $jchan]
	close $jchan

	$ip eval $data
	interp delete $ip

	set cvalid 1
	return
    }

    method Compact {} {
	# Compact the journal

	#puts @@/2*$count/3*[array size temp]/=/[expr {2*$count >= 3*[array size temp]}]

	# ASSERT cvalid

	# do not compact <=>
	# 2*ops < 3*size <=>
	# ops < 3/2*size <=>
	# ops < 1.5*size

	if {(2*$count) < (3*[array size cache])} return

	::file delete -force ${path}.new
	set new [open ${path}.new {RDWR EXCL CREAT APPEND}]
	fconfigure $new -buffering none -encoding utf-8

	# Compress current contents into a single multi-key load operation.
	puts $new [list array set [array get cache]]

	if {$::tcl_platform(platform) eq "windows"} {
	    # For windows the open channels prevent us from
	    # overwriting the old file. We have to leave
	    # attackers a (small) window of opportunity for
	    # replacing the file with something they own :(
	    close $chan
	    close $new
	    ::file rename -force ${path}.new $path
	    set chan [open ${path} {RDWR EXCL APPEND}]
	    fconfigure $chan -buffering none -encoding utf-8
	} else {
	    # Copy compacted journal over the existing one.
	    ::file rename -force ${path}.new $path
	    close $chan
	    set    chan $new
	}
	return
    }

    method Set {index value} {
	set cache($index) $value
	incr count
	return
    }

    method Unset {index} {
	unset cache($index)
	incr count
	return
    }

    method Array {cmd detail} {
	# syntax : set   dict
	# ...... : unset pattern

	if {$cmd eq "set"} {
	    array set cache $detail
	} elseif {$cmd eq "unset"} {
	    array unset cache $detail
	} else {
	    return -code error "Illegal command \"$cmd\""
	}
	incr count
	return
    }

    method Invalidate {} {
	if {!$cvalid} return
	set cvalid 0
	unset cache
	return
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready to go

::tie::register ::tie::std::file as file
package provide   tie::std::file 1.0.4
