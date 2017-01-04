#
# tcllib.tcl --
#
# Various command dealing with tlib package libraries.
#------------------------------------------------------------------------------
# Copyright 1992-1999 Karl Lehenbauer and Mark Diekhans.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted, provided
# that the above copyright notice appear in all copies.  Karl Lehenbauer and
# Mark Diekhans make no representations about the suitability of this
# software for any purpose.  It is provided "as is" without express or
# implied warranty.
#------------------------------------------------------------------------------
# Copyright (c) 1991-1994 The Regents of the University of California.
# All rights reserved.
#
# Permission is hereby granted, without written agreement and without
# license or royalty fees, to use, copy, modify, and distribute this
# software and its documentation for any purpose, provided that the
# above copyright notice and the following two paragraphs appear in
# all copies of this software.
#
# IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
# OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
# CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
# ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
# PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
#------------------------------------------------------------------------------
# $Id: tcllib.tcl,v 1.1 2001/10/24 23:31:48 hobbs Exp $
#------------------------------------------------------------------------------
#

#@package: TclX-libraries searchpath auto_load_file

#------------------------------------------------------------------------------
# searchpath:
# Search a path list for a file. (catch is for bad ~user)
#
proc searchpath {pathlist file} {
    foreach dir $pathlist {
        if {$dir == ""} {set dir .}
        if {[catch {file exists $dir/$file} result] == 0 && $result}  {
            return $dir/$file
        }
    }
    return {}
}

#------------------------------------------------------------------------------
# auto_load_file:
# Search auto_path for a file and source it.
#
proc auto_load_file {name} {
    global auto_path errorCode
    if {[string first / $name] >= 0} {
        return  [uplevel 1 source $name]
    }
    set where [searchpath $auto_path $name]
    if [lempty $where] {
        error "couldn't find $name in any directory in auto_path"
    }
    uplevel 1 source $where
}

#@package: TclX-lib-list auto_packages auto_commands

#------------------------------------------------------------------------------
# auto_packages:
# List all of the loadable packages.  If -files is specified, the file paths
# of the packages is also returned.

proc auto_packages {{option {}}} {
    global auto_pkg_index

    auto_load  ;# Make sure all indexes are loaded.
    if ![info exists auto_pkg_index] {
        return {}
    }
    
    set packList [array names auto_pkg_index] 
    if [lempty $option] {
        return $packList
    }

    if {$option != "-files"} {
        error "Unknow option \"$option\", expected \"-files\""
    }
    set locList {}
    foreach pack $packList {
        lappend locList [list $pack [lindex $auto_pkg_index($pack) 0]]
    }
    return $locList
}

#------------------------------------------------------------------------------
# auto_commands:
# List all of the loadable commands.  If -loaders is specified, the commands
# that will be involked to load the commands is also returned.

proc auto_commands {{option {}}} {
    global auto_index

    auto_load  ;# Make sure all indexes are loaded.
    if ![info exists auto_index] {
        return {}
    }
    
    set cmdList [array names auto_index] 
    if [lempty $option] {
        return $cmdList
    }

    if {$option != "-loaders"} {
        error "Unknow option \"$option\", expected \"-loaders\""
    }
    set loadList {}
    foreach cmd $cmdList {
        lappend loadList [list $cmd $auto_index($cmd)]
    }
    return $loadList
}



