# html.tcl --
#
#	Procedures to make generating HTML easier.
#
#	This module depends on the ncgi module for the procedures
#	that initialize form elements based on current CGI values.
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
# Copyright (c) 2006 Michael Schlenker <mic42@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# Originally by Brent Welch, with help from Dan Kuchler and Melissa Chawla

package require Tcl 8.2
package require ncgi
package provide html 1.5

namespace eval ::html {

    # State about the current page

    variable page

    # A simple set of global defaults for tag parameters is implemented
    # by storing into elements indexed by "key.param", where key is
    # often the name of an HTML tag (anything for scoping), and
    # param must be the name of the HTML tag parameter (e.g., "href" or "size")
    #	input.size
    #	body.bgcolor
    #	body.text
    #	font.face
    #	font.size
    #	font.color

    variable defaults
    array set defaults {
	input.size	45
	body.bgcolor	white
	body.text	black
    }

    # In order to nandle nested calls to redefined control structures,
    # we need a temporary variable that is known not to exist.  We keep this
    # counter to append to the varname.  Each time we need a temporary
    # variable, we increment this counter.

    variable randVar 0

    # No more export, because this defines things like
    # foreach and if that do HTML things, not Tcl control
    # namespace export *

    # Dictionary mapping from special characters to their entities.

    variable entities {
        \xa0 &nbsp; \xa1 &iexcl; \xa2 &cent; \xa3 &pound; \xa4 &curren;
        \xa5 &yen; \xa6 &brvbar; \xa7 &sect; \xa8 &uml; \xa9 &copy;
        \xaa &ordf; \xab &laquo; \xac &not; \xad &shy; \xae &reg;
        \xaf &macr; \xb0 &deg; \xb1 &plusmn; \xb2 &sup2; \xb3 &sup3;
        \xb4 &acute; \xb5 &micro; \xb6 &para; \xb7 &middot; \xb8 &cedil;
        \xb9 &sup1; \xba &ordm; \xbb &raquo; \xbc &frac14; \xbd &frac12;
        \xbe &frac34; \xbf &iquest; \xc0 &Agrave; \xc1 &Aacute; \xc2 &Acirc;
        \xc3 &Atilde; \xc4 &Auml; \xc5 &Aring; \xc6 &AElig; \xc7 &Ccedil;
        \xc8 &Egrave; \xc9 &Eacute; \xca &Ecirc; \xcb &Euml; \xcc &Igrave;
        \xcd &Iacute; \xce &Icirc; \xcf &Iuml; \xd0 &ETH; \xd1 &Ntilde;
        \xd2 &Ograve; \xd3 &Oacute; \xd4 &Ocirc; \xd5 &Otilde; \xd6 &Ouml;
        \xd7 &times; \xd8 &Oslash; \xd9 &Ugrave; \xda &Uacute; \xdb &Ucirc;
        \xdc &Uuml; \xdd &Yacute; \xde &THORN; \xdf &szlig; \xe0 &agrave;
        \xe1 &aacute; \xe2 &acirc; \xe3 &atilde; \xe4 &auml; \xe5 &aring;
        \xe6 &aelig; \xe7 &ccedil; \xe8 &egrave; \xe9 &eacute; \xea &ecirc;
        \xeb &euml; \xec &igrave; \xed &iacute; \xee &icirc; \xef &iuml;
        \xf0 &eth; \xf1 &ntilde; \xf2 &ograve; \xf3 &oacute; \xf4 &ocirc;
        \xf5 &otilde; \xf6 &ouml; \xf7 &divide; \xf8 &oslash; \xf9 &ugrave;
        \xfa &uacute; \xfb &ucirc; \xfc &uuml; \xfd &yacute; \xfe &thorn;
        \xff &yuml; \u192 &fnof; \u391 &Alpha; \u392 &Beta; \u393 &Gamma;
        \u394 &Delta; \u395 &Epsilon; \u396 &Zeta; \u397 &Eta; \u398 &Theta;
        \u399 &Iota; \u39A &Kappa; \u39B &Lambda; \u39C &Mu; \u39D &Nu;
        \u39E &Xi; \u39F &Omicron; \u3A0 &Pi; \u3A1 &Rho; \u3A3 &Sigma;
        \u3A4 &Tau; \u3A5 &Upsilon; \u3A6 &Phi; \u3A7 &Chi; \u3A8 &Psi;
        \u3A9 &Omega; \u3B1 &alpha; \u3B2 &beta; \u3B3 &gamma; \u3B4 &delta;
        \u3B5 &epsilon; \u3B6 &zeta; \u3B7 &eta; \u3B8 &theta; \u3B9 &iota;
        \u3BA &kappa; \u3BB &lambda; \u3BC &mu; \u3BD &nu; \u3BE &xi;
        \u3BF &omicron; \u3C0 &pi; \u3C1 &rho; \u3C2 &sigmaf; \u3C3 &sigma;
        \u3C4 &tau; \u3C5 &upsilon; \u3C6 &phi; \u3C7 &chi; \u3C8 &psi;
        \u3C9 &omega; \u3D1 &thetasym; \u3D2 &upsih; \u3D6 &piv;
        \u2022 &bull; \u2026 &hellip; \u2032 &prime; \u2033 &Prime;
        \u203E &oline; \u2044 &frasl; \u2118 &weierp; \u2111 &image;
        \u211C &real; \u2122 &trade; \u2135 &alefsym; \u2190 &larr;
        \u2191 &uarr; \u2192 &rarr; \u2193 &darr; \u2194 &harr; \u21B5 &crarr;
        \u21D0 &lArr; \u21D1 &uArr; \u21D2 &rArr; \u21D3 &dArr; \u21D4 &hArr;
        \u2200 &forall; \u2202 &part; \u2203 &exist; \u2205 &empty;
        \u2207 &nabla; \u2208 &isin; \u2209 &notin; \u220B &ni; \u220F &prod;
        \u2211 &sum; \u2212 &minus; \u2217 &lowast; \u221A &radic;
        \u221D &prop; \u221E &infin; \u2220 &ang; \u2227 &and; \u2228 &or;
        \u2229 &cap; \u222A &cup; \u222B &int; \u2234 &there4; \u223C &sim;
        \u2245 &cong; \u2248 &asymp; \u2260 &ne; \u2261 &equiv; \u2264 &le;
        \u2265 &ge; \u2282 &sub; \u2283 &sup; \u2284 &nsub; \u2286 &sube;
        \u2287 &supe; \u2295 &oplus; \u2297 &otimes; \u22A5 &perp;
        \u22C5 &sdot; \u2308 &lceil; \u2309 &rceil; \u230A &lfloor;
        \u230B &rfloor; \u2329 &lang; \u232A &rang; \u25CA &loz;
        \u2660 &spades; \u2663 &clubs; \u2665 &hearts; \u2666 &diams;
        \x22 &quot; \x26 &amp; \x3C &lt; \x3E &gt; \u152 &OElig;
        \u153 &oelig; \u160 &Scaron; \u161 &scaron; \u178 &Yuml;
        \u2C6 &circ; \u2DC &tilde; \u2002 &ensp; \u2003 &emsp; \u2009 &thinsp;
        \u200C &zwnj; \u200D &zwj; \u200E &lrm; \u200F &rlm; \u2013 &ndash;
        \u2014 &mdash; \u2018 &lsquo; \u2019 &rsquo; \u201A &sbquo;
        \u201C &ldquo; \u201D &rdquo; \u201E &bdquo; \u2020 &dagger;
        \u2021 &Dagger; \u2030 &permil; \u2039 &lsaquo; \u203A &rsaquo;
        \u20AC &euro;
    }
}

# ::html::foreach
#
#	Rework the "foreach" command to blend into HTML template files.
#	Rather than evaluating the body, we return the subst'ed body.  Each
#	iteration of the loop causes another string to be concatenated to
#	the result value.  No error checking is done on any arguments.
#
# Arguments:
#	varlist	Variables to instantiate with values from the next argument.
#	list	Values to set variables in varlist to.
#	args	?varlist2 list2 ...? body, where body is the string to subst
#		during each iteration of the loop.
#
# Results:
#	Returns a string composed of multiple concatenations of the
#	substitued body.
#
# Side Effects:
#	None.

proc ::html::foreach {vars vals args} {
    variable randVar

    # The body of the foreach loop must be run in the stack frame
    # above this one in order to have access to local variable at that stack
    # level.

    # To support nested foreach loops, we use a uniquely named
    # variable to store incremental results.
    incr randVar
    ::set resultVar "result_$randVar"

    # Extract the body and any varlists and valuelists from the args.
    ::set body [lindex $args end]
    ::set varvals [linsert [lreplace $args end end] 0 $vars $vals]

    # Create the script to eval in the stack frame above this one.
    ::set script "::foreach"
    ::foreach {vars vals} $varvals {
        append script " [list $vars] [list $vals]"
    }
    append script " \{\n"
    append script "  append $resultVar \[subst \{$body\}\]\n"
    append script "\}\n"

    # Create a temporary variable in the stack frame above this one,
    # and use it to store the incremental results of the multiple loop
    # iterations.  Remove the temporary variable when we're done so there's
    # no trace of this loop left in that stack frame.

    upvar 1 $resultVar tmp
    ::set tmp ""
    uplevel 1 $script
    ::set result $tmp
    unset tmp
    return $result
}

# ::html::for
#
#	Rework the "for" command to blend into HTML template files.
#	Rather than evaluating the body, we return the subst'ed body.  Each
#	iteration of the loop causes another string to be concatenated to
#	the result value.  No error checking is done on any arguments.
#
# Arguments:
#	start	A script to evaluate once at the very beginning.
#	test	An expression to eval before each iteration of the loop.
#		Once the expression is false, the command returns.
#	next	A script to evaluate after each iteration of the loop.
#	body	The string to subst during each iteration of the loop.
#
# Results:
#	Returns a string composed of multiple concatenations of the
#	substitued body.
#
# Side Effects:
#	None.

proc ::html::for {start test next body} {
    variable randVar

    # The body of the for loop must be run in the stack frame
    # above this one in order to have access to local variable at that stack
    # level.

    # To support nested for loops, we use a uniquely named
    # variable to store incremental results.
    incr randVar
    ::set resultVar "result_$randVar"

    # Create the script to eval in the stack frame above this one.
    ::set script "::for [list $start] [list $test] [list $next] \{\n"
    append script "  append $resultVar \[subst \{$body\}\]\n"
    append script "\}\n"

    # Create a temporary variable in the stack frame above this one,
    # and use it to store the incremental resutls of the multiple loop
    # iterations.  Remove the temporary variable when we're done so there's
    # no trace of this loop left in that stack frame.

    upvar 1 $resultVar tmp
    ::set tmp ""
    uplevel 1 $script
    ::set result $tmp
    unset tmp
    return $result
}

# ::html::while
#
#	Rework the "while" command to blend into HTML template files.
#	Rather than evaluating the body, we return the subst'ed body.  Each
#	iteration of the loop causes another string to be concatenated to
#	the result value.  No error checking is done on any arguments.
#
# Arguments:
#	test	An expression to eval before each iteration of the loop.
#		Once the expression is false, the command returns.
#	body	The string to subst during each iteration of the loop.
#
# Results:
#	Returns a string composed of multiple concatenations of the
#	substitued body.
#
# Side Effects:
#	None.

proc ::html::while {test body} {
    variable randVar

    # The body of the while loop must be run in the stack frame
    # above this one in order to have access to local variable at that stack
    # level.

    # To support nested while loops, we use a uniquely named
    # variable to store incremental results.
    incr randVar
    ::set resultVar "result_$randVar"

    # Create the script to eval in the stack frame above this one.
    ::set script "::while [list $test] \{\n"
    append script "  append $resultVar \[subst \{$body\}\]\n"
    append script "\}\n"

    # Create a temporary variable in the stack frame above this one,
    # and use it to store the incremental resutls of the multiple loop
    # iterations.  Remove the temporary variable when we're done so there's
    # no trace of this loop left in that stack frame.

    upvar 1 $resultVar tmp
    ::set tmp ""
    uplevel 1 $script
    ::set result $tmp
    unset tmp
    return $result
}

# ::html::if
#
#	Rework the "if" command to blend into HTML template files.
#	Rather than evaluating a body clause, we return the subst'ed body.
#	No error checking is done on any arguments.
#
# Arguments:
#	test	An expression to eval to decide whether to use the then body.
#	body	The string to subst if the test case was true.
#	args	?elseif test body2 ...? ?else bodyn?, where bodyn is the string
#		to subst if none of the tests are true.
#
# Results:
#	Returns a string composed by substituting a body clause.
#
# Side Effects:
#	None.

proc ::html::if {test body args} {
    variable randVar

    # The body of the then/else clause must be run in the stack frame
    # above this one in order to have access to local variable at that stack
    # level.

    # To support nested if's, we use a uniquely named
    # variable to store incremental results.
    incr randVar
    ::set resultVar "result_$randVar"

    # Extract the elseif clauses and else clause if they exist.
    ::set cmd [linsert $args 0 "::if" $test $body]

    ::foreach {keyword test body} $cmd {
        ::if {[string equal $keyword "else"]} {
            append script " else \{\n"
            ::set body $test
        } else {
            append script " $keyword [list $test] \{\n"
        }
        append script "  append $resultVar \[subst \{$body\}\]\n"
        append script "\} "
    }

    # Create a temporary variable in the stack frame above this one,
    # and use it to store the incremental resutls of the multiple loop
    # iterations.  Remove the temporary variable when we're done so there's
    # no trace of this loop left in that stack frame.

    upvar $resultVar tmp
    ::set tmp ""
    uplevel $script
    ::set result $tmp
    unset tmp
    return $result
}

# ::html::set
#
#	Rework the "set" command to blend into HTML template files.
#	The return value is always "" so nothing is appended in the
#	template.  No error checking is done on any arguments.
#
# Arguments:
#	var	The variable to set.
#	val	The new value to give the variable.
#
# Results:
#	Returns "".
#
# Side Effects:
#	None.

proc ::html::set {var val} {

    # The variable must be set in the stack frame above this one.

    ::set cmd [list set $var $val]
    uplevel 1 $cmd
    return ""
}

# ::html::eval
#
#	Rework the "eval" command to blend into HTML template files.
#	The return value is always "" so nothing is appended in the
#	template.  No error checking is done on any arguments.
#
# Arguments:
#	args	The args to evaluate.  At least one must be given.
#
# Results:
#	Returns "".
#
# Side Effects:
#	Throws an error if no arguments are given.

proc ::html::eval {args} {

    # The args must be evaluated in the stack frame above this one.
    ::eval [linsert $args 0 uplevel 1]
    return ""
}

# ::html::init
#
#	Reset state that gets accumulated for the current page.
#
# Arguments:
#	nvlist	Name, value list that is used to initialize default namespace
#		variables that set font, size, etc.
#
# Side Effects:
#	Wipes the page state array

proc ::html::init {{nvlist {}}} {
    variable page
    variable defaults
    ::if {[info exists page]} {
	unset page
    }
    ::if {[info exists defaults]} {
	unset defaults
    }
    array set defaults $nvlist
}

# ::html::head
#
#	Generate the <head> section.  There are a number of
#	optional calls you make *before* this to inject
#	meta tags - see everything between here and the bodyTag proc.
#
# Arguments:
#	title	The page title
#
# Results:
#	HTML for the <head> section

proc ::html::head {title} {
    variable page
    ::set html "[openTag html][openTag head]\n"
    append html "\t[title $title]"
    ::if {[info exists page(author)]} {
	append html "\t$page(author)"
    }
    ::if {[info exists page(meta)]} {
	::foreach line $page(meta) {
	    append html "\t$line\n"
	}
    }
    ::if {[info exists page(css)]} {
	::foreach style $page(css) {
	    append html "\t$style\n"
	}
    }
    ::if {[info exists page(js)]} {
	::foreach script $page(js) {
	    append html "\t$script\n"
	}
    }
    append html "[closeTag]\n"
}

# ::html::title
#
#	Wrap up the <title> and tuck it away for use in the page later.
#
# Arguments:
#	title	The page title
#
# Results:
#	HTML for the <title> section

proc ::html::title {title} {
    variable page
    ::set page(title) $title
    ::set html "<title>$title</title>\n"
    return $html
}

# ::html::getTitle
#
#	Return the title of the current page.
#
# Arguments:
#	None
#
# Results:
#	The title

proc ::html::getTitle {} {
    variable page
    ::if {[info exists page(title)]} {
	return $page(title)
    } else {
	return ""
    }
}

# ::html::meta
#
#	Generate a meta tag.  This tag gets bundled into the <head>
#	section generated by html::head
#
# Arguments:
#	args	A name-value list of meta tag names and values.
#
# Side Effects:
#	Stores HTML for the <meta> tag for use later by html::head

# Ref: https://www.w3schools.com/tags/tag_meta.asp

proc ::html::meta {args} {
    # compatibility command
    variable page
    append html ""
    ::foreach {name value} $args {
	append html "<meta name=\"$name\" content=\"[quoteFormValue $value]\">"
    }
    lappend page(meta) $html
    return ""
}

proc ::html::meta_name {args} {
    variable page
    append html ""
    ::foreach {name value} $args {
	append html "<meta name=\"$name\" content=\"[quoteFormValue $value]\">"
    }
    lappend page(meta) $html
    return ""
}

proc ::html::meta_charset {charset} {
    variable page
    append html "<meta charset=\"[quoteFormValue $charset]\">"
    lappend page(meta) $html
    return ""
}

proc ::html::meta_equiv {args} {
    variable page
    append html ""
    ::foreach {name value} $args {
	append html "<meta http-equiv=\"$name\" content=\"[quoteFormValue $value]\">"
    }
    lappend page(meta) $html
    return ""
}

# ::html::refresh
#
#	Generate a meta refresh tag.  This tag gets bundled into the <head>
#	section generated by html::head
#
# Arguments:
#	content	Time period, in seconds, before the refresh
#	url	(option) new page to view. If not specified, then
#		the current page is reloaded.
#
# Side Effects:
#	Stores HTML for the <meta> tag for use later by html::head

proc ::html::refresh {content {url {}}} {
    variable page
    ::set html "<meta http-equiv=\"Refresh\" content=\"$content"
    ::if {[string length $url]} {
	append html "; url=$url"
    }
    append html "\">"
    lappend page(meta) $html
    return ""
}

# ::html::headTag
#
#	Embed a tag into the HEAD section
#	generated by html::head
#
# Arguments:
#	string	Everything but the < > for the tag.
#
# Side Effects:
#	Stores HTML for the tag for use later by html::head

proc ::html::headTag {string} {
    variable page
    lappend page(meta) <$string>
    return ""
}

# ::html::keywords
#
#	Add META tag keywords to the <head> section.
#	Call this before you call html::head
#
# Arguments:
#	args	The keywords
#
# Side Effects:
#	See html::meta

proc ::html::keywords {args} {
    html::meta keywords [join $args ", "]
}

# ::html::description
#
#	Add a description META tag to the <head> section.
#	Call this before you call html::head
#
# Arguments:
#	description	The description
#
# Side Effects:
#	See html::meta

proc ::html::description {description} {
    html::meta description $description
}

# ::html::author
#
#	Add an author comment to the <head> section.
#	Call this before you call html::head
#
# Arguments:
#	author	Author's name
#
# Side Effects:
#	sets page(author)

proc ::html::author {author} {
    variable page
    ::set page(author) "<!-- $author -->\n"
    return ""
}

# ::html::tagParam
#
#	Return a name, value string for the tag parameters.
#	The values come from "hard-wired" values in the
#	param argument, or from the defaults set with html::init.
#
# Arguments:
#	tag	Name of the HTML tag (case insensitive).
#	param	pname=value info that overrides any default values
#
# Results
#	A string of the form:
#		pname="keyvalue" name2="2nd value"

proc ::html::tagParam {tag {param {}}} {
    variable defaults

    ::set def ""
    ::foreach key [lsort [array names defaults $tag.*]] {
	append def [default $key $param]
    }
    return [string trimleft $param$def]
}

# ::html::default
#
#	Return a default value, if one has been registered
#	and an overriding value does not occur in the existing
#	tag parameters.
#
# Arguments:
#	key	Index into the defaults array defined by html::init
#		This is expected to be in the form tag.pname where
#		the pname part is used in the tag parameter name
#	param	pname=value info that overrides any default values
#
# Results
#	pname="keyvalue"

proc ::html::default {key {param {}}} {
    variable defaults
    ::set pname [string tolower [lindex [split $key .] 1]]
    ::set key [string tolower $key]
    ::if {![regexp -nocase "(\[ 	\]|^)$pname=" $param] &&
	    [info exists defaults($key)] &&
	    [string length $defaults($key)]} {
	return " $pname=\"$defaults($key)\""
    } else {
	return ""
    }
}

# ::html::bodyTag
#
#	Generate a body tag
#
# Arguments:
#	none
#
# Results
#	A body tag

proc ::html::bodyTag {args} {
    return [openTag body [join $args]]\n
}

# The following procedures are all related to generating form elements
# that are initialized to store the current value of the form element
# based on the CGI state.  These functions depend on the ncgi::value
# procedure and assume that the caller has called ncgi::parse and/or
# ncgi::init appropriately to initialize the ncgi module.

# ::html::formValue
#
#	Return a name and value pair, where the value is initialized
#	from existing form data, if any.
#
# Arguments:
#	name		The name of the form element
#	defvalue	A default value to use, if not appears in the CGI
#			inputs.  DEPRECATED - use ncgi::defValue instead.
#
# Retults:
#	A string like:
#	name="fred" value="freds value"

proc ::html::formValue {name {defvalue {}}} {
    ::set value [ncgi::value $name]
    ::if {[string length $value] == 0} {
	::set value $defvalue
    }
    return "name=\"$name\" value=\"[quoteFormValue $value]\""
}

# ::html::quoteFormValue
#
#	Quote a value for use in a value=\"$value\" fragment.
#
# Arguments:
#	value		The value to quote
#
# Retults:
#	A string like:
#	&#34;Hello, &lt;b&gt;World!&#34;

proc ::html::quoteFormValue {value} {
    return [string map [list "&" "&amp;" "\"" "&#34;" \
			    "'" "&#39;" "<" "&lt;" ">" "&gt;"] $value]
}

# ::html::textInput --
#
#	Return an <input type=text> element.  This uses the
#	input.size default falue.
#
# Arguments:
#	name		The form element name
#	args		Additional attributes for the INPUT tag
#
# Results:
#	The html fragment

proc ::html::textInput {name {value {}} args} {
    ::set html "<input type=\"text\" "
    append html [formValue $name $value]
    append html [default input.size $args]
    ::if {[llength $args] != 0} then {
	append html " " [join $args]
    }
    append html ">\n"
    return $html
}

# ::html::textInputRow --
#
#	Format a table row containing a text input element and a label.
#
# Arguments:
#	label	Label to display next to the form element
#	name	The form element name
#	args	Additional attributes for the INPUT tag
#
# Results:
#	The html fragment

proc ::html::textInputRow {label name {value {}} args} {
    ::set html [row $label [::eval [linsert $args 0 html::textInput $name $value]]]
    return $html
}

# ::html::passwordInputRow --
#
#	Format a table row containing a password input element and a label.
#
# Arguments:
#	label	Label to display next to the form element
#	name	The form element name
#
# Results:
#	The html fragment

proc ::html::passwordInputRow {label {name password}} {
    ::set html [row $label [passwordInput $name]]
    return $html
}

# ::html::passwordInput --
#
#	Return an <input type=password> element.
#
# Arguments:
#	name	The form element name. Defaults to "password"
#
# Results:
#	The html fragment

proc ::html::passwordInput {{name password}} {
    ::set html "<input type=\"password\" name=\"$name\">\n"
    return $html
}

# ::html::checkbox --
#
#	Format a checkbox so that it retains its state based on
#	the current CGI values
#
# Arguments:
#	name		The form element name
#	value		The value associated with the checkbox
#
# Results:
#	The html fragment

proc ::html::checkbox {name value} {
    ::set html "<input type=\"checkbox\" [checkValue $name $value]>\n"
}

# ::html::checkValue
#
#	Like html::formalue, but for checkboxes that need CHECKED
#
# Arguments:
#	name		The name of the form element
#	defvalue	A default value to use, if not appears in the CGI
#			inputs
#
# Retults:
#	A string like:
#	name="fred" value="freds value" CHECKED


proc ::html::checkValue {name {value 1}} {
    ::foreach v [ncgi::valueList $name] {
	::if {[string compare $value $v] == 0} {
	    return "name=\"$name\" value=\"[quoteFormValue $value]\" checked"
	}
    }
    return "name=\"$name\" value=\"[quoteFormValue $value]\""
}

# ::html::radioValue
#
#	Like html::formValue, but for radioboxes that need CHECKED
#
# Arguments:
#	name	The name of the form element
#	value	The value associated with the radio button.
#
# Retults:
#	A string like:
#	name="fred" value="freds value" CHECKED

proc ::html::radioValue {name value {defaultSelection {}}} {
    ::if {[string equal $value [ncgi::value $name $defaultSelection]]} {
	return "name=\"$name\" value=\"[quoteFormValue $value]\" checked"
    } else {
	return "name=\"$name\" value=\"[quoteFormValue $value]\""
    }
}

# ::html::radioSet --
#
#	Display a set of radio buttons while looking for an existing
#	value from the query data, if any.

proc ::html::radioSet {key sep list {defaultSelection {}}} {
    ::set html ""
    ::set s ""
    ::foreach {label v} $list {
	append html "$s<input type=\"radio\" [radioValue $key $v $defaultSelection]> $label"
	::set s $sep
    }
    return $html
}

# ::html::checkSet --
#
#	Display a set of check buttons while looking for an existing
#	value from the query data, if any.

proc ::html::checkSet {key sep list} {
    ::set s ""
    ::foreach {label v} $list {
	append html "$s<input type=\"checkbox\" [checkValue $key $v]> $label"
	::set s $sep
    }
    return $html
}

# ::html::select --
#
#	Format a <select> element that retains the state of the
#	current CGI values.
#
# Arguments:
#	name		The form element name
#	param		The various size, multiple parameters for the tag
#	choices		A simple list of choices
#	current		Value to assume if nothing is in CGI state
#
# Results:
#	The html fragment

proc ::html::select {name param choices {current {}}} {
    ::set def [ncgi::valueList $name $current]
    ::set html "<select name=\"$name\"[string trimright  " $param"]>\n"
    ::foreach {label v} $choices {
	::if {[lsearch -exact $def $v] != -1} {
	    ::set SEL " selected"
	} else {
	    ::set SEL ""
	}
	append html "<option value=\"$v\"$SEL>$label\n"
    }
    append html "</select>\n"
    return $html
}

# ::html::selectPlain --
#
#	Format a <select> element where the values are the same
#	as those that are displayed.
#
# Arguments:
#	name		The form element name
#	param		Tag parameters
#	choices		A simple list of choices
#
# Results:
#	The html fragment

proc ::html::selectPlain {name param choices {current {}}} {
    ::set namevalue {}
    ::foreach c $choices {
	lappend namevalue $c $c
    }
    return [select $name $param $namevalue $current]
}

# ::html::textarea --
#
#	Format a <textarea> element that retains the state of the
#	current CGI values.
#
# Arguments:
#	name		The form element name
#	param		The various size, multiple parameters for the tag
#	current		Value to assume if nothing is in CGI state
#
# Results:
#	The html fragment

proc ::html::textarea {name {param {}} {current {}}} {
    ::set value [quoteFormValue [ncgi::value $name $current]]
    return "<[string trimright \
	"textarea name=\"$name\"\
		[tagParam textarea $param]"]>$value</textarea>\n"
}

# ::html::submit --
#
#	Format a submit button.
#
# Arguments:
#	label		The string to appear in the submit button.
#	name		The name for the submit button element.
#	title		The string to appear on the submit button.
#			Optional. If not specified no title is shown.
#
# Results:
#	The html fragment

proc ::html::submit {label {name submit} {title {}}} {
    ::set html "<input type=\"submit\" name=\"$name\" value=\"$label\""
    ::if {$title != ""} { append html " title=\"$title\"" }
    append html ">\n"
}

# ::html::varEmpty --
#
#	Return true if the variable doesn't exist or is an empty string
#
# Arguments:
#	varname	Name of the variable
#
# Results:
#	1 if the variable doesn't exist or has the empty value

proc ::html::varEmpty {name} {
    upvar 1 $name var
    ::if {[info exists var]} {
	::set value $var
    } else {
	::set value ""
    }
    return [expr {[string length [string trim $value]] == 0}]
}

# ::html::getFormInfo --
#
#	Generate hidden fields to capture form values.
#
# Arguments:
#	args	List of elements to save.  If this is empty, everything is
#		saved in hidden fields.  This is a list of string match
#		patterns.
#
# Results:
#	A bunch of <input type=hidden> elements

proc ::html::getFormInfo {args} {
    ::if {[llength $args] == 0} {
	::set args *
    }
    ::set html ""
    ::foreach {n v} [ncgi::nvlist] {
	::foreach pat $args {
	    ::if {[string match $pat $n]} {
		append html "<input type=\"hidden\" name=\"$n\" \
				    value=\"[quoteFormValue $v]\">\n"
	    }
	}
    }
    return $html
}

# ::html::h1
#	Generate an H1 tag.
#
# Arguments:
#	string
#	param
#
# Results:
#	Formats the tag.

proc ::html::h1 {string {param {}}} {
    html::h 1 $string $param
}
proc ::html::h2 {string {param {}}} {
    html::h 2 $string $param
}
proc ::html::h3 {string {param {}}} {
    html::h 3 $string $param
}
proc ::html::h4 {string {param {}}} {
    html::h 4 $string $param
}
proc ::html::h5 {string {param {}}} {
    html::h 5 $string $param
}
proc ::html::h6 {string {param {}}} {
    html::h 6 $string $param
}
proc ::html::h {level string {param {}}} {
    return "<[string trimright "h$level [tagParam h$level $param]"]>$string</h$level>\n"
}

# ::html::wrapTag
#   Takes an optional text and wraps it in a tag pair, along with
#   optional attributes for the tag
#
# Arguments:
#   tag      The HTML tag name 
#   text     Optional text to insert between open/close tag
#   args     List of optional attributes and values to use for the tag
#
# Results:
#   String with the text wrapped in the open/close tag

proc ::html::wrapTag {tag {text ""} args} {
    ::set html ""
    ::set params ""
    ::foreach {i j} $args {
        append params "$i=\"[quoteFormValue $j]\" "
    }
    append html [openTag $tag [string trimright $params]]
    append html $text
    append html [closeTag]
    return $html
}

# ::html::openTag
#	Remember that a tag  is opened so it can be closed later.
#	This is used to automatically clean up at the end of a page.
#
# Arguments:
#	tag	The HTML tag name
#	param	Any parameters for the tag
#
# Results:
#	Formats the tag.  Also keeps it around in a per-page stack
#	of open tags.

proc ::html::openTag {tag {param {}}} {
    variable page
    lappend page(stack) $tag
    return "<[string trimright "$tag [tagParam $tag $param]"]>"
}

# ::html::closeTag
#	Pop a tag from the stack and close it.
#
# Arguments:
#	None
#
# Results:
#	A close tag.  Also pops the stack.

proc ::html::closeTag {} {
    variable page
    ::if {[info exists page(stack)]} {
	::set top [lindex $page(stack) end]
	::set page(stack) [lreplace $page(stack) end end]
    }
    ::if {[info exists top] && [string length $top]} {
	return </$top>
    } else {
	return ""
    }
}

# ::html::end
#
#	Close out all the open tags.  Especially useful for
#	Tables that do not display at all if they are unclosed.
#
# Arguments:
#	None
#
# Results:
#	Some number of close HTML tags.

proc ::html::end {} {
    variable page
    ::set html ""
    ::while {[llength $page(stack)]} {
	append html [closeTag]\n
    }
    return $html
}

# ::html::row
#
#	Format a table row.  If the default font has been set, this
#	takes care of wrapping the table cell contents in a font tag.
#
# Arguments:
#	args	Values to put into the row
#
# Results:
#	A <tr><td>...</tr> fragment

proc ::html::row {args} {
    ::set html <tr>\n
    ::foreach x $args {
	append html \t[cell "" $x td]\n
    }
    append html "</tr>\n"
    return $html
}

# ::html::hdrRow
#
#	Format a table row.  If the default font has been set, this
#	takes care of wrapping the table cell contents in a font tag.
#
# Arguments:
#	args	Values to put into the row
#
# Results:
#	A <tr><th>...</tr> fragment

proc ::html::hdrRow {args} {
    variable defaults
    ::set html <tr>\n
    ::foreach x $args {
	append html \t[cell "" $x th]\n
    }
    append html "</tr>\n"
    return $html
}

# ::html::paramRow
#
#	Format a table row.  If the default font has been set, this
#	takes care of wrapping the table cell contents in a font tag.
#
#       Based on html::row
#
# Arguments:
#	list	Values to put into the row
#       rparam   Parameters for row
#       cparam   Parameters for cells
#
# Results:
#	A <tr><td>...</tr> fragment

proc ::html::paramRow {list {rparam {}} {cparam {}}} {
    ::set html "<tr $rparam>\n"
    ::foreach x $list {
	append html \t[cell $cparam $x td]\n
    }
    append html "</tr>\n"
    return $html
}

# ::html::cell
#
#	Format a table cell.  If the default font has been set, this
#	takes care of wrapping the table cell contents in a font tag.
#
# Arguments:
#	param	Td tag parameters
#	value	The value to put into the cell
#	tag	(option) defaults to TD
#
# Results:
#	<td>...</td> fragment

proc ::html::cell {param value {tag td}} {
    ::set font [font]
    ::if {[string length $font]} {
	::set value $font$value</font>
    }
    return "<[string trimright "$tag $param"]>$value</$tag>"
}

# ::html::tableFromArray
#
#	Format a Tcl array into an HTML table
#
# Arguments:
#	arrname	The name of the array
#	param	The <table> tag parameters, if any.
#	pat	A string match pattern for the element keys
#
# Results:
#	A <table>

proc ::html::tableFromArray {arrname {param {}} {pat *}} {
    upvar 1 $arrname arr
    ::set html ""
    ::if {[info exists arr]} {
	append html "<table $param>\n"
	append html "<tr><th colspan=2>$arrname</th></tr>\n"
	::foreach name [lsort [array names arr $pat]] {
	    append html [row $name $arr($name)]
	}
	append html </table>\n
    }
    return $html
}

# ::html::tableFromList
#
#	Format a table from a name, value list
#
# Arguments:
#	querylist	A name, value list
#	param		The <table> tag parameters, if any.
#
# Results:
#	A <table>

proc ::html::tableFromList {querylist {param {}}} {
    ::set html ""
    ::if {[llength $querylist]} {
	append html "<table $param>"
	::foreach {label value} $querylist {
	    append html [row $label $value]
	}
	append html </table>
    }
    return $html
}

# ::html::mailto
#
#	Format a mailto: HREF tag
#
# Arguments:
#	email	The target
#	subject	The subject of the email, if any
#
# Results:
#	A <a href=mailto> tag </a>

proc ::html::mailto {email {subject {}}} {
    ::set html "<a href=\"mailto:$email"
    ::if {[string length $subject]} {
	append html ?subject=$subject
    }
    append html "\">$email</a>"
    return $html
}

# ::html::font
#
#	Generate a standard <font> tag.  This depends on defaults being
#	set via html::init
#
# Arguments:
#	args	Font parameters.
#
# Results:
#	HTML

proc ::html::font {args} {

    # e.g., font.face, font.size, font.color
    ::set param [tagParam font [join $args]]

    ::if {[string length $param]} {
	return "<[string trimright "font $param"]>"
    } else {
	return ""
    }
}

# ::html::minorMenu
#
#	Create a menu of links given a list of label, URL pairs.
#	If the URL is the current page, it is not highlighted.
#
# Arguments:
#
#	list	List that alternates label, url, label, url
#	sep	Separator between elements
#
# Results:
#	html

proc ::html::minorMenu {list {sep { | }}} {
    ::set s ""
    ::set html ""
    regsub -- {index.h?tml$} [ncgi::urlStub] {} this
    ::foreach {label url} $list {
	regsub -- {index.h?tml$} $url {} that
	::if {[string compare $this $that] == 0} {
	    append html "$s$label"
	} else {
	    append html "$s<a href=\"$url\">$label</a>"
	}
	::set s $sep
    }
    return $html
}

# ::html::minorList
#
#	Create a list of links given a list of label, URL pairs.
#	If the URL is the current page, it is not highlighted.
#
#       Based on html::minorMenu
#
# Arguments:
#
#	list	List that alternates label, url, label, url
#       ordered Boolean flag to choose between ordered and
#               unordered lists. Defaults to 0, i.e. unordered.
#
# Results:
#	A <ul><li><a...><\li>.....<\ul> fragment
#    or a <ol><li><a...><\li>.....<\ol> fragment

proc ::html::minorList {list {ordered 0}} {
    ::set s ""
    ::set html ""
    ::if { $ordered } {
	append html [openTag ol]
    } else {
	append html [openTag ul]
    }
    regsub -- {index.h?tml$} [ncgi::urlStub] {} this
    ::foreach {label url} $list {
	append html [openTag li]
	regsub -- {index.h?tml$} $url {} that
	::if {[string compare $this $that] == 0} {
	    append html "$s$label"
	} else {
	    append html "$s<a href=\"$url\">$label</a>"
	}
	append html [closeTag]
	append html \n
    }
    append html [closeTag]
    return $html
}

# ::html::extractParam
#
#	Extract a value from parameter list (this needs a re-do)
#
# Arguments:
#   param	A parameter list.  It should alredy have been processed to
#		remove any entity references
#   key		The parameter name
#   varName	The variable to put the value into (use key as default)
#
# Results:
#	returns "1" if the keyword is found, "0" otherwise

proc ::html::extractParam {param key {varName ""}} {
    ::if {$varName == ""} {
	upvar $key result
    } else {
	upvar $varName result
    }
    ::set ws " \t\n\r"

    # look for name=value combinations.  Either (') or (") are valid delimeters
    ::if {
      [regsub -nocase [format {.*%s[%s]*=[%s]*"([^"]*).*} $key $ws $ws] $param {\1} value] ||
      [regsub -nocase [format {.*%s[%s]*=[%s]*'([^']*).*} $key $ws $ws] $param {\1} value] ||
      [regsub -nocase [format {.*%s[%s]*=[%s]*([^%s]+).*} $key $ws $ws $ws] $param {\1} value] } {
        ::set result $value
        return 1
    }

    # now look for valueless names
    # I should strip out name=value pairs, so we don't end up with "name"
    # inside the "value" part of some other key word - some day

    ::set bad \[^a-zA-Z\]+
    ::if {[regexp -nocase  "$bad$key$bad" -$param-]} {
	return 1
    } else {
	return 0
    }
}

# ::html::urlParent --
#	This is like "file dirname", but doesn't screw with the slashes
#       (file dirname will collapse // into /)
#
# Arguments:
#	url	The URL
#
# Results:
#	The parent directory of the URL.

proc ::html::urlParent {url} {
    ::set url [string trimright $url /]
    regsub -- {[^/]+$} $url {} url
    return $url
}

# ::html::html_entities --
#	Replaces all special characters in the text with their
#	entities.
#
# Arguments:
#	s	The near-HTML text
#
# Results:
#	The text with entities in place of specials characters.

proc ::html::html_entities {s} {
    variable entities
    ::set text [string map $entities $s]
    ::if {[string is ascii $text]} {
        return $text
    }
    # Escape unicode characters
    ::set N [string length $text]
    ::set c 0
    ::set result {}
    ::for {::set x 0} {$x < $N} {::incr x} {
        ::set char [string index $text $x]
        ::set code [::scan $char %c]
        ::if {$code>255} {
            ::append result "&#$code\;"
        } else {
            ::append result $char
        }
    }
    return $result
}

# ::html::nl2br --
#	Replaces all line-endings in the text with <br> tags.
#
# Arguments:
#	s	The near-HTML text
#
# Results:
#	The text with <br> in place of line-endings.

proc ::html::nl2br {s} {
    return [string map [list \n\r <br> \r\n <br> \n <br> \r <br>] $s]
}

# ::html::doctype
#	Create the DOCTYPE tag and tuck it away for usage
#
# Arguments:
#	arg	The DOCTYPE you want to declare
#
# Results:
#	HTML for the doctype section

proc ::html::doctype {arg} {
    variable doctypes
    ::set code [string toupper $arg]
    ::if {![info exists doctypes($code)]} {
	return -code error -errorcode {HTML DOCTYPE BAD} \
	    "Unknown doctype \"$arg\""
    }
    return $doctypes($code)
}

namespace eval ::html {
    variable  doctypes
    array set doctypes {
	HTML32   {<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">}
	HTML40   {<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN" "http://www.w3.org/TR/REC-html40/strict.dtd">}
	HTML40T  {<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">}
	HTML40F  {<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Frameset//EN" "http://www.w3.org/TR/REC-html40/frameset.dtd">}
	HTML401  {<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">}
	HTML401T {<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">}
	HTML401F {<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">}
	XHTML10S {<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">}
	XHTML10T {<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">}
	XHTML10F {<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">}
	XHTML11  {<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">}
	XHTMLB   {<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.0//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic10.dtd">}
    }
}

# ::html::css
#	Create the text/css tag and tuck it away for usage
#
# Arguments:
#	href	The location of the css file to include the filename and path
#
# Results:
#	None.

proc ::html::css {href} {
    variable page
    lappend page(css) "<link rel=\"stylesheet\" type=\"text/css\" href=\"[quoteFormValue $href]\">"
    return
}

# ::html::css-clear
#	Drop all text/css references.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc ::html::css-clear {} {
    variable page
    catch { unset page(css) }
    return
}

# ::html::js
#   Create the text/javascript tag and tuck it away for usage
#
# Arguments:
#	href	The location of the javascript file to include the filename and path
#
# Results:
#	None.

proc ::html::js {href} {
    variable page
    lappend page(js) "<script language=\"javascript\" type=\"text/javascript\" src=\"[quoteFormValue $href]\"></script>"
    return
}

# ::html::js-clear
#	Drop all text/javascript references.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc ::html::js-clear {} {
    variable page
    catch { unset page(js) }
    return
}

