# -*- tcl -*-
#
# Copyright (c) 2019 Andreas Kupries <andreas_kupries@sourceforge.net>
# Freely redistributable.
#
# _text_state.tcl -- State variables and accessors

# # ## ### ##### ########
# State: Flag to suppress of plain text in some places.

global __off

# # ## ### ##### ########
# API

proc Off   {} { global __off ; set __off 1 ; return}
proc On    {} { global __off ; set __off 0 ; TextClear ; return}
proc IsOff {} { global __off ; return $__off }

# Debugging ...
#proc Off   {}        {puts_stderr OFF ; global __off ; set __off 1 ; return}
#proc On    {}        {puts_stderr ON_ ; global __off ; set __off 0 ; TextClear ; return}
