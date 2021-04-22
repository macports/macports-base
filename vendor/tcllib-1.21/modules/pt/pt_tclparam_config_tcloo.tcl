# -*- tcl -*-
# Copyright (c) 2009-2014 Andreas Kupries <andreas_kupries@sourceforge.net>

# Canned configuration for the converter to Tcl/PARAM representation,
# causing generation of a proper TclOO class.

# The requirements of the embedded template are not our requirements.
# @mdgen NODEP: TclOO
# @mdgen NODEP: pt::rde::oo

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5              ; # Required runtime.

# # ## ### ##### ######## ############# #####################
##

namespace eval ::pt::tclparam::configuration::tcloo {
    namespace export   def
    namespace ensemble create
}

# # ## ### ##### ######## #############
## Public API

# Check that the proposed serialization of an abstract syntax tree is
# indeed such.

proc ::pt::tclparam::configuration::tcloo::def {class pkg version cmd} {

    # TODO :: See if we can consolidate the API for converters,
    # TODO :: plugins, export manager, and container in some way.
    # TODO :: Container may make exporter manager available through
    # TODO :: public method.

    lappend map @@PKG@@     $pkg
    lappend map @@VERSION@@ $version
    lappend map @@CLASS@@   $class
    lappend map \n\t        \n ;# undent the template

    {*}$cmd -runtime-command my
    {*}$cmd -self-command    my
    {*}$cmd -proc-command    method
    {*}$cmd -prelude         {}
    {*}$cmd -namespace       {}
    {*}$cmd -main            MAIN
    {*}$cmd -indent          4
    {*}$cmd -template        [string trim \
				  [string map $map {
	## -*- tcl -*-
	##
	## OO-based Tcl/PARAM implementation of the parsing
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
	package require TclOO
	package require pt::rde::oo ; # OO-based implementation of the
				      # PARAM virtual machine
				      # underlying the Tcl/PARAM code
				      # used below.

	# # ## ### ##### ######## ############# #####################
	##

	oo::class create @@CLASS@@ {
	    # # ## ### ##### ######## #############
	    ## Public API

	    superclass pt::rde::oo ; # TODO - Define this class.
	                             # Or can we inherit from a snit
	                             # class too ?

	    method parse {channel} {
		my reset $channel
		my MAIN ; # Entrypoint for the generated code.
		return [my complete]
	    }

	    method parset {text} {
		my reset {}
		my data $text
		my MAIN ; # Entrypoint for the generated code.
		return [my complete]
	    }

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

namespace eval ::pt::tclparam::configuration::tcloo {}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::tclparam::configuration::tcloo 1.0.4
return
