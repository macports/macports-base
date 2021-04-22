# -*- tcl -*-
#
# Copyright (c) 2019 Andreas Kupries <andreas_kupries@sourceforge.net>
# Freely redistributable.
#
# _text_cstack.tcl -- Stack of contexts and accessors

global contexts ; set contexts {}

################################################################
# Management of the stack

proc ContextReset {} { global contexts ; set contexts {} ; return }

proc ContextPush {} {
    global  contexts
    lappend contexts [set id [CAttrCurrent]]

    #puts_stderr "Push:[llength $contexts]>> [CAttrName $id]"
    return
}

proc ContextPop {} {
    global contexts
    set id       [lindex $contexts end]
    set contexts [lrange $contexts 0 end-1]

    #puts_stderr "<<Pop:[llength $contexts]  [CAttrName $id]"
    ContextSet   $id
    return
}
