# -*- tcl -*-
# Copyright (c) 2009-2014 Andreas Kupries <andreas_kupries@sourceforge.net>
# Copyright (c) 2016 Stefan Sobernig <stefan.sobernig@wu.ac.at>

# Canned configuration for the converter to Tcl/PARAM representation,
# causing generation of a proper NX class.

# The requirements of the embedded template are not our requirements.
# @mdgen NODEP: nx
# @mdgen NODEP: pt::rde::nx

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5              ; # Required runtime.

# # ## ### ##### ######## ############# #####################
##

namespace eval ::pt::tclparam::configuration::nx {
    namespace export   def
    namespace ensemble create
}

# # ## ### ##### ######## #############
## Public API

# Check that the proposed serialization of an abstract syntax tree is
# indeed such.

proc ::pt::tclparam::configuration::nx::def {class pkg version cmd} {

    lappend map @@PKG@@     $pkg
    lappend map @@VERSION@@ $version
    lappend map @@CLASS@@   $class
    lappend map \n\t        \n ;# undent the template

    {*}$cmd -runtime-command :
    {*}$cmd -self-command    :
    {*}$cmd -proc-command    :method
    {*}$cmd -prelude         {}
    {*}$cmd -namespace       {}
    {*}$cmd -main            MAIN
    {*}$cmd -indent          4
    {*}$cmd -template        [string trim \
				  [string map $map {
	## -*- tcl -*-
	##
	## NX-based Tcl/PARAM implementation of the parsing
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
	package require nx
	package require pt::rde::nx ; # NX-based implementation of the
				      # PARAM virtual machine
				      # underlying the Tcl/PARAM code
				      # used below.

	# # ## ### ##### ######## ############# #####################
	##

	nx::Class create @@CLASS@@ -superclasses pt::rde::nx {
	    # # ## ### ##### ######## #############
	    ## Public API
	    
	    :public method parse {channel} {
		:reset $channel
		:MAIN ; # Entrypoint for the generated code.
		return [:complete]
	    }

	    :public method parset {text} {
		:reset {}
		:data $text
		:MAIN ; # Entrypoint for the generated code.
		return [:complete]
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

namespace eval ::pt::tclparam::configuration::nx {}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::tclparam::configuration::nx 1.0.1
return
