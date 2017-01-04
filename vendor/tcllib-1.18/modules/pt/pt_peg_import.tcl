# import.tcl --
#
#	Importing parsing expression grammars from other formats.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pt_peg_import.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

# Each object manages a set of plugins for the creation of parsing
# expression grammars from some textual representation. I.e. this
# object manages the conversion from specialized serializations of
# parsing expression grammars into their standard form.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require paths
package require pt::peg
package require pluginmgr
package require snit

# ### ### ### ######### ######### #########
## API

snit::type ::pt::peg::import {

    # ### ### ### ######### ######### #########
    ## Options :: None

    # ### ### ### ######### ######### #########
    ## Creation, destruction.

    constructor {} {
	install myinclude using ::paths         ${selfns}::INCLUDE
	return
    }

    destructor {
	$myinclude destroy
	# Clear the cache of loaded import plugins.
	foreach k [array names myplugin] {
	    $myplugin($k) destroy
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Convert from other formats to the Tcl PEG serialization

    method {import object text} {obj text {format {}}} {
	$obj deserialize [$self import text $text $format]
	return
    }

    method {import object file} {obj path {format {}}} {
	$obj deserialize [$self import file $path $format]
	return
    }

    # ### ### ### ######### ######### #########

    method {import text} {text {format {}}} {
	set plugin [$self GetPlugin $format]

	return [$plugin do import $text]
    }

    method {import file} {path {format {}}} {
	# The plugin is not trusted to handle the file to convert.
	return [$self import text [fileutil::cat $path] $format]
    }

    # ### ### ### ######### ######### #########
    ## Internal methods

    method GetPlugin {format} {
	if {$format eq {}} { set format text }

	if {![info exists myplugin($format)]} {
	    set plugin [pluginmgr ${selfns}::fmt-$format \
			       -pattern pt::peg::import::* \
			       -api { import } \
			       -setup [mymethod PluginSetup]]
	    ::pluginmgr::paths $plugin pt::peg::import
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
	$ip eval {package provide pt::peg::import::plugin 1}
	return
    }

    method PluginSetup {mgr ip} {
	# Inject a pseudo package into the plugin interpreter the
	# import plugins can use to check that they were loaded into a
	# proper environment.
	$ip eval {package provide pt::peg::import::plugin 1}

	# The import plugins may use msgcat, which requires access to
	# tcl_platform during its initialization, and won't have it by
	# default. We trust them enough to hand out the information.
	# TODO :: remove user/wordSize, etc. We need only 'os'.
	$ip eval [list array set ::tcl_platform [array get ::tcl_platform]]

	# Provide an alias-command a plugin can use to ask for any
	# file, so that it can handle the processing of include files,
	# should its format have that concept. The alias will be
	# directed to a method of ours and use the configured include
	# paths to find the file.

	::interp alias $ip include {} {*}[mymethod IncludeFile]
	return
    }

    method IncludeFile {currentfile path} {
	# result = ok text fullpath error-code error-message

	# Find the file, or not.
	set fullpath [$self Locate $path]
	if {$fullpath eq {}} {
	    return [list 0 {} $path notfound {}]
	}

	# Read contents, or not.
	if {[catch {
	    set data [fileutil::cat $fullpath]
	} msg]} {
	    set error notread
	    set emessage $msg
	    return [list 0 {} $fullpath notread $msg]
	}

	return [list 1 $data $fullpath {} {}]
    }

    method Locate {path} {
	upvar 1 currentfile currentfile

	if {$currentfile ne {}} {
	    set pathstosearch \
		[linsert [$myinclude paths] 0 \
		     [file dirname [file normalize $currentfile]]]
	} else {
	    set pathstosearch [$myinclude paths]
	}

	foreach base $pathstosearch {
	    set try [file join $base $path]
	    if {![file exists $try]} continue
	    return $try
	}
	# Nothing found
	return {}
    }

    # ### ### ### ######### ######### #########
    ## State

    # Array serving as a cache for the various plugin managers holding
    # a specific import plugin.

    variable myplugin -array {}

    # A component managing the configuration given to the import
    # plugins when they are invoked.

    component myinclude -public include

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide pt::peg::import 1
return
