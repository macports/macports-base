# import.tcl --
#
#	Importing indices into other formats.
#
# Copyright (c) 2009-2019 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# Each object manages a set of plugins for the conversion of keyword
# indices into some textual representation. I.e. this object manages
# the conversion to specialized serializations of keyword indices.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4
package require struct::map
package require doctools::toc::structure
package require fileutil::paths
package require pluginmgr
package require snit

# ### ### ### ######### ######### #########
## API

snit::type ::doctools::toc::import {

    # ### ### ### ######### ######### #########
    ## Options :: None

    # ### ### ### ######### ######### #########
    ## Creation, destruction.

    constructor {} {
	install myconfig  using ::struct::map     ${selfns}::config
	install myinclude using ::fileutil::paths ${selfns}::include
	return
    }

    destructor {
	$myconfig  destroy
	$myinclude destroy
	# Clear the cache of loaded import plugins.
	foreach k [array names myplugin] {
	    $myplugin($k) destroy
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Convert from other formats to the Tcl toc serialization

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

	set     configuration [$myconfig get]
	lappend configuration user   $::tcl_platform(user)
	lappend configuration format [$plugin plugin]

	return [$plugin do import $text $configuration]
    }

    method {import file} {path {format {}}} {
	# The plugin is not trusted to handle the file to convert.
	return [$self import text [fileutil::cat $path] $format]
    }

    # ### ### ### ######### ######### #########
    ## Internal methods

    method GetPlugin {format} {
	if {$format eq {}} { set format doctoc }

	if {![info exists myplugin($format)]} {
	    set plugin [pluginmgr ${selfns}::fmt-$format \
			       -pattern doctools::toc::import::* \
			       -api { import } \
			       -setup [mymethod PluginSetup]]
	    ::pluginmgr::paths $plugin doctools::toc::import
	    $plugin load $format
	    set myplugin($format) $plugin
	} else {
	    set plugin $myplugin($format)
	}

	return $plugin
    }

    method PluginSetup {mgr ip} {
	# Inject a pseudo package into the plugin interpreter the
	# import plugins can use to check that they were loaded into a
	# proper environment.
	$ip eval {package provide doctools::toc::import::plugin 1}

	# The import plugins may use msgcat, which requires access to
	# tcl_platform during its initialization, and won't have it by
	# default. We trust them enough to hand out the information.
	# TODO :: remove user/wordSize, etc. We need only 'os'.
	$ip eval [list array set ::tcl_platform [array get ::tcl_platform]]

	# Provide an alias-command a plugin can use to ask for any
	# file, so that it can handle the processing of include files,
	# should its format have that concept. Like doctoc. The alias
	# will be directed to a method of ours and use the configured
	# include paths to find the file, analogous to the GetFile
	# procedure of doctools::toc::parse.

	#8.5+: ::interp alias $ip include {} {*}[mymethod IncludeFile]
	eval [linsert [mymethod IncludeFile] 0 ::interp alias $ip include {}]
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

    component myconfig  -public config
    component myinclude -public include

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide doctools::toc::import 0.2.1
return
