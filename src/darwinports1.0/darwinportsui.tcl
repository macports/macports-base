# darwinportsui.tcl
#
# Copyright (c) 2002 Apple Computer, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
package provide darwinportsui 1.0 

# System options array.  Options we pay attention to are:
# system_options(ports_debug) - If set, output debugging messages.
# system_options(ports_verbose) - If set, output info messages (ui_info)
# system_options(ports_quiet) - If set, don't output "standard messages"
# system_options(_ui_is_enabled) - If not set, go into "batch mode"
global system_options

# Accessor functions for system options
proc ports_debug {val} {
    global system_options

    set system_options(ports_debug) $val
}

proc ports_verbose {val} {
    global system_options

    set system_options(ports_verbose) $val
}

proc ports_quiet {val} {
    global system_options

    set system_options(ports_quiet) $val
}

proc isset {val} {
    global system_options
    if {[info exists system_options($val)]} {
	if {$system_options($val) == "yes"} {
	    return 1
	}
    }
    return 0
}

# do whatever interesting things need to be done to initialize the UI
# environment.  Always called by convention though it does nothing
# much in the "minimal UI" implementation (though it should always
# make sure to enable the ui at the very minimum.
proc ui_init {} {
    ui_enable
}

# Enable the UI.  This is merely a convenient hook to be able to turn
# the UI entirely on or entirely off, for ports that are being built
# in "batch mode".
proc ui_enable {} {
    global system_options
    set system_options(_ui_is_enabled) yes
}

# Disable the UI.  All routines essentially go quiet and return default
# values.
proc ui_disable {} {
    global system_options
    set system_options(_ui_is_enabled) no
}

# Returns 1 if the UI is enabled or 0 if not.
proc ui_enabled {} {
    global system_options
    return [isset _ui_is_enabled]
}

# Output string "str" on whatever the "output device" is, depending on
# the UI model in use.  If you don't want newlines to be output, you
# must pass "-nonewline" as the second argument.

proc ui_puts {str {nonl ""}} {
    if ![ui_enabled] return

    if {$nonl == "-nonewline"} {
	puts -nonewline stdout "$str"
	flush stdout
    } else {
	puts "$str"
    }
}

# Output debugging messages if the ports_debug variable is set.
proc ui_debug {str} {
    global system_options

    if [isset ports_debug] {
	puts stderr "DEBUG: $str"
    }
}

# Output message if ports_verbose is set.
proc ui_info {str {nonl ""}} {
    global system_options

    if [isset ports_verbose] {
	ui_puts "$str" $nonl
    }
}

# Output message unless ports_quiet is set.
proc ui_msg {str {nonl ""}} {
    global system_options

    if ![isset ports_quiet] {
	ui_puts "$str" $nonl
    }
}

# Output message unconditionally as an error message.
proc ui_error {str} {
    ui_puts "Error: $str"
}

# Get a line of input from the user and store in str, returning the
# number of bytes input.
proc ui_gets {str} {
    if ![ui_enabled] {
	set str ""
	return 0
    }
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
	ui_puts $promptstr -nonewline
	if {[ui_gets mystr] == 0} {
	    if {[string length $defvalue] > 0} {
		set mystr $defvalue
	    } else {
		if {![ui_enabled]} {return 0}
		continue
	    }
	}
	if {[string compare -nocase -length 1 $mystr y] == 0} {
	    set rval 1
	    set satisfaction yes
	} elseif {[string compare -nocase -length 1 $mystr n] == 0} {
	    set rval 0
	    set satisfaction yes
	} elseif {![ui_enabled]} {
	    return 0
	}
    }
    return $rval
}

# Put up a simple confirmation dialog, requesting nothing more than
# the user's acknowledgement of the prompt string passed in
# "promptstr".  There is no return value.
proc ui_confirm {promptstr} {
    ui_puts "$promptstr" -nonewline
    ui_gets garbagestr
}

# Display the contents of a file, ideally in a manner which allows the
# user to scroll through and read it comfortably (e.g. a license
# text).  For the "simple UI" version of this, we simply punt this to
# less(1) since rewriting a complete pager for the simple case would
# be a waste of time.  It's expected in a more complex UI case, a
# scrolling display widget of some type will be used.
proc ui_display {filename} {
    if {![ui_enabled]} {return}

    if [file exists $filename] {
	system "/usr/bin/less $filename"
    }
}
