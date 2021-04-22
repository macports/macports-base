# patch.tcl --
#
#	Application of a diff -ruN patch to a directory tree.
#
# Copyright (c) 2019 Christian Gollwitzer <auriocus@gmx.de>
# with tweaks by Andreas Kupries
# - Factored patch parsing into a helper
# - Replaced `puts` with report callback.

package require Tcl 8.5
package provide textutil::patch 0.1

# # ## ### ##### ######## ############# #####################

namespace eval ::textutil::patch {
    namespace export apply
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################

proc ::textutil::patch::apply {dir striplevel patch reportcmd} {
    set patchdict [Parse $dir $striplevel $patch]

    # Apply, now that we have parsed the patch.
    dict for {fn hunks} $patchdict {
	Report apply $fn
	if {[catch {open $fn} fd]} {
	    set orig {}
	} else {
	    set orig [split [read $fd] \n]
	}
	close $fd

	set patched $orig

	set fail false
	set already_applied false
	set hunknr 1
	foreach hunk $hunks {
	    dict with hunk {
		set oldend [expr {$oldstart+[llength $oldcode]-1}]
		set newend [expr {$newstart+[llength $newcode]-1}]
		# check if the hunk matches
		set origcode [lrange $orig $oldstart $oldend]
		if {$origcode ne $oldcode} {
		    set fail true
		    # check if the patch is already applied
		    set origcode_applied [lrange $orig $newstart $newend]
		    if {$origcode_applied eq $newcode} {
			set already_applied true
			Report fail-already $fn $hunknr
		    } else {
			Report fail $fn $hunknr $oldcode $origcode
		    }
		    break
		}
		# apply patch
		set patched [list \
				 {*}[lrange $patched 0 $newstart-1] \
				 {*}$newcode \
				 {*}[lrange $orig $oldend+1 end]]
	    }
	    incr hunknr
	}

	if {!$fail} {
	    # success - write the result back
	    set fd [open $fn w]
	    puts -nonewline $fd [join $patched \n]
	    close $fd
	}
    }

    return
}

# # ## ### ##### ######## ############# #####################

proc ::textutil::patch::Report args {
    upvar 1 reportcmd reportcmd
    uplevel #0 [list {*}$reportcmd {*}$args]
    ##
    # apply        $fname
    # fail-already $fname $hunkno
    # fail         $fname $hunkno $expected $seen
    ##
}

proc ::textutil::patch::Parse {dir striplevel patch} {
    set patchlines [split $patch \n]
    set inhunk false
    set oldcode {}
    set newcode {}
    set n [llength $patchlines]

    set patchdict {}
    for {set lineidx 0} {$lineidx < $n} {incr lineidx} {
	set line [lindex $patchlines $lineidx]
	if {[string match ---* $line]} {
	    # a diff block starts. Current line should be
	    # --- oldfile date time TZ
	    # Next line should be
	    # +++ newfile date time TZ
	    set in $line
	    incr lineidx
	    set out [lindex $patchlines $lineidx]

	    if {![string match ---* $in] || ![string match +++* $out]} {
		#puts $in
		#puts $out
		return -code error "Patch not in unified diff format, line $lineidx $in $out"
	    }

	    # the quoting is compatible with list
	    lassign $in  -> oldfile
	    lassign $out -> newfile

	    set fntopatch [file join $dir {*}[lrange [file split $oldfile] $striplevel end]]
	    set inhunk false
	    #puts "Found diffline for $fntopatch"
	    continue
	}

	# state machine for parsing the hunks
	set typechar [string index $line 0]
	set codeline [string range $line 1 end]
	switch $typechar {
	    @ {
		if {![regexp {@@\s+\-(\d+),(\d+)\s+\+(\d+),(\d+)\s+@@} $line \
			  -> oldstart oldlen newstart newlen]} {
		    return code -error "Erroneous hunk in line $lindeidx, $line"
		}
		# adjust line numbers for 0-based indexing
		incr oldstart -1
		incr newstart -1
		#puts "New hunk"
		set newcode {}
		set oldcode {}
		set inhunk true
	    }
	    - { # line only in old code
		if {$inhunk} {
		    lappend oldcode $codeline
		}
	    }
	    + { # line only in new code
		if {$inhunk} {
		    lappend newcode $codeline
		}
	    }
	    " " { # common line
		if {$inhunk} {
		    lappend oldcode $codeline
		    lappend newcode $codeline
		}
	    }
	    default {
		# puts "Junk: $codeline";
		continue
	    }
	}
	# test if the hunk is complete
	if {[llength $oldcode]==$oldlen && [llength $newcode]==$newlen} {
	    set hunk [dict create \
			  oldcode $oldcode \
			  newcode $newcode \
			  oldstart $oldstart \
			  newstart $newstart]
	    #puts "hunk complete: $hunk"
	    set inhunk false
	    dict lappend patchdict $fntopatch $hunk
	}
    }

    return $patchdict
}

# # ## ### ##### ######## ############# #####################
return
