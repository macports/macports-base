# doctoc.tcl --
#
#	Exporting indices into other formats.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: export.tcl,v 1.2 2009/11/15 05:50:03 andreas_kupries Exp $

# Each object manages a set of plugins for the conversion of keyword
# indices into some textual representation. I.e. this object manages
# the conversion to specialized serializations of keyword indices.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4
package require doctools::config
package require doctools::toc::structure
package require pluginmgr
package require snit

# ### ### ### ######### ######### #########
## API

snit::type ::doctools::toc::export {

    # ### ### ### ######### ######### #########
    ## Options :: None

    # ### ### ### ######### ######### #########
    ## Creation, destruction.

    constructor {} {
	install myconfig using ::doctools::config ${selfns}::config
	return
    }

    destructor {
	$myconfig destroy
	# Clear the cache of loaded export plugins.
	foreach k [array names myplugin] {
	    $myplugin($k) destroy
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Convert from the Tcl toc serialization to other formats.

    method {export object} {obj {format {}}} {
	return [$self export serial [$obj serialize] $format]
    }

    method {export serial} {serial {format {}}} {
	doctools::toc::structure verify $serial iscanonical

	set plugin [$self GetPlugin $format]

	# We have a plugin, now feed it.

	if {!$iscanonical} {
	    set serial [doctools::toc::structure canonicalize $serial]
	}

	set     configuration [$myconfig get]
	lappend configuration user   $::tcl_platform(user)
	lappend configuraton  format [$plugin plugin]

	return [$plugin do export $serial $configuration]
    }

    # ### ### ### ######### ######### #########
    ## Internal methods

    method GetPlugin {format} {
	if {$format eq {}} { set format doctoc }

	if {![info exists myplugin($format)]} {
	    set plugin [pluginmgr ${selfns}::fmt-$format \
			       -pattern doctools::toc::export::* \
			       -api { export } \
			       -setup [mymethod PluginSetup]]
	    ::pluginmgr::paths $plugin doctools::toc::export
	    $plugin load $format
	    set myplugin($format) $plugin
	} else {
	    set plugin $myplugin($format)
	}

	return $plugin
    }

    method PluginSetup {mgr ip} {
	# Inject a pseudo package into the plugin interpreter the
	# formatters can use to check that they were loaded into a
	# proper environment.
	$ip eval {package provide doctools::toc::export::plugin 1}
	return
    }

    # ### ### ### ######### ######### #########
    ## State

    # Array serving as a cache for the various plugin managers holding
    # a specific export plugin.

    variable myplugin -array {}

    # A component managing the configuration given to the export
    # plugins when they are invoked.

    component myconfig -public config

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide doctools::toc::export 0.1
return
