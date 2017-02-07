# -*- tcl -*-
# Copyright (c) 2009-2014 Andreas Kupries <andreas_kupries@sourceforge.net>

# Canned configuration for the converter to Tcl/PARAM representation,
# causing generation of a proper snit class.

# The requirements of the embedded template are not our requirements.
# @mdgen NODEP: snit
# @mdgen NODEP: pt::rde

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5              ; # Required runtime.

# # ## ### ##### ######## ############# #####################
##

namespace eval ::pt::tclparam::configuration::snit {
    namespace export   def
    namespace ensemble create
}

# # ## ### ##### ######## #############
## Public API

# Check that the proposed serialization of an abstract syntax tree is
# indeed such.

proc ::pt::tclparam::configuration::snit::def {class pkg version cmd} {

    # TODO :: See if we can consolidate the API for converters,
    # TODO :: plugins, export manager, and container in some way.
    # TODO :: Container may make exporter manager available through
    # TODO :: public method.

    # class : is actually the name of the package to generate, and
    #         will be prefixed with :: to make it a proper absolute
    #         class and Tcl namespace name.

    lappend map @@PKG@@     $pkg
    lappend map @@VERSION@@ $version
    lappend map @@CLASS@@   $class
    lappend map \n\t        \n ;# undent the template

    {*}$cmd -runtime-command {$myparser}
    #{*}$cmd -self-command    {$self}
    #{*}$cmd -proc-command    method
    {*}$cmd -self-command    {}
    {*}$cmd -proc-command    proc
    {*}$cmd -prelude         {upvar 1 myparser myparser}
    {*}$cmd -namespace       {}
    {*}$cmd -main            MAIN
    {*}$cmd -indent          4
    {*}$cmd -template        [string trim \
				  [string map $map {
	## -*- tcl -*-
	##
	## Snit-based Tcl/PARAM implementation of the parsing
	## expression grammar
	##
	##	@name@
	##
	## Generated from file	@file@
	##            for user  @user@
	##
	# # ## ### ##### ######## ############# #####################
	## Requirements

	package require Tcl 8.5
	package require snit
	package require pt::rde ; # Implementation of the PARAM
				  # virtual machine underlying the
				  # Tcl/PARAM code used below.

	# # ## ### ##### ######## ############# #####################
	##

	snit::type ::@@CLASS@@ {
	    # # ## ### ##### ######## #############
	    ## Public API

	    constructor {} {
		# Create the runtime supporting the parsing process.
		set myparser [pt::rde ${selfns}::ENGINE]
		return
	    }

	    method parse {channel} {
		$myparser reset $channel
		MAIN ; # Entrypoint for the generated code.
		return [$myparser complete]
	    }

	    method parset {text} {
		$myparser reset
		$myparser data $text
		MAIN ; # Entrypoint for the generated code.
		return [$myparser complete]
	    }

	    # # ## ### ###### ######## #############
	    ## Configuration

	    pragma -hastypeinfo    0
	    pragma -hastypemethods 0
	    pragma -hasinfo        0
	    pragma -simpledispatch 1

	    # # ## ### ###### ######## #############
	    ## Data structures.

	    variable myparser {} ; # Our instantiation of the PARAM.

	    # # ## ### ###### ######## #############
	    ## BEGIN of GENERATED CODE. DO NOT EDIT.

@code@
	    ## END of GENERATED CODE. DO NOT EDIT.
	    # # ## ### ###### ######## #############
	}

	# # ## ### ##### ######## ############# #####################
	## Ready

	package provide @@PKG@@ @@VERSION@@
	return
    }]]

    return
}

# # ## ### ##### ######## #############

namespace eval ::pt::tclparam::configuration::snit {}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::tclparam::configuration::snit 1.0.2
return
