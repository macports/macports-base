# -*- tcl -*-
# Implementation of 'help'.

# Available variables
# * argv  - Cmdline arguments

if {[llength $argv] > 2} {
    puts stderr "Usage: $argv0 help ?topic?"
    exit 1
}

package require sak::help

if {[llength $argv] == 1} {
    # Argument is a topic.
    # Locate text for the topic.

    sak::help::print [sak::help::on [lindex $argv 0]]
    return
}

sak::help::print [sak::help::alltopics]

##
# ###
