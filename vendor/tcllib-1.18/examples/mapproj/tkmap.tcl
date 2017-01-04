#!/usr/bin/env tclsh
## -*- tcl -*-
# tkmap.tcl --
#
#	Example application demonstrating the use of Tcllib's 'mapproj'
#	package.

package require Tcl 8.4
package require Tk 8.4
package require mapproj 1.0

#----------------------------------------------------------------------
#
# Module for reading NCAR DS780.0 is included literally
#

namespace eval ncar780_0 {
    variable libdir [file dirname [info script]]
    variable mapFile [file join $libdir ncar780.txt]
    namespace export readMap cancelReadMap
}

#----------------------------------------------------------------------
#
# ncar780_0::readMap --
#
#	Read in the continental outlines from NCAR data set 780.0.
#
# Parameters:
#	lineCallback
#		Callback to make after each polyline is read.
#	doneCallback
#		Callback to make when the entire map has been
#		read.
#
# Results:
#	An integer that identifies the map-reading task.
#
# Side effects:
#	A chain of `after' callbacks is initiated to read the map.
#
# When the ncar780_0::readMap procedure is invoked, it reads in
# the list of line segments from the data set.  Rather than freeze
# the user interface for the amount of time that it takes to
# process this large file, it sets up `after' callbacks that
# actually do the work.
#
# For each polyline that is read from the file, the `lineCallback'
# is executed at global level.  To the callback are appended
# six parameters: the `group ID' (see the documentation for
# NCAR 780.0 for an explanation), the minimum latitude and longitude
# of the line, the maximum latitude and longitude of the line,
# and a list of co-ordinates that have longitude and latitude
# values alternating: {lon1 lat1 lon2 lat2 ...}.
#
# At the end of the file, the `doneCallback' is evaluated at global
# level.
#
# The ncar780_0::cancelReadMap procedure may be used to cancel
# a ncar780_0::readMap call before the map has been completely read
# in.
#
#----------------------------------------------------------------------

proc ncar780_0::readMap {lineCallback doneCallback} {
    variable mapFile
    variable mapReaders
    if {![info exists mapReaders]} {
	set mapReaders 0
    } else {
	incr mapReaders
    }
    upvar #0 [namespace current]::mapReader$mapReaders state
    set state(lineCallback) $lineCallback
    set state(doneCallback) $doneCallback
    set state(channel) [open $mapFile RDONLY]
    readMapGroup $mapReaders
    return $mapReaders
}

#----------------------------------------------------------------------
#
# ncar780_0::cancelReadMap --
#
#	Cancel the operation begun by ncar780_0::readMap
#
# Parameters:
#	reader
#		Token returned by ncar780_0::readMap
#
# Results:
#	None.
#
# Side effects:
#	Cancels the `after' calls set up by ncar780_0::readMap and
#	cleans up variables.
#
#----------------------------------------------------------------------

proc ncar780_0::cancelReadMap {reader} {
    upvar #0 [namespace current]::mapReader$reader state
    catch {
	after cancel $state(idleHandler)
    }
    unset [namespace current]::mapReader$reader
    return
}

#----------------------------------------------------------------------
#
# ncar780_0::readMapGroup --
#
#	Read a single group of points from the NCAR 780.0 data set.
#
# Parameters:
#	reader
#		Token identifying the map-reading process.
#
# Results:
#	None.
#
# Side effects:
#	Reads a group of points from the file, and invokes the
#	line callback (after each group) and the done callback
#	(at end of file).  If end of file has not been reached,
#	schedules an `after' callback to process the next group.
#
#----------------------------------------------------------------------

proc ncar780_0::readMapGroup {reader} {
    upvar #0 [namespace current]::mapReader$reader state

    set f $state(channel)
    for {set i 0} {$i < 10} {incr i} {
	set pointList {}
	if {[gets $f line] >= 0} {
	    regexp {^(........)(.*)} $line junk nPoints line
	    set nPoints [string trim $nPoints]
	    if {$nPoints < 2} {
		close $f
		uplevel #0 $state(doneCallback)
		unset [namespace current]::mapReader$reader
		return
	    }
	    regexp {^(........)(.*)} $line junk groupId line
	    set groupId [string trim $groupId]
	    regexp {^(........)(.*)} $line junk maxLat line
	    set maxLat [string trim $maxLat]
	    regexp {^(........)(.*)} $line junk minLat line
	    set minLat [string trim $minLat]
	    regexp {^(........)(.*)} $line junk maxLon line
	    set maxLon [string trim $maxLon]
	    regexp {^(........)(.*)} $line junk minLon line
	    set minLon [string trim $minLon]
	    set pointList {}
	    set ptsLeft 0
	    for {set i 0} {$i < $nPoints} {incr i 2} {
		if {$ptsLeft == 0} {
		    gets $f line
		    set ptsLeft 5
		}
		regexp {^(........)(........)(.*)} $line junk lat lon line
		lappend pointList [string trim $lon] [string trim $lat]
		incr ptsLeft -1
	    }
	    uplevel \#0 $state(lineCallback) [list $groupId \
						  $minLat $minLon $maxLat $maxLon \
						  $pointList]

	} else {
	    unset [namespace current]::mapReader$reader
	    close $f
	    uplevel #0 $doneCallback
	    return
	}
    }
    set state(idleHandler) [after 2 [namespace code \
					 [list readMapGroup $reader]]]
    return
}

#
#----------------------------------------------------------------------

# plot --
#
#	Plots a line in the '.c' canvas.
#
# Parameters:
#	id - Line ID from the NCAR DS780.0 file.  'id$id' will be added as
#	     a canvas tag for the plotted line.
#	la0, lo0 - Co-ordinates of the southwest corner of the bounding box
#	la1, lo1 - Co-ordinates of the northeast corenr of the bounding box
#	ptlist - List of points on the line, expressed as alternating
#	         longitude and latitude in degrees.
#
# Results:
#	None.
#
# Side effects:
#	Line is added to the canvas '.c', scaled to 100 pixels per Earth
#	radius.

proc plot {id la0 lo0 la1 lo1 ptlist} {
    variable toProjCmd
    set command [list .c create line]
    foreach {lo la} $ptlist {
	set ok 0
	set pcmd $toProjCmd
	lappend pcmd $lo $la
	foreach {x y} [eval $pcmd] {
	    set ok 1
	}
	if {!$ok
	    || ([info exists lastx] && hypot($x-$lastx, $y-$lasty) > 0.25)} {
	    if {[llength $command] >= 7} {
		if {$id == 0} {
		    lappend command -fill \#cccccc
		} else {
		    lappend command -fill \#cc0000
		}
		eval $command
	    } 
	    set command [list .c create line]
	} 
	if {$ok} {
	    lappend command [expr {316 + 100 * $x}] \
		[expr {316 - 100 * $y}]
	    set lastx $x
	    set lasty $y
	}
    }
    if {[llength $command] >= 7} {
	if {$id == 0} {
	    lappend command -fill \#cccccc
	} else {
	    lappend command -fill \#cc0000
	}
	lappend command -tags id$id
	eval $command
    }
    return
}

# done --
#
#	Completes the plot of the map
#
# Results:
#	None.
#
# Side effects:
#	Updates the canvas's scrollregion to its bounding box.

proc done {} {
    variable reader
    unset reader
    .c configure -scrollregion [.c bbox all]
    return
}

# locate --
#
#	Computes longitude and latitude of a point on the map
#
# Parameters:
#	w -- Path name of the canvas showing the map
#	x,y -- Window co-ordinates of the point to convert
#
# Results:
#	None.
#
# Side effects:
#	Stores longitude and latitude (in degrees) in 'lon' and 'lat'.

proc locate {w x y} {
    variable lon
    variable lat
    variable fromProjCmd
    set x [$w canvasx $x]
    set y [$w canvasy $y]
    set x [expr {($x - 316.) / 100.}]
    set y [expr {(316. - $y) / 100.}]
    set pcmd $fromProjCmd
    lappend pcmd $x $y
    foreach {lon lat} [eval $pcmd] break
    return
}

# showMap --
#
#	Redisplays the world map
#
# Results:
#	None.
#
# Side effects:
#	Launches a reader to read the NCAR data set and plot the continent
#	outlines.  Cancels any existing reader.  Has a check so that new
#	readers are launched at most every half second.

proc showMap {} {
    variable showMapScheduled
    if {[info exists showMapScheduled]} {
	after cancel $showMapScheduled
	unset showMapScheduled
    }
    set showMapScheduled [after 500 showMap2]
    return
}
proc showMap2 {} {
    variable showMapScheduled
    if {[info exists showMapScheduled]} {
	after cancel $showMapScheduled
	unset showMapScheduled
    }
    variable projection
    variable fromProjCmd
    variable toProjCmd
    variable reader
    if {[info exists reader]} {
	ncar780_0::cancelReadMap $reader
	unset reader
    }
    .c delete all

    foreach {toProjCmd fromProjCmd} [makeProjCmds $projection] break
    for {set m -180} {$m <= 180} {incr m 15} {
	set plist {}
	for {set p -89} {$p <= 89} {incr p} {
	    lappend plist $m $p
	}
	plot 0 -90.0 $m 90.0 $m $plist
    }
    for {set p -75} {$p <= 75} {incr p 15} {
	set plist {}
	for {set m -180} {$m <= 180} {incr m} {
	    lappend plist $m $p
	}
	plot 0 $p -180.0 $p 180.0 $plist
    }
    set reader [ncar780_0::readMap plot done]
    return
}

# makeProjCmds --
#
#	Switches projections, making commands to convert to/from the new 
#	projection.
#
# Parameters:
#	pro -- Name of the new projection.
#	comps -- 1 if GUI components for the projection's parameters are
#		 required, 0 otherwise.
#
# Results:
#	Returns a list of command prefixes, {toProj fromProj}.  'toProj'
#	should have longitude and latitude postpended, and converts to
#	the given projection.  'fromProj' should have canvas x and y appended
#	and converts back to longitude and latitude.
#
# Side effects:
#	If requested, changes the GUI to show components for the projection's
#	parameters.

proc makeProjCmds {pro {comps 1}} {
    variable phi_0
    variable phi_1
    variable phi_2
    variable lambda_0
    set toProjCmd ::mapproj::to$pro
    set alist [info args ::mapproj::to$pro]
    if {[llength $alist] < 2} {
	return -code error "$toProjCmd has too few args"
    }
    if {[lindex $alist end-1] ne {lambda}
	|| [lindex $alist end] ne {phi}} {
	return -code error "$toProjCmd does not accept lambda and phi"
    }
    foreach a [lrange $alist 0 end-2] {
	switch -exact $a {
	    phi_0 - phi_1 - phi_2 - lambda_0 {
		lappend toProjCmd [set $a]
		set have($a) {}
	    }
	    default {
		return -code error "$toProjCmd accepts an unknown arg $a"
	    }
	}
    }
    set fromProjCmd ::mapproj::from$pro
    set alist [info args ::mapproj::from$pro]
    if {[llength $alist] < 2} {
	return -code error "$fromProjCmd has too few args"
    }
    if {[lindex $alist end-1] ne {x}
	|| [lindex $alist end] ne {y}} {
	return -code error "$fromProjCmd does not accept x and y"
    }
    foreach a [lrange $alist 0 end-2] {
	switch -exact $a {
	    phi_0 - phi_1 - phi_2 - lambda_0 {
		lappend fromProjCmd [set $a]
		set have($a) {}
	    }
	    default {
		return -code error "$fromProjCmd accepts an unknown arg $a"
	    }
	}
    }
    if {$comps} {
	foreach item {lambda_0 phi_0 phi_1 phi_2} {
	    if {[info exists have($item)] && ![winfo ismapped .extras.$item]} {
		grid .extras.$item -sticky ew -columnspan 2
	    } elseif {![info exists have($item)]
		      && [winfo ismapped .extras.$item]} {
		grid forget .extras.$item
	    }
	}
    }
    return [list $toProjCmd $fromProjCmd]
}	

# isProjection --
#
#	Tests whether a given name represents a known map projection.
#
# Parameters:
#	pro -- Name to test
#
# Results:
#	Returns 1 if the name is a known projection, 0 otherwise.

proc isProjection {pro} {
    if {![catch {makeProjCmds $pro 0} r]} {
	return 1
    } else {
	puts $r
	return 0
    }
}

# Parameters of various projections

set phi_0 15.0;				# Reference latitude
set phi_1 -30.0;			# First standard parallel
set phi_2 60.0;				# Second standard parallel
set lambda_0 12.0;			# Reference longitude

# Create a GUI to display the map

canvas .c -width 632 -height 632 -bg white
listbox .projs -height 10 -width 30 -yscrollcommand [list .projsy set]
scrollbar .projsy -orient vertical -command [list .projs yview]
frame .extras
label .extras.llat -text "Latitude:" -anchor w
entry .extras.elat -width 20 -textvariable lat -state disabled
label .extras.llon -text "Longitude:" -anchor w
entry .extras.elon -width 20 -textvariable lon -state disabled
scale .extras.phi_0 -label "Reference latitude" \
    -variable phi_0 -from -90.0 -to 90.0 -length 180 -orient horizontal
scale .extras.lambda_0 -label "Reference longitude" \
    -variable lambda_0 -from -180.0 -to 180.0 -length 180 -orient horizontal
scale .extras.phi_1 -label "First standard parallel" \
    -variable phi_1 -from -90.0 -to 90.0 -length 180 -orient horizontal
scale .extras.phi_2 -label "Second standard parallel" \
    -variable phi_2 -from -90.0 -to 90.0 -length 180 -orient horizontal

grid .extras.llat     .extras.elat -sticky nsew
grid .extras.llon     .extras.elon -sticky nsew
grid .extras.lambda_0 -            -sticky nsew
grid .extras.phi_0    -            -sticky nsew
grid .extras.phi_1    -            -sticky nsew
grid .extras.phi_2    -            -sticky nsew

grid rowconfigure .extras 20 -weight 1

grid .c .projs  .projsy  -sticky nsew
grid ^  .extras -        -sticky nsew

grid rowconfigure . 1 -weight 1
grid columnconfigure . 0 -weight 1

foreach cmd [info commands ::mapproj::to*] {
    if {[regexp ^::mapproj::to(.*) $cmd -> pro]
	&& [namespace origin ::mapproj::from$pro] ne {}
	&& [isProjection $pro]} {
	lappend prolist $pro
    }
}

bind .c <1> {locate %W %x %y}
bind .projs <<ListboxSelect>> {
    foreach p [.projs curselection] {
	set projection [.projs get $p]
    }
    showMap
}
foreach pro [lsort -dictionary $prolist] {
    .projs insert end $pro
}

.projs selection set 0
event generate .projs <<ListboxSelect>>

trace add variable phi_0 write "showMap;\#"
trace add variable phi_1 write "showMap;\#"
trace add variable phi_2 write "showMap;\#"
trace add variable lambda_0 write "showMap;\#"
