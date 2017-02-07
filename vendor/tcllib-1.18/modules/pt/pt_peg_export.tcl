# pt_peg_export.tcl --
#
#	Exporting parsing expression grammars into other formats.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pt_peg_export.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

# Each object manages a set of plugins for the conversion of parsing
# expression grammars into some textual representation. I.e. this
# object manages the conversion to specialized serializations of
# parsing expression grammars.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require configuration
package require pt::peg
package require pluginmgr
package require snit

# ### ### ### ######### ######### #########
## API

snit::type ::pt::peg::export {

    # ### ### ### ######### ######### #########
    ## Options :: None

    # ### ### ### ######### ######### #########
    ## Creation, destruction.

    constructor {} {
	install myconfig using ::configuration ${selfns}::CONFIG
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
    ## Convert from the Tcl index serialization to other formats.

    method {export object} {obj {format {}}} {
	return [$self export serial [$obj serialize] $format]
    }

    method {export serial} {serial {format {}}} {
	set serial [pt::peg canonicalize $serial]
	set plugin [$self GetPlugin $format]

	# We have a plugin, now feed it.

	set configuration [$myconfig get]

	return [$plugin do export $serial $configuration]
    }

    # ### ### ### ######### ######### #########
    ## Internal methods

    method GetPlugin {format} {
	if {$format eq {}} { set format text }

	if {![info exists myplugin($format)]} {
	    set plugin [pluginmgr ${selfns}::fmt-$format \
			       -pattern pt::peg::export::* \
			       -api { export } \
			       -setup [mymethod PluginSetup]]
	    ::pluginmgr::paths $plugin pt::peg::export
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
	$ip eval {package provide pt::peg::export::plugin 1}
	return
    }

    # ### ### ### ######### ######### #########
    ## State

    # Array serving as a cache for the various plugin managers holding
    # a specific export plugin.

    variable myplugin -array {}

    # A component managing the configuration given to the export
    # plugins when they are invoked.

    component myconfig -public configuration

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide pt::peg::export 1
return
