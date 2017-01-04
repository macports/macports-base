## -*- tcl -*-
# ### ### ### ######### ######### #########

## A cache we put on top of a slippy fetcher, to satisfy requests for
## tiles from the local filesystem first, if possible.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4     ; # No {*}-expansion :(, no ** either, nor lassign
package require Tk          ; # image photo
package require map::slippy ; # Slippy constants
package require fileutil    ; # Testing paths
package require img::png    ; # We write tile images using the PNG image file format.
package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type map::slippy::cache {
    # ### ### ### ######### ######### #########
    ## API

    constructor {cachedir provider} {
	if {![fileutil::test $cachedir edrw msg]} {
	    return -code error "$type constructor: $msg"
	}
	set mycachedir $cachedir
	set myprovider $provider
	set mylevels   [uplevel \#0 [linsert $myprovider end levels]]
	return
    }

    delegate method * to myprovider
    delegate option * to myprovider

    method valid {tile {msgv {}}} {
	if {$msgv ne ""} { upvar 1 $msgv msg }
	return [map::slippy tile valid $tile $mylevels msg]
    }

    method exists {tile} {
	if {![map::slippy tile valid $tile $mylevels msg]} {
	    return -code error $msg
	}
	return [file exists [FileOf $tile]]
    }

    method get {tile donecmd} {
	if {![map::slippy tile valid $tile $mylevels msg]} {
	    return -code error $msg
	}

	# Query the filesystem for a cached tile and return
	# immediately if such was found.

	set tilefile [FileOf $tile]
	if {[file exists $tilefile]} {
	    set tileimage [image create photo -file $tilefile]
	    after 0 [linsert $donecmd end set $tile $tileimage]
	    return
	}

	# The requested tile is not known to the cache, so we forward
	# the request to our provider and intercept the result to
	# update the cache. Only one retrieval request will be issued
	# if multiple arrive from above.

	lappend mypending($tile) $donecmd
	if {[llength $mypending($tile)] > 1} return

	uplevel \#0 [linsert $myprovider end get $tile [mymethod Done]]
	return
    }

    method {Done set} {tile tileimage} {
	# The requested tile was known to the provider, we can cache
	# the image we got and then hand it over to the original
	# requestor.

	set tilefile [FileOf $tile]
	file mkdir [file dirname $tilefile]
	$tileimage write $tilefile -format png

	set requests $mypending($tile)
	unset mypending($tile)

	# Note. The cache accepts empty callbacks for requests, and if
	# no actual callback 'took' the image it is assumed to be not
	# wanted and destroyed. This allows higher layers to request
	# tiles before needng them without leaking imagas and yet also
	# not throwing them away when a prefetch and regular fetch
	# collide.

	set taken 0
	foreach d $requests {
	    if {![llength $d]} continue
	    uplevel \#0 [linsert $d end set $tile $tileimage]
	    set taken 1
	}

	if {!$taken} {
	    image delete $tileimage
	}
	return
    }

    method {Do unset} {donecmd tile} {
	# The requested tile is not known. Nothing has to change in
	# the cache (it did not know the tile either), the result can
	# be directly handed over to the original requestor.

	uplevel \#0 [linsert $donecmd end unset $tile]
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal commands

    proc FileOf {tile} {
	upvar 1 mycachedir mycachedir
	foreach {z r c} $tile break
	return [file join $mycachedir $z $c $r.png]
    }

    # ### ### ### ######### ######### #########
    ## State

    variable mycachedir {} ; # Directory to cache tiles in.
    variable myprovider {} ; # Command prefix, provider of tiles to cache.
    variable mylevels   {} ; # Zoom-levels, retrieved from provider.

    variable mypending -array {} ; # tile -> list (done-cmd-prefix)

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide map::slippy::cache 0.2
