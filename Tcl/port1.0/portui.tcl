#-*- mode: Fundamental; tab-width: 4; -*-
# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portui 1.0

# do whatever interesting things need to be done to initialize the UI
# environment.  Always called by convention though it does nothing in
# the "minimal UI" implementation.
proc ui_init {} {
}

# Output string "str" on whatever the "output device" is, depending on
# the UI model in use.  If you want newlines to be output, you must
# include them in the string.  No newlines are output by default
# because it would make it hard to use this ui routine for other
# purposes (like doing one-line queries from the user).
proc ui_puts {str} {
    puts -nonewline stdout "$str"
    flush stdout
}

# Get a line of input from the user and store in str, returning the
# number of bytes input.
proc ui_gets {str} {
    upvar $str in_string
    gets stdin in_string
}

# Ask a boolean "yes/no" question of the user, using "promptstr" as
# the prompt.  It should contain a trailing space and/or anything else
# you want to precede the user's input string.  Returns 1 for "yes" or
# 0 for "no".  This implementation also assumes an english yes/no or
# y/n response, but that is not mandated by the spec.  If "defvalue"
# is passed, it will be used as the default value if none is supplied
# by the user.
proc ui_yesno {promptstr {defvalue ""}} {
    set satisfaction no
    while {$satisfaction == "no"} {
	ui_puts $promptstr
	if {[ui_gets mystr] == 0} {
	    if {[string length $defvalue] > 0} {
		set mystr $defvalue
	    } else {
		continue
	    }
	}
	if {[string compare -nocase -length 1 $mystr y] == 0} {
	    set rval 1
	    set satisfaction yes
	} elseif {[string compare -nocase -length 1 $mystr n] == 0} {
	    set rval 0
	    set satisfaction yes
	}
    }
    return $rval
}

# Put up a simple confirmatoin dialog, requesting nothing more than
# the user's acknowledgement of the prompt string passed in
# "promptstr".  There is no return value.
proc ui_confirm {promptstr} {
    ui_puts $promptstr
    ui_gets garbagestr
}

# Display the contents of a file, ideally in a manner which allows the
# user to scroll through and read it comfortably (e.g. a license
# text).  For the "simple UI" version of this, we simply punt this to
# less(1) since rewriting a complete pager for the simple case would
# be a waste of time.  It's expected in a more complex UI case, a
# scrolling display widget of some type will be used.
proc ui_display {filename} {
    if [file exists $filename] {
	system /usr/bin/less $filename
    }
}
