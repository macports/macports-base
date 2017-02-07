#
# bldmanhelp.tcl --
#
#  Build help files from the manual pages.  This uses a table of manual
# pages, sections. Brief entries are extracted from the name line.
# This is not installed as part of Extended Tcl, its just used during the
# build phase.
#
# This program is very specific to extracting manual files from John
# Ousterhout's Tcl and Tk man pages.  Its not general.
#
# The command line is:
#
#   bldmanhelp docdir maninfo helpdir
#
# Where:
#    o docdir is the directory containing the manual pages.
#    o maninfo is the path to a file that when sources returns a list of
#      entries describing manual pages to convert.  Each entry is a list
#      of manual file and the path of the help file to generate.
#    o helpdir is the directory to create the help files in.
#    o brief is the brief file to create.
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
# $Id: bldmanhelp.tcl,v 8.5 2002/11/12 21:35:31 karll Exp $
#------------------------------------------------------------------------------
#

package require Tclx

#
# pull in buildhelp procs
#
source $env(TCLX_LIBRARY)/buildhelp.tcl

#
# Flag indicating if errors occured.
#
set gotErrors 0

#-----------------------------------------------------------------------------
# Process the name section.  This is used to generate a @brief: entry.
# It returns the line that was read.

proc ProcessNameSection {manFH outFH} {
    set line [gets $manFH]
    case [lindex $line 0] {
        {.HS .BS .BE .VS .VE} {
            set line [gets $manFH]
        }
    }
    set brief [string trim [crange $line [string first - $line]+1 end]]
    puts $outFH "'\\\"@brief: $brief"
    return $line
}

#-----------------------------------------------------------------------------
# Copy the named manual page source to the target, recursively including
# .so files.  Remove macros usages that don't work good in a help file.

proc CopyManPage {manPage outFH} {
    global skipSection

    set stat [catch {
        open $manPage
    } fh]
    if {$stat != 0} {
        global gotErrors
        set gotErrors 1
        puts stderr "can't open \"$manPage\" $fh"
        return
    }
    while {[gets $fh line] >= 0} {
        switch -glob -- $line {
            .so* {
                CopyManPage [lindex $line 1] $outFH
            }
            .SH* {
                puts $outFH $line
                if {[lindex $line 1] == "NAME"} {
                    set line [ProcessNameSection $fh $outFH]
                    puts $outFH $line
                }
            }
            .HS* - .BS* - .BE* - .VS* - .VE* - .TH* {
            }
            default {
                if !$skipSection {
                    puts $outFH $line
                }
            }
        }
    }
    close $fh
}

#-----------------------------------------------------------------------------
# Process a manual file and copy it to the temporary file.  Assumes current
# dir is the directory containing the manual files.

proc ProcessManFile {ent tmpFH} {
    global skipSection
    set skipSection 0
    puts $tmpFH "'\\\"@help: [lindex $ent 1]"
    CopyManPage [lindex $ent 0] $tmpFH
    puts $tmpFH "'\\\"@endhelp"
}

#-----------------------------------------------------------------------------
# Procedure to create a temporary file containing the file constructed
# for input to buildhelp.
#

proc GenInputFile {docDir manInfoTbl tmpFile} {

   set tmpFH [open $tmpFile w]
   set cwd [pwd]
   cd $docDir

   foreach ent $manInfoTbl {
       puts stdout "    preprocessing $ent"
       ProcessManFile $ent $tmpFH
   }
   cd $cwd
   close $tmpFH
}

#-----------------------------------------------------------------------------
# Main program for building help from manual files.  Constructs tmp input
# file for the buildhelp command.

if {[llength $argv] != 4} {
    puts stderr "wrong # args: bldmanhelp docdir maninfo helpdir brief"
    exit 1
}

set tmpFile "bldmanhelp.tmp"

set docDir [lindex $argv 0]
set manInfoTbl [source [lindex $argv 1]]
set helpDir [lindex $argv 2]
set brief [lindex $argv 3]

puts stdout "Begin preprocessing UCB manual files"
GenInputFile $docDir $manInfoTbl $tmpFile

buildhelp $helpDir $brief [list $tmpFile]

file delete -force $tmpFile

if $gotErrors {
    puts stderr "Errors occured processing manual files"
    exit 1
}
exit 0


