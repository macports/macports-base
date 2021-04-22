# -*- tcl -*-
# ### ### ### ######### ######### #########
## Terminal packages - ANSI - Control operations
## (Unix specific implementation).

## This was originally taken from page 11820 (Pure Tcl Console Editor)
## of the Tcler's Wiki, however page 14693 (Reading a single character
## ...) is the same in a more self-contained manner.

# ### ### ### ######### ######### #########
## Requirements

namespace eval ::term::ansi::ctrl::unix {}

# ### ### ### ######### ######### #########
## Make command easily available

proc ::term::ansi::ctrl::unix::import {{ns ctrl} args} {
    if {![llength $args]} {set args *}
    set args ::term::ansi::ctrl::unix::[join $args " ::term::ansi::ctrl::unix::"]
    uplevel 1 [list namespace eval ${ns} [linsert $args 0 namespace import]]
    return
}

# ### ### ### ######### ######### #########
## API

# We use the <@stdin because stty works out what terminal to work with
# using standard input on some platforms. On others it prefers
# /dev/tty instead, but putting in the redirection makes the code more
# portable

proc ::term::ansi::ctrl::unix::raw {} {
    variable stty
    exec $stty raw -echo <@stdin
    return
}

proc ::term::ansi::ctrl::unix::cooked {} {
    variable stty
    exec $stty -raw echo <@stdin
    return
}

proc ::term::ansi::ctrl::unix::columns {} {
    variable tput
    return [exec $tput cols <@stdin]
}

proc ::term::ansi::ctrl::unix::rows {} {
    variable tput
    return [exec $tput lines <@stdin]
}

# ### ### ### ######### ######### #########
## Package setup

proc ::term::ansi::ctrl::unix::INIT {} {
    variable tput [auto_execok tput]
    variable stty [auto_execok stty]

    if {($stty eq "/usr/ucb/stty") &&
	($::tcl_platform(os) eq "SunOS")} {
	set stty /usr/bin/stty
    }

    if {($tput eq "") || ($stty eq "")} {
	return -code error \
		"The external requirements for the \
		use of this package (tput, stty in \
		\$PATH) are not met."
    }
    return
}

namespace eval ::term::ansi::ctrl::unix {
    variable tput {}
    variable stty {}

    namespace export columns rows raw cooked
}

::term::ansi::ctrl::unix::INIT

# ### ### ### ######### ######### #########
## Ready

package provide term::ansi::ctrl::unix 0.1.1

##
# ### ### ### ######### ######### #########
