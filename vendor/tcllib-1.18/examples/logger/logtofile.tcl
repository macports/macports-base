#!/usr/bin/env tclsh
#
# Logging to a simple file
#
# This creates the file mylog.log and adds a single line.
#
# (c) 2005 Michael Schlenker <mic42@users.sourceforge.net>
#
# $Id: logtofile.tcl,v 1.2 2005/09/28 03:46:37 andreas_kupries Exp $
#
#

 package require logger

# Define a simple custom logproc
 proc log_to_file {lvl txt} {
   set logfile "mylog.log"
   set msg "\[[clock format [clock seconds]]\] $txt"
   set f [open $logfile {WRONLY CREAT APPEND}] ;# instead of "a"
   fconfigure $f -encoding utf-8
   puts $f $msg
   close $f
 }

# Initialize the logger
 set log [logger::init global]

# Install the logproc for all levels 
 foreach lvl [logger::levels] {
   interp alias {} log_to_file_$lvl {} log_to_file $lvl
   ${log}::logproc $lvl log_to_file_$lvl
 }

# Send a simple message to the logfile
 ${log}::info "Logging to a file"