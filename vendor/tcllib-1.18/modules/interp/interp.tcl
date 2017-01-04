# interp.tcl
# Some utility commands for interpreter creation
#
# Copyright (c) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: interp.tcl,v 1.5 2011/11/08 02:40:31 andreas_kupries Exp $

package require Tcl 8.3

# ### ### ### ######### ######### #########
## Requisites

namespace eval ::interp {}

# ### ### ### ######### ######### #########
## Public API

proc ::interp::createEmpty {args} {
    # Create interpreter, predefined path or
    # automatic naming.

    if {[llength $args] > 1} {
	return -code error "wrong#args: Expected ?path?"
    } elseif {[llength $args] == 1} {
	set i [interp create [lindex $args 0]]
    } else {
	set i [interp create]
    }

    # Clear out namespaces and commands, leaving an empty interpreter
    # behind. Take care to delete the rename command last, as it is
    # needed to perform the deletions. We have to keep the 'rename'
    # command until last to allow us to delete all ocmmands. We also
    # have to defer deletion of the ::tcl namespace (if present), as
    # it may contain state for the auto-loader, which may be
    # invoked. This also forces us to defer the deletion of the
    # builtin command 'namespace' so that we can delete ::tcl at last.

    foreach n [interp eval $i [list ::namespace children ::]] {
	if {[string equal $n ::tcl]} continue
	interp eval $i [list namespace delete $n]
    }
    foreach c [interp eval $i [list ::info commands]] {
	if {[string equal $c rename]}    continue
	if {[string equal $c namespace]} continue
	interp eval $i [list ::rename $c {}]
    }

    interp eval $i [list ::namespace delete ::tcl]
    catch {
	# In 8.6 the removal of the ::tcl namespace killed the
	# ensemblified namespace command already, so a deletion will
	# fail. Easier to catch than being conditional.
	interp eval $i [list ::rename namespace {}]
    }
    interp eval $i [list ::rename rename    {}]

    # Done. Result is ready.

    return $i
}

proc ::interp::snitLink {path methods} {
    foreach m $methods {
	set dst   [uplevel 1 [linsert $m 0 mymethod]]
	set alias [linsert $dst 0 interp alias $path [lindex $m 0] {}]
	eval $alias
    }
    return
}

proc ::interp::snitDictLink {path methoddict} {
    foreach {c m} $methoddict {
	set dst   [uplevel 1 [linsert $m 0 mymethod]]
	set alias [linsert $dst 0 interp alias $path $c {}]
	eval $alias
    }
    return
}

# ### ### ### ######### ######### #########
## Ready to go

package provide interp 0.1.2
