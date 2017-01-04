# traverse.tcl --
#
#	Directory traversal.
#
# Copyright (c) 2006-2015 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: traverse.tcl,v 1.9 2012/08/29 20:42:19 andreas_kupries Exp $

package require Tcl 8.3

# OO core
if {[package vsatisfies [package present Tcl] 8.5]} {
    # Use new Tcl 8.5a6+ features to specify the allowed packages.
    # We can use anything above 1.3. This means v2 as well.
    package require snit 1.3-
} else {
    # For Tcl 8.{3,4} only snit1 of a suitable patchlevel is possible.
    package require snit 1.3
}
package require control  ; # Helpers for control structures
package require fileutil ; # -> fullnormalize

snit::type ::fileutil::traverse {

    # Incremental directory traversal.

    # API
    # create  %AUTO% basedirectory options... -> object
    # next    filevar                         -> boolean
    # foreach filevar script
    # files                                   -> list (path ...)

    # Options
    # -prefilter command-prefix
    # -filter    command-prefix
    # -errorcmd  command-prefix

    # Use cases
    #
    # (a) Basic incremental
    # - Create and configure a traversal object.
    # - Execute 'next' to retrieve one path at a time,
    #   until the command returns False, signaling that
    #   the iterator has exhausted the supply of paths.
    #   (The path is stored in the named variable).
    #
    # The execution of 'next' can be done in a loop, or via event
    # processing.

    # (b) Basic loop
    # - Create and configure a traversal object.
    # - Run a script for each path, using 'foreach'.
    #   This is a convenient standard wrapper around 'next'.
    #
    # The loop properly handles all possible Tcl result codes.

    # (c) Non-incremental, non-looping.
    # - Create and configure a traversal object.
    # - Retrieve a list of all paths via 'files'.

    # The -prefilter callback is executed for directories. Its result
    # determines if the traverser recurses into the directory or not.
    # The default is to always recurse into all directories. The call-
    # back is invoked with a single argument, the path of the
    # directory.
    #
    # The -filter callback is executed for all paths. Its result
    # determines if the current path is a valid result, and returned
    # by 'next'. The default is to accept all paths as valid. The
    # callback is invoked with a single argument, the path to check.

    # The -errorcmd callback is executed for all paths the traverser
    # has trouble with. Like being unable to cd into them, get their
    # status, etc. The default is to ignore any such problems. The
    # callback is invoked with a two arguments, the path for which the
    # error occured, and the error message. Errors thrown by the
    # filter callbacks are handled through this callback too. Errors
    # thrown by the error callback itself are not caught and ignored,
    # but allowed to pass to the caller, usually of 'next'.

    # Note: Low-level functionality, version and platform dependent is
    # implemented in procedures, and conditioally defined for optimal
    # use of features, etc. ...

    # Note: Traversal is done in depth-first pre-order.

    # Note: The options are handled only during
    # construction. Afterward they are read-only and attempts to
    # modify them will cause the system to throw errors.

    # ### ### ### ######### ######### #########
    ## Implementation

    option -filter    -default {} -readonly 1
    option -prefilter -default {} -readonly 1
    option -errorcmd  -default {} -readonly 1

    constructor {basedir args} {
	set _base $basedir
	$self configurelist $args
	return
    }

    method files {} {
	set files {}
	$self foreach f {lappend files $f}
	return $files
    }

    method foreach {fvar body} {
	upvar 1 $fvar currentfile

	# (Re-)initialize the traversal state on every call.
	$self Init

	while {[$self next currentfile]} {
	    set code [catch {uplevel 1 $body} result]

	    # decide what to do upon the return code:
	    #
	    #               0 - the body executed successfully
	    #               1 - the body raised an error
	    #               2 - the body invoked [return]
	    #               3 - the body invoked [break]
	    #               4 - the body invoked [continue]
	    # everything else - return and pass on the results
	    #
	    switch -exact -- $code {
		0 {}
		1 {
		    return -errorinfo [::control::ErrorInfoAsCaller uplevel foreach]  \
			    -errorcode $::errorCode -code error $result
		}
		3 {
		    # FRINK: nocheck
		    return
		}
		4 {}
		default {
		    return -code $code $result
		}
	    }
	}
	return
    }

    method next {fvar} {
	upvar 1 $fvar currentfile

	# Initialize on first call.
	if {!$_init} {
	    $self Init
	}

	# We (still) have valid paths in the result stack, return the
	# next one.

	if {[llength $_results]} {
	    set top      [lindex   $_results end]
	    set _results [lreplace $_results end end]
	    set currentfile $top
	    return 1
	}

	# Take the next directory waiting in the processing stack and
	# fill the result stack with all valid files and sub-
	# directories contained in it. Extend the processing queue
	# with all sub-directories not yet seen already (!circular
	# symlinks) and accepted by the prefilter. We stop iterating
	# when we either have no directories to process anymore, or
	# the result stack contains at least one path we can return.

	while {[llength $_pending]} {
	    set top      [lindex   $_pending end]
	    set _pending [lreplace $_pending end end]

	    # Directory accessible? Skip if not.
	    if {![ACCESS $top]} {
		Error $top "Inacessible directory"
		continue
	    }

	    # Expand the result stack with all files in the directory,
	    # modulo filtering.

	    foreach f [GLOBF $top] {
		if {![Valid $f]} continue
		lappend _results $f
	    }

	    # Expand the result stack with all sub-directories in the
	    # directory, modulo filtering. Further expand the
	    # processing stack with the same directories, if not seen
	    # yet and modulo pre-filtering.

	    foreach f [GLOBD $top] {
		if {
		    [string equal [file tail $f]  "."] ||
		    [string equal [file tail $f] ".."]
		} continue

		if {[Valid $f]} {
		    lappend _results $f
		}

		Enter $top $f
		if {[Cycle $f]} continue

		if {[Recurse $f]} {
		    lappend _pending $f
		}
	    }

	    # Stop expanding if we have paths to return.

	    if {[llength $_results]} {
		set top      [lindex   $_results end]
		set _results [lreplace $_results end end]
		set currentfile $top
		return 1
	    }
	}

	# Allow re-initialization with next call.

	set _init 0
	return 0
    }

    # ### ### ### ######### ######### #########
    ## Traversal state

    # * Initialization flag. Checked in 'next', reset by next when no
    #   more files are available. Set in 'Init'.
    # * Base directory (or file) to start the traversal from.
    # * Stack of prefiltered unknown directories waiting for
    #   processing, i.e. expansion (TOP at end).
    # * Stack of valid paths waiting to be returned as results.
    # * Set of directories already visited (normalized paths), for
    #   detection of circular symbolic links.

    variable _init         0  ; # Initialization flag.
    variable _base         {} ; # Base directory.
    variable _pending      {} ; # Processing stack.
    variable _results      {} ; # Result stack.

    # sym link handling (to break cycles, while allowing the following of non-cycle links).
    # Notes
    # - path parent   tracking is lexical.
    # - path identity tracking is based on the normalized path, i.e. the path with all
    #   symlinks resolved.
    # Maps
    # - path -> parent     (easier to follow the list than doing dirname's)
    # - path -> normalized (cache to avoid redundant calls of fullnormalize)
    # cycle <=> A parent's normalized form (NF) is identical to the current path's NF

    variable _parent -array {}
    variable _norm   -array {}

    # ### ### ### ######### ######### #########
    ## Internal helpers.

    proc Enter {parent path} {
	#puts ___E|$path
	upvar 1 _parent _parent _norm _norm
	set _parent($path) $parent
	set _norm($path)   [fileutil::fullnormalize $path]
    }

    proc Cycle {path} {
	upvar 1 _parent _parent _norm _norm
	set nform $_norm($path)
	set paren $_parent($path)
	while {$paren ne {}} {
	    if {$_norm($paren) eq $nform} { return yes }
	    set paren $_parent($paren)
	}
	return no
    }

    method Init {} {
	array unset _parent *
	array unset _norm   *

	# Path ok as result?
	if {[Valid $_base]} {
	    lappend _results $_base
	}

	# Expansion allowed by prefilter?
	if {[file isdirectory $_base] && [Recurse $_base]} {
	    Enter {} $_base
	    lappend _pending $_base
	}

	# System is set up now.
	set _init 1
	return
    }

    proc Valid {path} {
	#puts ___V|$path
	upvar 1 options options
	if {![llength $options(-filter)]} {return 1}
	set path [file normalize $path]
	set code [catch {uplevel \#0 [linsert $options(-filter) end $path]} valid]
	if {!$code} {return $valid}
	Error $path $valid
	return 0
    }

    proc Recurse {path} {
	#puts ___X|$path
	upvar 1 options options _norm _norm
	if {![llength $options(-prefilter)]} {return 1}
	set path [file normalize $path]
	set code [catch {uplevel \#0 [linsert $options(-prefilter) end $path]} valid]
	if {!$code} {return $valid}
	Error $path $valid
	return 0
    }

    proc Error {path msg} {
	upvar 1 options options
	if {![llength $options(-errorcmd)]} return
	set path [file normalize $path]
	uplevel \#0 [linsert $options(-errorcmd) end $path $msg]
	return
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
##

# The next three helper commands for the traverser depend strongly on
# the version of Tcl, and partially on the platform.

# 1. In Tcl 8.3 using -types f will return only true files, but not
#    links to files. This changed in 8.4+ where links to files are
#    returned as well. So for 8.3 we have to handle the links
#    separately (-types l) and also filter on our own.
#    Note that Windows file links are hard links which are reported by
#    -types f, but not -types l, so we can optimize that for the two
#    platforms.
#
# 2. In Tcl 8.3 we also have a crashing bug in glob (SIGABRT, "stat on
#    a known file") when trying to perform 'glob -types {hidden f}' on
#    a directory without e'x'ecute permissions. We code around by
#    testing if we can cd into the directory (stat might return enough
#    information too (mode), but possibly also not portable).
#
#    For Tcl 8.2 and 8.4+ glob simply delivers an empty result
#    (-nocomplain), without crashing. For them this command is defined
#    so that the bytecode compiler removes it from the bytecode.
#
#    This bug made the ACCESS helper necessary.
#    We code around the problem by testing if we can cd into the
#    directory (stat might return enough information too (mode), but
#    possibly also not portable).

if {[package vsatisfies [package present Tcl] 8.5]} {
    # Tcl 8.5+.
    # We have to check readability of "current" on our own, glob
    # changed to error out instead of returning nothing.

    proc ::fileutil::traverse::ACCESS {args} {return 1}

    proc ::fileutil::traverse::GLOBF {current} {
	if {![file readable $current] ||
	    [BadLink $current]} {
	    return {}
	}

	set res [lsort -unique [concat \
		     [glob -nocomplain -directory $current -types f          -- *] \
		     [glob -nocomplain -directory $current -types {hidden f} -- *]]]

	# Look for broken links (They are reported as neither file nor directory).
	foreach l [lsort -unique [concat \
		       [glob -nocomplain -directory $current -types l          -- *] \
		       [glob -nocomplain -directory $current -types {hidden l} -- *]]] {
	    if {[file isfile      $l]} continue
	    if {[file isdirectory $l]} continue
	    lappend res $l
	}
	return [lsort -unique $res]
    }

    proc ::fileutil::traverse::GLOBD {current} {
	if {![file readable $current] ||
	    [BadLink $current]} {
	    return {}
	}

	lsort -unique [concat \
	   [glob -nocomplain -directory $current -types d          -- *] \
	   [glob -nocomplain -directory $current -types {hidden d} -- *]]
    }

    proc ::fileutil::traverse::BadLink {current} {
	if {[file type $current] ne "link"} { return no }

	set dst [file join [file dirname $current] [file readlink $current]]

	if {![file exists   $dst] ||
	    ![file readable $dst]} {
	    return yes
	}

	return no
    }

} elseif {[package vsatisfies [package present Tcl] 8.4]} {
    # Tcl 8.4+.
    # (Ad 1) We have -directory, and -types,
    # (Ad 2) Links are returned for -types f/d if they refer to files/dirs.
    # (Ad 3) No bug to code around

    proc ::fileutil::traverse::ACCESS {args} {return 1}

    proc ::fileutil::traverse::GLOBF {current} {
	set res [concat \
		     [glob -nocomplain -directory $current -types f          -- *] \
		     [glob -nocomplain -directory $current -types {hidden f} -- *]]

	# Look for broken links (They are reported as neither file nor directory).
	foreach l [concat \
		       [glob -nocomplain -directory $current -types l          -- *] \
		       [glob -nocomplain -directory $current -types {hidden l} -- *] ] {
	    if {[file isfile      $l]} continue
	    if {[file isdirectory $l]} continue
	    lappend res $l
	}
	return $res
    }

    proc ::fileutil::traverse::GLOBD {current} {
	concat \
	    [glob -nocomplain -directory $current -types d          -- *] \
	    [glob -nocomplain -directory $current -types {hidden d} -- *]
    }

} else {
    # 8.3.
    # (Ad 1) We have -directory, and -types,
    # (Ad 2) Links are NOT returned for -types f/d, collect separately.
    #        No symbolic file links on Windows.
    # (Ad 3) Bug to code around.

    proc ::fileutil::traverse::ACCESS {current} {
	if {[catch {
	    set h [pwd] ; cd $current ; cd $h
	}]} {return 0}
	return 1
    }

    if {[string equal $::tcl_platform(platform) windows]} {
	proc ::fileutil::traverse::GLOBF {current} {
	    concat \
		[glob -nocomplain -directory $current -types f          -- *] \
		[glob -nocomplain -directory $current -types {hidden f} -- *]]
	}
    } else {
	proc ::fileutil::traverse::GLOBF {current} {
	    set l [concat \
		       [glob -nocomplain -directory $current -types f          -- *] \
		       [glob -nocomplain -directory $current -types {hidden f} -- *]]

	    foreach x [concat \
			   [glob -nocomplain -directory $current -types l          -- *] \
			   [glob -nocomplain -directory $current -types {hidden l} -- *]] {
		if {[file isdirectory $x]} continue
		# We have now accepted files, links to files, and broken links.
		lappend l $x
	    }

	    return $l
	}
    }

    proc ::fileutil::traverse::GLOBD {current} {
	set l [concat \
		   [glob -nocomplain -directory $current -types d          -- *] \
		   [glob -nocomplain -directory $current -types {hidden d} -- *]]

	foreach x [concat \
		       [glob -nocomplain -directory $current -types l          -- *] \
		       [glob -nocomplain -directory $current -types {hidden l} -- *]] {
	    if {![file isdirectory $x]} continue
	    lappend l $x
	}

	return $l
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide fileutil::traverse 0.6
