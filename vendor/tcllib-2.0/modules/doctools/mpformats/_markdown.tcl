# -*- tcl -*-
##
# Support for markdown, overrides parts of coore text.
#
# Copyright (c) 2019 Andreas Kupries <andreas_kupries@sourceforge.net>
# Freely redistributable.
##
# # ## ### ##### ########

# # ## ### ##### ########
## `markdown` formatting

proc SectTitle {lb title} {
    upvar 1 $lb lines
    lappend lines "[Hash] $title"
    return
}

proc SubsectTitle {lb title} {
    upvar 1 $lb lines
    lappend lines "[Hash][Hash] $title"
    return
}

proc Sub3Title {lb title} {
    upvar 1 $lb lines
    lappend lines "[Hash][Hash][Hash] $title"
    return
}

proc Sub4Title {lb title} {
    upvar 1 $lb lines
    lappend lines "[Hash][Hash][Hash][Hash] $title"
    return
}

proc _Strong {text} { return [Undr][Undr]${text}[Undr][Undr] }
proc _Em     {text} { return [Star]${text}[Star] }

##
# # ## ### ##### ########
##

set __comments 0

proc MDCInit {} { global __comments ; set __comments 0 }

proc MDComment {text} {
    global __comments
    Text "\n[OBrk]//[format %09d [incr __comments]][CBrk]: [Hash] [OPar]$text[CPar]"
}

proc MDCDone {} {
    TextTrimLeadingSpace
    CloseParagraph [Verbatim]
}

##
# # ## ### ##### ########
##

proc MakeLink {l t} { ALink $t $l } ;# - xref - todo: consolidate

proc ALink {dst label} { return "[OBrk]$label[CBrk][OPar]$dst[CPar]" }

proc SetAnchor {text {name {}}} {
    if {$name == {}} { set name [Anchor $text] }
    return "<a name='$name'></a>$text"
}

proc Anchor {text} {
    global kwid
    if {[info exists kwid($text)]} {
	return "$kwid($text)"
    }
    return [A $text]
}

proc A {text} {
    set anchor [regsub -all {[^a-zA-Z0-9]} [string tolower $text] {_}]
    set anchor [regsub -all {__+} $anchor [Undr]]
    return $anchor
}

# Generate special code sequences for markdown command characters.  At
# the end of the render the command sequences are converted to regular
# final form whereas all unprotected special characters are quoted.

proc Back {} { return "\1\\" }
proc Tick {} { return "\1`" }
proc Star {} { return "\1*" }
proc Undr {} { return "\1_" }
proc Hash {} { return "\1#" }
proc Plus {} { return "\1+" }
proc Dash {} { return "\1-" }
proc Dot  {} { return "\1." }
proc Bang {} { return "\1!" }
proc OBra {} { return "\1\{" }
proc CBra {} { return "\1\}" }
proc OBrk {} { return "\1\[" }
proc CBrk {} { return "\1\]" }
proc OPar {} { return "\1(" }
proc CPar {} { return "\1)" }
proc VBar {} { return "\1|" }

proc LB  {} { return "\1\n" }
proc LB. {} { return "\1" }

proc c_copyrightsymbol {} {return "&copy;"}

# Modified bulleting

DIB [list [Dash] [Star] [Plus]]
DEB [list "1[Dot]" "1[CPar]"]

proc Unmark {x} {
    lappend map "\1\n" "  \n"
    # Marked special characters are commands. Convert into regular
    # form. Unmarked special characters need quoting.
    lappend map \1\\ \\
    lappend map \1`  `
    lappend map \1*  *
    lappend map \1_  _
    lappend map \1#  "#"
    lappend map \1+  +
    lappend map \1-  -
    lappend map \1.  .
    lappend map \1!  !
    lappend map \1\{ \{
    lappend map \1\} \}
    lappend map \1\[ \[
    lappend map \1\] \]
    lappend map \1(  (
    lappend map \1)  )
    lappend map \1|  |

    lappend map \\ \\\\
    lappend map `  \\`
    lappend map *  \\*
    lappend map _  \\_
    lappend map "#" "\\#"
    lappend map +  \\+
    lappend map -  \\-
    lappend map .  \\.
    lappend map !  \\!
    lappend map \{ \\\{
    lappend map \} \\\}
    lappend map \[ \\\[
    lappend map \] \\\]
    lappend map (  \\(
    lappend map )  \\)
    lappend map | "&#124;"

    #puts_stderr ZZZ(($x))
    set x [string map $map $x]

    #puts_stderr ZZZ<<$x>>
    set x
}

# Invert handling of special characters for text specified by the
# user, i.e. engine parameters of some kind.
#
# Quoted special characters are unquoted, and unquoted special
# characters get marked/protected.

proc Mark {x} {
    # Dequote non-special specials.
    lappend map \\\\     \\
    lappend map \\`	 `
    lappend map \\*	 *
    lappend map \\_	 _
    lappend map "\\#"	 "#"
    lappend map \\+	 +
    lappend map \\-	 -
    lappend map \\.	 .
    lappend map \\!	 !
    lappend map \\\{	 \{
    lappend map \\\}	 \}
    lappend map \\\[	 \[
    lappend map \\\]	 \]
    lappend map \\(	 (
    lappend map \\)	 )
    lappend map "&#124;" |

    # Protect special specials
    lappend map \\  \1\\
    lappend map `   \1`
    lappend map *   \1*
    lappend map _   \1_
    lappend map "#" \1#
    lappend map +   \1+
    lappend map -   \1-
    lappend map .   \1.
    lappend map !   \1!
    lappend map \{  \1\{
    lappend map \}  \1\}
    lappend map \[  \1\[
    lappend map \]  \1\]
    lappend map (   \1(
    lappend map )   \1)
    lappend map |   \1|

    #puts_stderr ZZZ(($x))
    set x [string map $map $x]

    #puts_stderr ZZZ<<$x>>
    set x
}

rename PostProcess PostProcessT
proc PostProcess {text} { Unmark [PostProcessT $text] }

##
# # ## ### ##### ########
return
