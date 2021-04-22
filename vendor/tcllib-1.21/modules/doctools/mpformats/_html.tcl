# -*- tcl -*-
# Copyright (c) 2001-2019 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# Helper rules for the creation of the memchan website from the .exp files.
# General formatting instructions ...
#
# htmlEscape text --
#	Replaces HTML markup characters in $text with the
#	appropriate entity references.
#

global textMap;
set    textMap {
    &    &amp;    <    &lt;     >    &gt;       
    \xa0 &nbsp;   \xb0 &deg;    \xc0 &Agrave; \xd0 &ETH;    \xe0 &agrave; \xf0 &eth;
    \xa1 &iexcl;  \xb1 &plusmn; \xc1 &Aacute; \xd1 &Ntilde; \xe1 &aacute; \xf1 &ntilde;
    \xa2 &cent;	  \xb2 &sup2;   \xc2 &Acirc;  \xd2 &Ograve; \xe2 &acirc;  \xf2 &ograve;
    \xa3 &pound;  \xb3 &sup3;   \xc3 &Atilde; \xd3 &Oacute; \xe3 &atilde; \xf3 &oacute;
    \xa4 &curren; \xb4 &acute;  \xc4 &Auml;   \xd4 &Ocirc;  \xe4 &auml;   \xf4 &ocirc;
    \xa5 &yen;	  \xb5 &micro;  \xc5 &Aring;  \xd5 &Otilde; \xe5 &aring;  \xf5 &otilde;
    \xa6 &brvbar; \xb6 &para;   \xc6 &AElig;  \xd6 &Ouml;   \xe6 &aelig;  \xf6 &ouml;
    \xa7 &sect;	  \xb7 &middot; \xc7 &Ccedil; \xd7 &times;  \xe7 &ccedil; \xf7 &divide;
    \xa8 &uml;	  \xb8 &cedil;  \xc8 &Egrave; \xd8 &Oslash; \xe8 &egrave; \xf8 &oslash;
    \xa9 &copy;	  \xb9 &sup1;   \xc9 &Eacute; \xd9 &Ugrave; \xe9 &eacute; \xf9 &ugrave;
    \xaa &ordf;	  \xba &ordm;   \xca &Ecirc;  \xda &Uacute; \xea &ecirc;  \xfa &uacute;
    \xab &laquo;  \xbb &raquo;  \xcb &Euml;   \xdb &Ucirc;  \xeb &euml;   \xfb &ucirc;
    \xac &not;	  \xbc &frac14; \xcc &Igrave; \xdc &Uuml;   \xec &igrave; \xfc &uuml;
    \xad &shy;	  \xbd &frac12; \xcd &Iacute; \xdd &Yacute; \xed &iacute; \xfd &yacute;
    \xae &reg;	  \xbe &frac34; \xce &Icirc;  \xde &THORN;  \xee &icirc;  \xfe &thorn;
    \xaf &hibar;  \xbf &iquest; \xcf &Iuml;   \xdf &szlig;  \xef &iuml;   \xff &yuml;
    {"} &quot;
} ; # " make the emacs highlighting code happy.

# Handling of HTML delimiters in content:
#
# Plain text is initially passed through unescaped;
# internally-generated markup is protected by preceding it with \1.
# The final PostProcess step strips the escape character from
# real markup and replaces markup characters from content
# with entity references.
#

global   markupMap
set      markupMap { {&} {\1&}  {<} {\1<}  {>} {\1>} {"} {\1"} } 
global   finalMap
set      finalMap $textMap
lappend  finalMap {\1&} {&}  {\1<} {<}  {\1>} {>} {\1"} {"}


proc htmlEscape {text} {
    global textMap
    return [string map $textMap $text]
}

proc fmt_postprocess {text} {
    global finalMap

    if 0 {
	puts_stderr ____________________________________________________________
	puts_stderr $text
	puts_stderr ____________________________________________________________
    }

    # Put protected characters into their final form.
    set text [string map $finalMap $text]
    # Remove leading/trailing whitespace from paragraphs.
    regsub -all "<p>\[\t\n \]*" $text {<p>} text
    regsub -all "\[\t\n \]*</p>" $text {</p>} text
    # Remove trailing linebreaks from paragraphs.
    while {[regsub -all "<br>\[\t\n \]*</p>" $text {</p>} text]} continue
    # Remove empty paragraphs
    regsub -all "<p>\[\t\n \]*</p>" $text {} text
    # Separate paragraphs
    regsub -all "</p><p>" $text "</p>\n<p>" text
    # Separate bigger structures
    foreach outer {div p dl ul ol} {
	foreach inner {div p dl ul ol} {
	    regsub -all "</${outer}><${inner}"  $text "</${outer}>\n<${inner}"  text
	    regsub -all "</${outer}></${inner}" $text "</${outer}>\n</${inner}" text
	}
    }
    regsub -all "<li><dl"   $text "<li>\n<dl"  text
    regsub -all "<li><ol"   $text "<li>\n<ol"  text
    regsub -all "<li><ul"   $text "<li>\n<ul"  text
    regsub -all "</dl></li" $text "</dl>\n</li" text
    regsub -all "</ol></li" $text "</ol>\n</li" text
    regsub -all "</ul></li" $text "</ul>\n</li" text
    # Remove empty lines.
    regsub -all "\n\n\n*" $text \n text

    if 0 {
	puts_stderr @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	puts_stderr $text
	puts_stderr @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    }

    return [string trimleft $text]
}

# markup text --
#	Protect markup characters in $text with \1.
#	These will be stripped out in PostProcess.
#
proc markup {text} {
    global markupMap
    return [string map $markupMap $text]
}

proc use_bg {} {
    set c [bgcolor]
    #puts stderr "using $c"
    if {$c == {}} {return ""}
    return bgcolor=$c
}

proc MakeLink {l t} { link $l $t }

proc nbsp   {}         {return [markup "&nbsp;"]}
proc p      {}         {return [markup <p>]}
proc ptop   {}         {return [markup "<p valign=top>"]}
proc td     {}         {return [markup "<td [use_bg]>"]}
proc trtop  {}         {return [markup "<tr valign=top [use_bg]>"]}
proc tr     {}         {return [markup "<tr            [use_bg]>"]}
proc sect   {s}        {return [markup <b>]$s[markup </b><br><hr>]}
proc link   {text url} {return [markup "<a href=\"$url\">"]$text[markup </a>]}
proc table  {}         {return [markup "<table [border] width=100% cellspacing=0 cellpadding=0>"]}
proc btable {}         {return [markup "<table border=1 width=100% cellspacing=0 cellpadding=0>"]}
proc stable {}         {return [markup "<table [border] cellspacing=0 cellpadding=0>"]}

proc link   {text url} {return [markup "<a href=\"$url\">"]$text[markup </a>]}

proc tcl_cmd {cmd} {return "[markup <b>]\[$cmd][markup </b>]"}
proc wget    {url} {exec /usr/bin/wget -q -O - $url 2>/dev/null}

proc url {tag text url} {
    set body {
	switch -exact -- $what {
	    link {return {\1<a href="%url%"\1>%text%\1</a\1>}} ; ## TODO - markup
	    text {return {%text%}}
	    url  {return {%url%}}
	}
    }
    proc $tag {{what link}} [string map [list %text% $text %url% $url] $body]
}

proc img {tag alt img} {
    proc $tag {} [list return "\1<img alt=\"$alt\" src=\"$img\"\1>"]
}

proc imagelink {alt img} {
    return [markup "<img alt=\"$alt\" src=\"$img\">"]
}

proc protect {text} {return [string map [list & "&amp;" < "&lt;" > "&gt;"] $text]}

proc strong {text}       {tag_ strong $text}
proc em     {text}       {tag_ em     $text}
proc bold   {text class} {tag_ b      $text class $class}
proc italic {text class} {tag_ i      $text class $class}
proc span   {text class} {tag_ span   $text class $class}

proc tag  {t} {return [markup <$t>]}
proc taga {t av} {
    # av = attribute value ...
    set avt [list]
    foreach {a v} $av {lappend avt "$a=\"$v\""}
    return [markup "<$t [join $avt]>"]
}
proc tag/ {t} {return [markup </$t>]}
proc tag_ {t block args} {
    # args = key value ...
    if {$args == {}} {return "[tag $t]$block[tag/ $t]"}
    return "[taga $t $args]$block[tag/ $t]"
}
proc tag* {t args} {
    if {[llength $args]} {
	taga $t $args
    } else {
	tag $t
    }
}

proc ht_comment {text}   {
    return "[markup <]!-- [htmlEscape [join [split $text \n] "   -- "]]\n   --[markup >]"
}

# wrap content gi --
#	Returns $content wrapped inside <$gi> ... </$gi> tags.
#
proc wrap {content gi} {
    return "[tag $gi]${content}[tag/ $gi]"
}
proc startTag {x args} {if {[llength $args]} {taga $x $args} else {tag $x}}
proc endTag   {x} {tag/ $x}


proc anchor {name text} {
    return [taga a [list name $name]]$text[tag/ a]
}
