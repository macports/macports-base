#
# checkup.tcl -- 
#
# Program to try to detect various serious problems during the build.  These
# are problems that are known and can be confusing to the user, so we check
# during the compile phase.
#
# Problems checked for:
#   o Detects broken glob and readdir command.  This is a common problem
#     encountered when building Tcl & TclX on Solaris systems.  If you compile
#     with /usr/ucb/cc you get readdir entries that don't match the include
#     file.  This program *MUST* be run in the src directory where TclX was
#     built.
#   o Checks for modern functionality that is missing from the version of
#     Unix we are compiled on.  Hopefully this will alert people to improper
#     configuration.
#------------------------------------------------------------------------------
# Copyright 1995-1999 Karl Lehenbauer and Mark Diekhans.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted, provided
# that the above copyright notice appear in all copies.  Karl Lehenbauer and
# Mark Diekhans make no representations about the suitability of this
# software for any purpose.  It is provided "as is" without express or
# implied warranty.
#------------------------------------------------------------------------------
# $Id: checkup.tcl,v 8.3 1999/03/31 06:37:59 markd Exp $
#------------------------------------------------------------------------------
#


#
# Report file that was not found and exit.
#
proc ReportError {chkfile cmd} {
    puts stderr "*************************************************************"
    puts stderr "Unable to find $chkfile in the output of the TclX command"
    puts stderr "'$cmd' when run in the src directory.  This indicates"
    puts stderr "that $cmd is broken.  If your are running Solaris this"
    puts stderr "can be caused by compiling Tcl or TclX with the /usr/ucb/cc"
    puts stderr "compiler.  If this is the case, move /usr/ucb to the end"
    puts stderr "of your path or see the INSTALL documentation for information"
    puts stderr "on specifying a different C compiler.  Do a 'make clean',"
    puts stderr "'configure' and 'make' for both Tcl and TclX."
    puts stderr "Good luck."
    puts stderr "*************************************************************"
    exit 1
}

#
# Check for files that can not be found.
#  o dirlist - Contents of either the glob or the readdir command on the src
#    directory.
#  o cmd - The command that was used.
#
proc CheckDirList {dirlist cmd} {
    foreach chkfile {Makefile tclxConfig.sh tcl} {
        if {[lsearch $dirlist $chkfile] < 0} {
            ReportError $chkfile $cmd
        }
    }
}

CheckDirList [glob *] glob
CheckDirList [readdir .] readdir

#
# Print a message about missing functionality.  If its the first time, print
# a header.
#
proc MissingMsg {msg} {
    # Not done yet.
}


