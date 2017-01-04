## -*- tcl -*-
# ### ### ### ######### ######### #########

## Fetch tile images for maps based on the slippy scheme.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl     8.4 ; # No {*}-expansion :(, no ** either, nor lassign

# Tk8.6 "image photo" supports PNG directly. Earlier versions requires
# the IMG extension, aka TkImg.
#	See http://sourceforge.net/projects/tkimg

if {[catch {
    package require Tk 8.6
}]} {
    package require Tk;
    package require img::png    ; # Slippy tiles use the PNG image file format.
}

package require map::slippy ; # Slippy contants
package require http        ; # Retrieval method
package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type map::slippy::fetcher {
    # ### ### ### ######### ######### #########
    ## API

    constructor {levels baseurl} {
	set mybase   $baseurl
	set mylevels $levels
	return
    }

    # ### ### ### ######### ######### #########
    ## Query API

    method levels     {} { return $mylevels }
    method tileheight {} {map::slippy tile size}
    method tilewidth  {} {map::slippy tile size}

    # ### ### ### ######### ######### #########
    ## Tile retrieval API

    method get {tile donecmd} {
	# tile = list (zoom, row, col)
	if {![map::slippy tile valid $tile $mylevels msg]} {
	    return -code error $msg
	}

	# Compose the url for the requested tile

	set url [urlOf $tile]

	# Initiate tile download.

	# Note however that a download is actually started if and only
	# if there is no download of this tile already in progress. If
	# there is we simply register the new request with that
	# download. When the download is done we convert the data to
	# an in-memory image and provide it to all the waiting requests.

	lappend mypending($url) $donecmd
	if {[llength $mypending($url)] > 1} return

	# We keep the retrieved image data in memory, 256x256 is not
	# that large for todays RAM sizes (Seen 124K max so far).

	if {[catch {
	    set token [http::geturl $url -binary 1 -command [mymethod Done] \
                          -timeout 60000]	    
	}]} {
	    puts $::errorInfo
	    # Some errors, like invalid urls, raise errors synchro-
	    # nously, even if a callback -command is specified.
	    after idle [linsert $donecmd end unset $tile]
	    return
	}

	# Remember the download settings.
	set mytoken($token) [list $url $tile]
	#puts "GET\t($url) = $token"
	return
    }

    method Done {token} {
	#puts GOT/$token

	# We get the request settings and waiting callbacks first, and
	# clean them up immediately, keeping the object state
	# consistent even in the face of recursive calls. (Which
	# should not be possible here).

	foreach {url tile} $mytoken($token) break
	set requests $mypending($url)

	unset mytoken($token)
	unset mypending($url)

	# Then we get the request results, and clean them up as well.

	set status [http::status $token]
	set ncode  [http::ncode  $token]
	set data   [http::data   $token]
	http::cleanup $token

	#puts URL|$url
	#puts STT|$status
	#puts COD|[http::code $token]
	#puts NCO|[http::ncode $token]
	#puts ERR|[http::error $token]

	# Check whether the retrieval failed, bad url, server out,
	# etc. or not, and report if yes.

	if {($status ne "ok") || ($ncode != 200)} {
	    # error, eof, and other non-ok conditions.
	    foreach d $requests { 
		after idle [linsert $d end unset $tile]
	    }
	    return
	}

	# The request was ok. Note that we assume that the slippy
	# server is not redirecting us to some other url. We expect
	# the image at exactly this location. A redirection is treated
	# as failure, see the check above.

	#puts \t|[string length $data]|

	if {[catch {
	    set tileimage [image create photo -data $data]
	}]} {
	    # XXX AK: Here we need a better way to report internal
	    # problems. Maybe just throw the error?
	    #puts $::errorInfo
	    #puts $data
	    
	    foreach d $requests { 
		after idle [linsert $d end unset $tile]
	    }
	    return
	}

	# Finally we have the image we seek, and can report it.

	foreach d $requests { 
	    after idle [linsert $d end set $tile $tileimage]
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal commands

    proc urlOf {tile} {
	upvar 1 mybase mybase
	foreach {z r c} $tile break
	return $mybase/$z/$c/$r.png
    }

    # ### ### ### ######### ######### #########
    ## State

    variable mybase   {} ; # Base url to the tiles.
    variable mylevels 0  ; # Number of zoom levels (0...mylevels-1)

    # State of all http requests currently in flight.

    variable mypending -array {} ; # tile url   -> list (done-cmd-prefix)
    variable mytoken   -array {} ; # http token -> list (tile url, tile id)

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide map::slippy::fetcher 0.4
