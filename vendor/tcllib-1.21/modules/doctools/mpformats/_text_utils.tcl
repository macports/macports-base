# -*- tcl -*-
#
# Copyright (c) 2019 Andreas Kupries <andreas_kupries@sourceforge.net>
# Freely redistributable.
#
# _text_utils.tcl -- Text formatting utilities

# # ## ### ##### ########
## API

proc Dots {x} { string map {{ } . {	} .} $x }

proc Compose {lb} {
    upvar 1 $lb linebuffer
    return [string trimright [join $linebuffer \n]]
}

proc ReHead {line prefix} {
    set n [string length [DeIce $prefix]]
    incr n -1
    string replace $line 0 $n $prefix
}

proc MaxLen {v s} {
    upvar 1 $v max
    set n [string length $s]
    if {$n <= $max} return
    set max $n
}

proc DeIce {x} { string map [list \1 {}] $x }

proc BlankMargin {} { global lmarginIncrement ; Blank $lmarginIncrement }

proc Repeat  {char n}      { textutil::repeat::strRepeat $char $n }
proc Blank   {n}           { textutil::repeat::blank $n }
proc RepeatM {char text}   { Repeat $char [string length [DeIce $text]] }
proc BlankM  {text}        { Blank        [string length [DeIce $text]] }
proc Undent  {text}        { textutil::adjust::undent $text }
proc Reflow  {text maxlen} { textutil::adjust::adjust $text -length $maxlen }
proc Indent  {text prefix} { textutil::adjust::indent $text $prefix }
proc Indent1 {text p1 p}   { return "${p1}[textutil::adjust::indent $text $p 1]" }
proc InFlow {text maxlen prefix1 prefix} {
    # Reformats the paragraph `text` to keep line length under
    # `maxlen` and then indents the result using `prefix1` and
    # `prefix`.  `prefix1` is applied to the first line, and `prefix`
    # to the remainder. The caller is responsible for ensuring that
    # both prefixes have the same length.
    Indent1 [Reflow $text $maxlen] $prefix1 $prefix
}

proc Provenance {} {
    textutil::string::uncap [c_provenance]
}

# # ## ### ##### ########
# Internals

# # ## ### ##### ########
return
