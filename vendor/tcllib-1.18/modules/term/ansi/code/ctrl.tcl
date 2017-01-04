# -*- tcl -*-
# ### ### ### ######### ######### #########
## Terminal packages - ANSI - Control codes

## References
# [0] Google: ansi terminal control
# [1] http://vt100.net/docs/vt100-ug/chapter3.html
# [2] http://www.termsys.demon.co.uk/vtansi.htm
# [3] http://rrbrandt.dyndns.org:60000/docs/tut/redes/ansi.php
# [4] http://www.dee.ufcg.edu.br/~rrbrandt/tools/ansi.html
# [5] http://www.ecma-international.org/publications/standards/Ecma-048.htm

# ### ### ### ######### ######### #########
## Requirements

package require  term::ansi::code
package require  term::ansi::code::attr

namespace eval ::term::ansi::code::ctrl {}

# ### ### ### ######### ######### #########
## API. Symbolic names.

proc ::term::ansi::code::ctrl::names {} {
    variable ctrl
    return  $ctrl
}

proc ::term::ansi::code::ctrl::import {{ns ctrl} args} {
    if {![llength $args]} {set args *}
    set args ::term::ansi::code::ctrl::[join $args " ::term::ansi::code::ctrl::"]
    uplevel 1 [list namespace eval $ns [linsert $args 0 namespace import]]
    return
}

# ### ### ### ######### ######### #########

## TODO = symbolic key codes for skd.

# ### ### ### ######### ######### #########
## Internal - Setup

proc ::term::ansi::code::ctrl::DEF {name esc value} {
    variable  ctrl
    define           $name $esc $value
    lappend   ctrl   $name
    namespace export $name
    return
}

proc ::term::ansi::code::ctrl::DEFC {name arguments script} {
    variable  ctrl
    proc             $name $arguments $script
    lappend   ctrl   $name
    namespace export $name
    return
}

proc ::term::ansi::code::ctrl::INIT {} {
    # ### ### ### ######### ######### #########
    ##

    # Erasing

    DEF	eeol    escb K  ; # Erase (to) End Of Line
    DEF	esol    escb 1K ; # Erase (to) Start Of Line
    DEF	el      escb 2K ; # Erase (current) Line
    DEF	ed      escb J  ; # Erase Down (to bottom)
    DEF	eu      escb 1J ; # Erase Up (to top)
    DEF	es      escb 2J ; # Erase Screen

    # Scrolling

    DEF	sd      esc D    ; # Scroll Down
    DEF	su      esc M    ; # Scroll Up

    # Cursor Handling

    DEF	ch      escb H  ; # Cursor Home
    DEF	sc      escb s  ; # Save Cursor
    DEF	rc      escb u  ; # Restore Cursor (Unsave)
    DEF	sca     esc  7  ; # Save Cursor + Attributes
    DEF	rca     esc  8  ; # Restore Cursor + Attributes

    # Tabbing

    DEF	st      esc  H  ; # Set Tab (@ current position)
    DEF	ct      escb g  ; # Clear Tab (@ current position)
    DEF	cat     escb 3g ; # Clear All Tabs

    # Device Introspection

    DEF	qdc     escb c  ; # Query Device Code
    DEF	qds     escb 5n ; # Query Device Status
    DEF	qcp     escb 6n ; # Query Cursor Position
    DEF	rd      esc  c  ; # Reset Device

    # Linewrap on/off

    DEF	elw     escb 7h ; # Enable Line Wrap
    DEF	dlw     escb 7l ; # Disable Line Wrap

    # Graphics Mode (aka use alternate font on/off)

    DEF eg      esc F   ; # Enter Graphics Mode
    DEF lg      esc G   ; # Exit Graphics Mode

    ##
    # ### ### ### ######### ######### #########

    # ### ### ### ######### ######### #########
    ## Complex, parameterized codes

    # Select Character Set
    # Choose which char set is used for default and
    # alternate font. This does not change whether
    # default or alternate font are used

    DEFC scs0 {tag} {esc  ($tag}  ; # Set default character set
    DEFC scs1 {tag} {esc  )$tag}  ; # Set alternate character set

    # tags in A : United Kingdom Set
    #         B : ASCII Set
    #         0 : Special Graphics
    #         1 : Alternate Character ROM Standard Character Set
    #         2 : Alternate Character ROM Special Graphics

    # Set Display Attributes

    DEFC sda {args} {escb [join $args \;]m}

    # Force Cursor Position (aka Go To)

    DEFC fcp {r c}  {escb ${r}\;${c}f}

    # Cursor Up, Down, Forward, Backward

    DEFC cu {{n 1}} {escb [expr {$n == 1 ? "A" : "${n}A"}]}
    DEFC cd {{n 1}} {escb [expr {$n == 1 ? "B" : "${n}B"}]}
    DEFC cf {{n 1}} {escb [expr {$n == 1 ? "C" : "${n}C"}]}
    DEFC cb {{n 1}} {escb [expr {$n == 1 ? "D" : "${n}D"}]}

    # Scroll Screen (entire display, or between rows start end, inclusive).

    DEFC ss {args} {
	if {[llength $args] == 0} {return [escb r]}
	if {[llength $args] == 2} {foreach {s e} $args break ; return [escb ${s};${e}r]}
	return -code error "wrong\#args"
    }

    # Set Key Definition

    DEFC skd {code str} {escb $code\;\"$str\"p}

    # Terminal title

    DEFC title {str} {esc \]0\;$str\007}

    # Switch to and from character/box graphics.

    DEFC gron  {} {return \016}
    DEFC groff {} {return \017}

    # Character graphics, box symbols
    # - 4 corners, 4 t-junctions,
    #   one 4-way junction, 2 lines

    DEFC tlc   {} {return [gron]l[groff]} ; # Top    Left  Corner
    DEFC trc   {} {return [gron]k[groff]} ; # Top    Right Corner
    DEFC brc   {} {return [gron]j[groff]} ; # Bottom Right Corner
    DEFC blc   {} {return [gron]m[groff]} ; # Bottom Left  Corner

    DEFC ltj   {} {return [gron]t[groff]} ; # Left   T Junction
    DEFC ttj   {} {return [gron]w[groff]} ; # Top    T Junction
    DEFC rtj   {} {return [gron]u[groff]} ; # Right  T Junction
    DEFC btj   {} {return [gron]v[groff]} ; # Bottom T Junction

    DEFC fwj   {} {return [gron]n[groff]} ; # Four-Way Junction

    DEFC hl    {} {return [gron]q[groff]} ; # Horizontal Line
    DEFC vl    {} {return [gron]x[groff]} ; # Vertical   Line

    # Optimize character graphics. The generator commands above create
    # way to many superfluous commands shifting into and out of the
    # graphics mode. The command below removes all shifts which are
    # not needed. To this end it also knows which characters will look
    # the same in both modes, to handle strings created outside this
    # package.

    DEFC groptim {string} {
	variable grforw
	variable grback
	while {![string equal $string [set new [string map \
		[list \017\016 {} \016\017 {}] [string map \
		$grback [string map \
		$grforw $string]]]]]} {
	    set string $new
	}
	return $string
    }

    ##
    # ### ### ### ######### ######### #########

    # ### ### ### ######### ######### #########
    ## Higher level operations

    # Clear screen <=> CursorHome + EraseDown
    # Init (Fonts): Default ASCII, Alternate Graphics
    # Show a block of text at a specific location.

    DEFC clear {} {return [ch][ed]}
    DEFC init  {} {return [scs0 B][scs1 0]}

    DEFC showat {r c text} {
	if {![string length $text]} {return {}}
	return [fcp $r $c][sca][join \
		[split $text \n] \
		[rca][cd][sca]][rca][cd]
    }

    ##
    # ### ### ### ######### ######### #########

    # ### ### ### ######### ######### #########
    ## Attribute control (single attributes)

    foreach a [::term::ansi::code::attr::names] {
	DEF sda_$a escb [::term::ansi::code::attr::$a]m
    }

    ##
    # ### ### ### ######### ######### #########
    return
}

# ### ### ### ######### ######### #########
## Data structures.

namespace eval ::term::ansi::code::ctrl {
    namespace import ::term::ansi::code::define
    namespace import ::term::ansi::code::esc
    namespace import ::term::ansi::code::escb

    variable grforw
    variable grback
    variable _

    foreach _ {
	! \" # $ % & ' ( ) * + , - . /
	0 1 2 3 4 5 6 7 8 9 : ; < = >
	? @ A B C D E F G H I J K L M
	N O P Q R S T U V W X Y Z [ ^
	\\ ]
    } {
	lappend grforw \016$_ $_\016
	lappend grback $_\017 \017$_
    }
    unset _
}

::term::ansi::code::ctrl::INIT

# ### ### ### ######### ######### #########
## Ready

package provide term::ansi::code::ctrl 0.2

##
# ### ### ### ######### ######### #########
