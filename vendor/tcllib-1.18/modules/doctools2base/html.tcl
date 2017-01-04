# -*- tcl -*-
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>

# Support package. Basic html generation commands.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.4 ; # Required Core
package require doctools::text ; # Basic generator state management.

namespace eval         ::doctools::html {}
doctools::text::import ::doctools::html

# # ## ### ##### ######## ############# #####################

proc ::doctools::html::begin {} {
    text::begin
    Begin
    return
}

proc ::doctools::html::save {} {
    variable state
    set current [array get state]
    text::save
    Begin
    set state(stack) $current
    return
}

proc ::doctools::html::restore {} {
    variable state
    set html [text::restore]
    array set state $state(stack)
    return $html
}

proc ::doctools::html::collect {script} {
    save
    uplevel 1 $script
    return [restore]
}

# # ## ### ##### ######## ############# #####################

proc ::doctools::html::tag1 {name args} {
    text::+ <$name
    if {[llength $args]} {
	foreach {a v} $args { text::+ " $a=\"$v\"" }
    }
    text::+ >
    return
}

proc ::doctools::html::tag {name args} {
    tagD $name $args
    return
}

proc ::doctools::html::tagD {name dict} {
    variable state
    lappend state(tstack) $name
    text::+ <$name
    if {[llength $dict]} {
	foreach {a v} $dict { text::+ " $a=\"$v\"" }
    }
    text::+ >
    return
}

proc ::doctools::html::/tag {} {
    variable state
    set tag           [lindex   $state(tstack) end]
    set state(tstack) [lreplace $state(tstack) end end]
    text::+ </$tag>
    return
}

proc ::doctools::html::tag/ {name args} {
    variable state
    lappend state(tstack) $tag
    text::+ <$tag
    if {[llength $args]} {
	foreach {a v} $args { text::+ " $a=\"$v\"" }
	text::+ { }
    }
    text::+ />
    return
}

proc ::doctools::html::tag* {name args} {
    set script [lindex   $args end]
    set args   [lreplace $args end end]
    tagD $name $args
    uplevel 1 $script
    /tag
    return
}

proc ::doctools::html::tag= {name args} {
    set text [lindex   $args end]
    set args [lreplace $args end end]
    eval [linsert $args 0 tag $name]
    + $text
    /tag
    return
}

# # ## ### ##### ######## ############# #####################

proc ::doctools::html::+ {text} {
    text::+ [Quote $text]
    return
}

proc ::doctools::html::comment {comment} {
    text::+ "<!-- ${comment} -->"
    return
}

proc ::doctools::html::++ {html} {
    text::+ $html
    return
}

# # ## ### ##### ######## ############# #####################

proc ::doctools::html::import {{namespace {}}} {
    uplevel 1 [list namespace eval ${namespace}::html {
	namespace import ::doctools::html::*
    }]
    return
}

proc ::doctools::html::importhere {{namespace ::}} {
    uplevel 1 [list namespace eval ${namespace} {
	namespace import ::doctools::html::*
    }]
    return
}

# # ## ### ##### ######## ############# #####################

proc ::doctools::html::Begin {} {
    variable state
    array unset state *
    array set   state {
	tags  {}
	stack {}
    }
    return
}

proc ::doctools::html::Quote {text} {
    variable textMap
    return [string map $textMap $text]
}

# # ## ### ##### ######## ############# #####################

namespace eval ::doctools::html {
    variable  state
    array set state {}

    # Replaces HTML markup characters in $text with the appropriate
    # entity references.

    variable textMap {
	&    &amp;    <    &lt;     >    &gt;       
	\xa0 &nbsp;	\xb0 &deg;    \xc0 &Agrave; \xd0 &ETH;    \xe0 &agrave; \xf0 &eth;
	\xa1 &iexcl;	\xb1 &plusmn; \xc1 &Aacute; \xd1 &Ntilde; \xe1 &aacute; \xf1 &ntilde;
	\xa2 &cent;	\xb2 &sup2;   \xc2 &Acirc;  \xd2 &Ograve; \xe2 &acirc;  \xf2 &ograve;
	\xa3 &pound;	\xb3 &sup3;   \xc3 &Atilde; \xd3 &Oacute; \xe3 &atilde; \xf3 &oacute;
	\xa4 &curren;	\xb4 &acute;  \xc4 &Auml;   \xd4 &Ocirc;  \xe4 &auml;   \xf4 &ocirc;
	\xa5 &yen;	\xb5 &micro;  \xc5 &Aring;  \xd5 &Otilde; \xe5 &aring;  \xf5 &otilde;
	\xa6 &brvbar;	\xb6 &para;   \xc6 &AElig;  \xd6 &Ouml;   \xe6 &aelig;  \xf6 &ouml;
	\xa7 &sect;	\xb7 &middot; \xc7 &Ccedil; \xd7 &times;  \xe7 &ccedil; \xf7 &divide;
	\xa8 &uml;	\xb8 &cedil;  \xc8 &Egrave; \xd8 &Oslash; \xe8 &egrave; \xf8 &oslash;
	\xa9 &copy;	\xb9 &sup1;   \xc9 &Eacute; \xd9 &Ugrave; \xe9 &eacute; \xf9 &ugrave;
	\xaa &ordf;	\xba &ordm;   \xca &Ecirc;  \xda &Uacute; \xea &ecirc;  \xfa &uacute;
	\xab &laquo;	\xbb &raquo;  \xcb &Euml;   \xdb &Ucirc;  \xeb &euml;   \xfb &ucirc;
	\xac &not;	\xbc &frac14; \xcc &Igrave; \xdc &Uuml;   \xec &igrave; \xfc &uuml;
	\xad &shy;	\xbd &frac12; \xcd &Iacute; \xdd &Yacute; \xed &iacute; \xfd &yacute;
	\xae &reg;	\xbe &frac34; \xce &Icirc;  \xde &THORN;  \xee &icirc;  \xfe &thorn;
	\xaf &hibar;	\xbf &iquest; \xcf &Iuml;   \xdf &szlig;  \xef &iuml;   \xff &yuml;
    {"} &quot;
} ; # " make the emacs highlighting code happy.

    # Text commands which are html commands, unchanged
    namespace import                \
	::doctools::text::done      \
	::doctools::text::+++       \
	::doctools::text::newline   \
	::doctools::text::prefix    \
	::doctools::text::indent    \
	::doctools::text::dedent    \
	::doctools::text::indented  \
	::doctools::text::indenting \
	::doctools::text::newlines

    namespace export begin done save restore collect + +++ \
	prefix indent dedent indented indenting newline newlines \
	tag /tag tag/ tag* tag1 tag= comment ++
}

# # ## ### ##### ######## ############# #####################
package provide doctools::html 0.1
return
