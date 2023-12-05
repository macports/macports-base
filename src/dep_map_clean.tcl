#!/usr/bin/env tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# $Id$

# Removes any duplicate entries from the MacPorts registry's dependency map.
# Takes one argument, which should be TCL_PACKAGE_DIR.

source [file join [lindex $argv 0] macports1.0 macports_fastload.tcl]
package require macports 1.0
package require registry 1.0

mportinit

registry::open_dep_map
registry::clean_dep_map
registry::write_dep_map

exit 0
