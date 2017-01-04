# -*- tcl -*-
# ### ### ### ######### ######### #########
## Terminal packages - ANSI - Attribute codes

# ### ### ### ######### ######### #########
## Requirements

package require  term::ansi::code ; # Constants

namespace eval ::term::ansi::code::attr {}

# ### ### ### ######### ######### #########
## API. Symbolic names.

proc ::term::ansi::code::attr::names {} {
    variable attr
    return  $attr
}

proc ::term::ansi::code::attr::import {{ns attr} args} {
    if {![llength $args]} {set args *}
    set args ::term::ansi::code::attr::[join $args " ::term::ansi::code::attr::"]
    uplevel 1 [list namespace eval ${ns} [linsert $args 0 namespace import]]
    return
}

# ### ### ### ######### ######### #########
## Internal - Setup

proc ::term::ansi::code::attr::DEF {name value} {
    variable  attr
    const            $name $value
    lappend   attr   $name
    namespace export $name
    return
}

proc ::term::ansi::code::attr::INIT {} {
    # ### ### ### ######### ######### #########
    ##

    # Colors. Foreground <=> Text
    DEF	fgblack   30	; # Black  
    DEF	fgred     31	; # Red    
    DEF	fggreen   32	; # Green  
    DEF	fgyellow  33	; # Yellow 
    DEF	fgblue    34	; # Blue   
    DEF	fgmagenta 35	; # Magenta
    DEF	fgcyan    36	; # Cyan   
    DEF	fgwhite   37	; # White  
    DEF	fgdefault 39    ; # Default (Black)

    # Colors. Background.
    DEF	bgblack   40	; # Black  
    DEF	bgred     41	; # Red    
    DEF	bggreen   42	; # Green  
    DEF	bgyellow  43	; # Yellow 
    DEF	bgblue    44	; # Blue   
    DEF	bgmagenta 45	; # Magenta
    DEF	bgcyan    46	; # Cyan   
    DEF	bgwhite   47	; # White  
    DEF	bgdefault 49    ; # Default (Transparent)

    # Non-color attributes. Activation.
    DEF	bold      1	; # Bold  
    DEF	dim       2	; # Dim
    DEF	italic    3     ; # Italics      
    DEF	underline 4	; # Underscore   
    DEF	blink     5	; # Blink
    DEF	revers    7	; # Reverse      
    DEF	hidden    8	; # Hidden
    DEF	strike    9     ; # StrikeThrough

    # Non-color attributes. Deactivation.
    DEF	nobold      22	; # Bold  
    DEF	nodim       __	; # Dim
    DEF	noitalic    23  ; # Italics      
    DEF	nounderline 24	; # Underscore   
    DEF	noblink     25	; # Blink
    DEF	norevers    27	; # Reverse      
    DEF	nohidden    28	; # Hidden
    DEF	nostrike    29  ; # StrikeThrough

    # Remainder
    DEF	reset       0   ; # Reset

    ##
    # ### ### ### ######### ######### #########
    return
}

# ### ### ### ######### ######### #########
## Data structures.

namespace eval ::term::ansi::code::attr {
    namespace import ::term::ansi::code::const
    variable attr {}
}

::term::ansi::code::attr::INIT

# ### ### ### ######### ######### #########
## Ready

package provide term::ansi::code::attr 0.1

##
# ### ### ### ######### ######### #########
