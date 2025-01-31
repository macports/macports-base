# -*- tcl -*-
#
# Copyright (c) 2019 Andreas Kupries <andreas_kupries@sourceforge.net>
# Freely redistributable.
#
# _text_margin.tcl -- Margin control

global lmarginIncrement ; set lmarginIncrement 4
global rmarginThreshold ; set rmarginThreshold 20

proc LMI {} { global lmarginIncrement ; return $lmarginIncrement }
proc RMT {} { global rmarginThreshold ; return $rmarginThreshold }

proc RMargin {indent} {
    set rmt [RMT]
    set rmargin [expr {80 - $indent}]
    if {$rmargin < $rmt} { set rmargin $rmt }
    return $rmargin
}

return
