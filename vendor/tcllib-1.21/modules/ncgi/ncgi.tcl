# ncgi.tcl
#
# Basic support for CGI programs
#
# Copyright (c) 2000 Ajuba Solutions.
# Copyright (c) 2012 Richard Hipp, Andreas Kupries
# Copyright (c) 2013-2014 Andreas Kupries
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.


# Please note that Don Libes' has a "cgi.tcl" that implements version 1.0
# of the cgi package.  That implementation provides a bunch of cgi_ procedures
# (it doesn't use the ::cgi:: namespace) and has a wealth of procedures for
# generating HTML.  In contract, the package provided here is primarly
# concerned with processing input to CGI programs.  I have tried to mirror his
# API's where possible.  So, ncgi::input is equivalent to cgi_input, and so
# on.  There are also some different APIs for accessing values (ncgi::list,
# ncgi::parse and ncgi::value come to mind)

# Note, I use the term "query data" to refer to the data that is passed in
# to a CGI program.  Typically this comes from a Form in an HTML browser.
# The query data is composed of names and values, and the names can be
# repeated.  The names and values are encoded, and this module takes care
# of decoding them.

# We use newer string routines
package require Tcl 8.4
package require fileutil ; # Required by importFile.
package require uri

package provide ncgi 1.4.4

namespace eval ::ncgi {

    # "query" holds the raw query (i.e., form) data
    # This is treated as a cache, too, so you can call ncgi::query more than
    # once

    variable query

    # This is the content-type which affects how the query is parsed

    variable contenttype

    # value is an array of parsed query data.  Each array element is a list
    # of values, and the array index is the form element name.
    # See the differences among ncgi::parse, ncgi::input, ncgi::value
    # and ncgi::valuelist for the various approaches to handling these values.

    variable value

    # This lists the names that appear in the query data

    variable varlist

    # This holds the URL coresponding to the current request
    # This does not include the server name.

    variable urlStub

    # This flags compatibility with Don Libes cgi.tcl when dealing with
    # form values that appear more than once.  This bit gets flipped when
    # you use the ncgi::input procedure to parse inputs.

    variable listRestrict 0

    # This is the set of cookies that are pending for output

    variable cookieOutput

    # Support for x-www-urlencoded character mapping
    # The spec says: "non-alphanumeric characters are replaced by '%HH'"
 
    variable i
    variable c
    variable map

    for {set i 1} {$i <= 256} {incr i} {
	set c [format %c $i]
	if {![string match \[a-zA-Z0-9\] $c]} {
	    set map($c) %[format %.2X $i]
	}
    }
     
    # These are handled specially
    array set map {
	" " +   \n %0D%0A
    }

    # Map of transient files

    variable  _tmpfiles
    array set _tmpfiles {}

    # I don't like importing, but this makes everything show up in 
    # pkgIndex.tcl

    namespace export reset urlStub query type decode encode
    namespace export nvlist parse input value valueList names
    namespace export setValue setValueList setDefaultValue setDefaultValueList
    namespace export empty import importAll importFile redirect header
    namespace export parseMimeValue multipart cookie setCookie
}

# ::ncgi::reset
#
#	This resets the state of the CGI input processor.  This is primarily
#	used for tests, although it is also designed so that TclHttpd can
#	call this with the current query data
#	so the ncgi package can be shared among TclHttpd and CGI scripts.
#
#	DO NOT CALL this in a standard cgi environment if you have not
#	yet processed the query data, which will not be used after a
#	call to ncgi::reset is made.  Instead, just call ncgi::parse
#
# Arguments:
#	newquery	The query data to be used instead of external CGI.
#	newtype		The raw content type.
#
# Side Effects:
#	Resets the cached query data and wipes any environment variables
#	associated with CGI inputs (like QUERY_STRING)

proc ::ncgi::reset {args} {
    global env
    variable _tmpfiles
    variable query
    variable contenttype
    variable cookieOutput

    # array unset _tmpfiles -- Not a Tcl 8.2 idiom
    unset _tmpfiles ; array set _tmpfiles {}

    set cookieOutput {}
    if {[llength $args] == 0} {

	# We use and test args here so we can detect the
	# difference between empty query data and a full reset.

	if {[info exists query]} {
	    unset query
	}
	if {[info exists contenttype]} {
	    unset contenttype
	}
    } else {
	set query [lindex $args 0]
	set contenttype [lindex $args 1]
    }
}

# ::ncgi::urlStub
#
#	Set or return the URL associated with the current page.
#	This is for use by TclHttpd to override the default value
#	that otherwise comes from the CGI environment
#
# Arguments:
#	url	(option) The url of the page, not counting the server name.
#		If not specified, the current urlStub is returned
#
# Side Effects:
#	May affects future calls to ncgi::urlStub

proc ::ncgi::urlStub {{url {}}} {
    global   env
    variable urlStub
    if {[string length $url]} {
	set urlStub $url
	return ""
    } elseif {[info exists urlStub]} {
	return $urlStub
    } elseif {[info exists env(SCRIPT_NAME)]} {
	set urlStub $env(SCRIPT_NAME)
	return $urlStub
    } else {
	return ""
    }
}

# ::ncgi::query
#
#	This reads the query data from the appropriate location, which depends
#	on if it is a POST or GET request.
#
# Arguments:
#	none
#
# Results:
#	The raw query data.

proc ::ncgi::query {} {
    global env
    variable query

    if {[info exists query]} {
	# This ensures you can call ncgi::query more than once,
	# and that you can use it with ncgi::reset
	return $query
    }

    set query ""
    if {[info exists env(REQUEST_METHOD)]} {
	if {$env(REQUEST_METHOD) == "GET"} {
	    if {[info exists env(QUERY_STRING)]} {
		set query $env(QUERY_STRING)
	    }
	} elseif {$env(REQUEST_METHOD) == "POST"} {
	    if {[info exists env(CONTENT_LENGTH)] &&
		    [string length $env(CONTENT_LENGTH)] != 0} {
 		## added by Steve Cassidy to try to fix binary file upload
 		fconfigure stdin -translation binary -encoding binary
		set query [read stdin $env(CONTENT_LENGTH)]
	    }
	}
    }
    return $query
}

# ::ncgi::type
#
#	This returns the content type of the query data.
#
# Arguments:
#	none
#
# Results:
#	The content type of the query data.

proc ::ncgi::type {} {
    global env
    variable contenttype

    if {![info exists contenttype]} {
	if {[info exists env(CONTENT_TYPE)]} {
	    set contenttype $env(CONTENT_TYPE)
	} else {
	    return ""
	}
    }
    return $contenttype
}

# ::ncgi::decode
#
#	This decodes data in www-url-encoded format.
#
# Arguments:
#	An encoded value
#
# Results:
#	The decoded value

if {[package vsatisfies [package present Tcl] 8.6]} {
    # 8.6+, use 'binary decode hex'
    proc ::ncgi::DecodeHex {hex} {
	return [binary decode hex $hex]
    }
} else {
    # 8.4+. More complex way of handling the hex conversion.
    proc ::ncgi::DecodeHex {hex} {
	return [binary format H* $hex]
    }
}

proc ::ncgi::decode {str} {
    # rewrite "+" back to space
    # protect \ from quoting another '\'
    set str [string map [list + { } "\\" "\\\\" \[ \\\[ \] \\\]] $str]

    # prepare to process all %-escapes
    regsub -all -nocase -- {%([E][A-F0-9])%([89AB][A-F0-9])%([89AB][A-F0-9])} \
	$str {[encoding convertfrom utf-8 [DecodeHex \1\2\3]]} str
    regsub -all -nocase -- {%([CDcd][A-F0-9])%([89AB][A-F0-9])} \
	$str {[encoding convertfrom utf-8 [DecodeHex \1\2]]} str
    regsub -all -nocase -- {%([A-F0-9][A-F0-9])} $str {\\u00\1} str

    # process \u unicode mapped chars
    return [subst -novar $str]
}

# ::ncgi::encode
#
#	This encodes data in www-url-encoded format.
#
# Arguments:
#	A string
#
# Results:
#	The encoded value

proc ::ncgi::encode {string} {
    variable map

    # 1 leave alphanumerics characters alone
    # 2 Convert every other character to an array lookup
    # 3 Escape constructs that are "special" to the tcl parser
    # 4 "subst" the result, doing all the array substitutions

    regsub -all -- \[^a-zA-Z0-9\] $string {$map(&)} string
    # This quotes cases like $map([) or $map($) => $map(\[) ...
    regsub -all -- {[][{})\\]\)} $string {\\&} string
    return [subst -nocommand $string]
}

# ::ncgi::names
#
#	This parses the query data and returns a list of the names found therein.
#
# 	Note: If you use ncgi::setValue or ncgi::setDefaultValue, this
#	names procedure doesn't see the effect of that.
#
# Arguments:
#	none
#
# Results:
#	A list of names

proc ::ncgi::names {} {
    array set names {}
    foreach {name val} [nvlist] {
        if {![string equal $name "anonymous"]} {
            set names($name) 1
        }
    }
    return [array names names]
}

# ::ncgi::nvlist
#
#	This parses the query data and returns it as a name, value list
#
# 	Note: If you use ncgi::setValue or ncgi::setDefaultValue, this
#	nvlist procedure doesn't see the effect of that.
#
# Arguments:
#	none
#
# Results:
#	An alternating list of names and values

proc ::ncgi::nvlist {} {
    set query [query]
    set type  [type]
    switch -glob -- $type {
	"" -
	text/xml* -
	application/x-www-form-urlencoded* -
	application/x-www-urlencoded* {
	    set result {}

	    # Any whitespace at the beginning or end of urlencoded data is not
	    # considered to be part of that data, so we trim it off.  One special
	    # case in which post data is preceded by a \n occurs when posting
	    # with HTTPS in Netscape.

	    foreach {x} [split [string trim $query] &] {
		# Turns out you might not get an = sign,
		# especially with <isindex> forms.

		set pos [string first = $x]
		set len [string length $x]

		if { $pos>=0 } {
		    if { $pos == 0 } { # if the = is at the beginning ...
		        if { $len>1 } { 
                            # ... and there is something to the right ...
		            set varname anonymous
		            set val [string range $x 1 end]
		        } else { 
                            # ... otherwise, all we have is an =
		            set varname anonymous
		            set val ""
		        }
		    } elseif { $pos==[expr {$len-1}] } { 
                        # if the = is at the end ...
		        set varname [string range $x 0 [expr {$pos-1}]]
			set val ""
		    } else {
		        set varname [string range $x 0 [expr {$pos-1}]]
		        set val [string range $x [expr {$pos+1}] end]
		    }
		} else { # no = was found ...
		    set varname anonymous
		    set val $x
		}		
		lappend result [decode $varname] [decode $val]
	    }
	    return $result
	}
	multipart/* {
	    return [multipart $type $query]
	}
	default {
	    return -code error "Unknown Content-Type: $type"
	}
    }
}

# ::ncgi::parse
#
#	The parses the query data and stores it into an array for later retrieval.
#	You should use the ncgi::value or ncgi::valueList procedures to get those
#	values, or you are allowed to access the ncgi::value array directly.
#
#	Note - all values have a level of list structure associated with them
#	to allow for multiple values for a given form element (e.g., a checkbox)
#
# Arguments:
#	none
#
# Results:
#	A list of names of the query values

proc ::ncgi::parse {} {
    variable value
    variable listRestrict 0
    variable varlist {}
    if {[info exists value]} {
	unset value
    }
    foreach {name val} [nvlist] {
	if {![info exists value($name)]} {
	    lappend varlist $name
	}
	lappend value($name) $val
    }
    return $varlist
} 

# ::ncgi::input
#
#	Like ncgi::parse, but with Don Libes cgi.tcl semantics.
#	Form elements must have a trailing "List" in their name to be
#	listified, otherwise this raises errors if an element appears twice.
#
# Arguments:
#	fakeinput	See ncgi::reset
#	fakecookie	The raw cookie string to use when testing.
#
# Results:
#	The list of element names in the form

proc ::ncgi::input {{fakeinput {}} {fakecookie {}}} {
    variable value
    variable varlist {}
    variable listRestrict 1
    if {[info exists value]} {
	unset value
    }
    if {[string length $fakeinput]} {
	ncgi::reset $fakeinput
    }
    foreach {name val} [nvlist] {
	set exists [info exists value($name)]
	if {!$exists} {
	    lappend varlist $name
	}
	if {[string match "*List" $name]} {
	    # Accumulate a list of values for this name
	    lappend value($name) $val
	} elseif {$exists} {
	    error "Multiple definitions of $name encountered in input.\
	    If you're trying to do this intentionally (such as with select),\
	    the variable must have a \"List\" suffix."
	} else {
	    # Capture value with no list structure
	    set value($name) $val
	}
    }
    return $varlist
} 

# ::ncgi::value
#
#	Return the value of a named query element, or the empty string if
#	it was not not specified.  This only returns the first value of
#	associated with the name.  If you want them all (like all values
#	of a checkbox), use ncgi::valueList
#
# Arguments:
#	key	The name of the query element
#	default	The value to return if the value is not present
#
# Results:
#	The first value of the named element, or the default

proc ::ncgi::value {key {default {}}} {
    variable value
    variable listRestrict
    variable contenttype
    if {[info exists value($key)]} {
	if {$listRestrict} {

	    # ::ncgi::input was called, and it already figured out if the
	    # user wants list structure or not.

	    set val $value($key)
	} else {

	    # Undo the level of list structure done by ncgi::parse

	    set val [lindex $value($key) 0]
	}
	if {[string match multipart/* [type]]} {

	    # Drop the meta-data information associated with each part

	    set val [lindex $val 1]
	}
	return $val
    } else {
	return $default
    }
}

# ::ncgi::valueList
#
#	Return all the values of a named query element as a list, or
#	the empty list if it was not not specified.  This always returns
#	lists - if you do not want the extra level of listification, use
#	ncgi::value instead.
#
# Arguments:
#	key	The name of the query element
#
# Results:
#	The first value of the named element, or ""

proc ::ncgi::valueList {key {default {}}} {
    variable value
    if {[info exists value($key)]} {
	return $value($key)
    } else {
	return $default
    }
}

# ::ncgi::setValue
#
#	Jam a new value into the CGI environment.  This is handy for preliminary
#	processing that does data validation and cleanup.
#
# Arguments:
#	key	The name of the query element
#	value	This is a single value, and this procedure wraps it up in a list
#		for compatibility with the ncgi::value array usage.  If you
#		want a list of values, use ngci::setValueList
#		
#
# Side Effects:
#	Alters the ncgi::value and possibly the ncgi::valueList variables

proc ::ncgi::setValue {key value} {
    variable listRestrict
    if {$listRestrict} {
	ncgi::setValueList $key $value
    } else {
	ncgi::setValueList $key [list $value]
    }
}

# ::ncgi::setValueList
#
#	Jam a list of new values into the CGI environment.
#
# Arguments:
#	key		The name of the query element
#	valuelist	This is a list of values, e.g., for checkbox or multiple
#			selections sets.
#		
# Side Effects:
#	Alters the ncgi::value and possibly the ncgi::valueList variables

proc ::ncgi::setValueList {key valuelist} {
    variable value
    variable varlist
    if {![info exists value($key)]} {
	lappend varlist $key
    }

    # This if statement is a workaround for another hack in
    # ::ncgi::value that treats multipart form data
    # differently.
    if {[string match multipart/* [type]]} {
	set value($key) [list [list {} [join $valuelist]]]
    } else {
	set value($key) $valuelist
    }
    return ""
}

# ::ncgi::setDefaultValue
#
#	Set a new value into the CGI environment if there is not already one there.
#
# Arguments:
#	key	The name of the query element
#	value	This is a single value, and this procedure wraps it up in a list
#		for compatibility with the ncgi::value array usage.
#		
#
# Side Effects:
#	Alters the ncgi::value and possibly the ncgi::valueList variables

proc ::ncgi::setDefaultValue {key value} {
    ncgi::setDefaultValueList $key [list $value]
}

# ::ncgi::setDefaultValueList
#
#	Jam a list of new values into the CGI environment if the CGI value
#	is not already defined.
#
# Arguments:
#	key		The name of the query element
#	valuelist	This is a list of values, e.g., for checkbox or multiple
#			selections sets.
#		
# Side Effects:
#	Alters the ncgi::value and possibly the ncgi::valueList variables

proc ::ncgi::setDefaultValueList {key valuelist} {
    variable value
    if {![info exists value($key)]} {
	ncgi::setValueList $key $valuelist
	return ""
    } else {
	return ""
    }
}

# ::ncgi::exists --
#
#	Return false if the CGI variable doesn't exist.
#
# Arguments:
#	name	Name of the CGI variable
#
# Results:
#	0 if the variable doesn't exist

proc ::ncgi::exists {var} {
    variable value
    return [info exists value($var)]
}

# ::ncgi::empty --
#
#	Return true if the CGI variable doesn't exist or is an empty string
#
# Arguments:
#	name	Name of the CGI variable
#
# Results:
#	1 if the variable doesn't exist or has the empty value

proc ::ncgi::empty {name} {
    return [expr {[string length [string trim [value $name]]] == 0}]
}

# ::ncgi::import
#
#	Map a CGI input into a Tcl variable.  This creates a Tcl variable in
#	the callers scope that has the value of the CGI input.  An alternate
#	name for the Tcl variable can be specified.
#
# Arguments:
#	cginame		The name of the form element
#	tclname		If present, an alternate name for the Tcl variable,
#			otherwise it is the same as the form element name

proc ::ncgi::import {cginame {tclname {}}} {
    if {[string length $tclname]} {
	upvar 1 $tclname var
    } else {
	upvar 1 $cginame var
    }
    set var [value $cginame]
}

# ::ncgi::importAll
#
#	Map a CGI input into a Tcl variable.  This creates a Tcl variable in
#	the callers scope for every CGI value, or just for those named values.
#
# Arguments:
#	args	A list of form element names.  If this is empty,
#		then all form value are imported.

proc ::ncgi::importAll {args} {
    variable varlist
    if {[llength $args] == 0} {
	set args $varlist
    }
    foreach cginame $args {
	upvar 1 $cginame var
	set var [value $cginame]
    }
}

# ::ncgi::redirect
#
#	Generate a redirect by returning a header that has a Location: field.
#	If the URL is not absolute, this automatically qualifies it to
#	the current server
#
# Arguments:
#	url		The url to which to redirect
#
# Side Effects:
#	Outputs a redirect header

proc ::ncgi::redirect {url} {
    global env

    if {![regexp -- {^[^:]+://} $url]} {

	# The url is relative (no protocol/server spec in it), so
	# here we create a canonical URL.

	# request_uri	The current URL used when dealing with relative URLs.  
	# proto		http or https
	# server 	The server, which we are careful to match with the
	#		current one in base Basic Authentication is being used.
	# port		This is set if it is not the default port.

	if {[info exists env(REQUEST_URI)]} {
	    # Not all servers have the leading protocol spec
	    #regsub -- {^https?://[^/]*/} $env(REQUEST_URI) / request_uri
	    array set u [uri::split $env(REQUEST_URI)]
	    set request_uri /$u(path)
	    unset u
	} elseif {[info exists env(SCRIPT_NAME)]} {
	    set request_uri $env(SCRIPT_NAME)
	} else {
	    set request_uri /
	}

	set port ""
	if {[info exists env(HTTPS)] && $env(HTTPS) == "on"} {
	    set proto https
	    if {$env(SERVER_PORT) != 443} {
		set port :$env(SERVER_PORT)
	    }
	} else {
	    set proto http
	    if {$env(SERVER_PORT) != 80} {
		set port :$env(SERVER_PORT)
	    }
	}
	# Pick the server from REQUEST_URI so it matches the current
	# URL.  Otherwise use SERVER_NAME.  These could be different, e.g.,
	# "pop.scriptics.com" vs. "pop"

	if {[info exists env(REQUEST_URI)]} {
	    # Not all servers have the leading protocol spec
	    if {![regexp -- {^https?://([^/:]*)} $env(REQUEST_URI) x server]} {
		set server $env(SERVER_NAME)
	    }
	} else {
	    set server $env(SERVER_NAME)
	}
	if {[string match /* $url]} {
	    set url $proto://$server$port$url
	} else {
	    regexp -- {^(.*/)[^/]*$} $request_uri match dirname
	    set url $proto://$server$port$dirname$url
	}
    }
    ncgi::header text/html Location $url
    puts "Please go to <a href=\"$url\">$url</a>"
}

# ncgi:header
#
#	Output the Content-Type header.
#
# Arguments:
#	type	The MIME content type
#	args	Additional name, value pairs to specifiy output headers
#
# Side Effects:
#	Outputs a normal header

proc ::ncgi::header {{type text/html} args} {
    variable cookieOutput
    puts "Content-Type: $type"
    foreach {n v} $args {
	puts "$n: $v"
    }
    if {[info exists cookieOutput]} {
	foreach line $cookieOutput {
	    puts "Set-Cookie: $line"
	}
    }
    puts ""
    flush stdout
}

# ::ncgi::parseMimeValue
#
#	Parse a MIME header value, which has the form
#	value; param=value; param2="value2"; param3='value3'
#
# Arguments:
#	value	The mime header value.  This does not include the mime
#		header field name, but everything after it.
#
# Results:
#	A two-element list, the first is the primary value,
#	the second is in turn a name-value list corresponding to the
#	parameters.  Given the above example, the return value is
#	{
#		value
#		{param value param2 value2 param3 value3}
#	}

proc ::ncgi::parseMimeValue {value} {
    set parts [split $value \;]
    set results [list [string trim [lindex $parts 0]]]
    set paramList [list]
    foreach sub [lrange $parts 1 end] {
	if {[regexp -- {([^=]+)=(.+)} $sub match key val]} {
            set key [string trim [string tolower $key]]
            set val [string trim $val]
            # Allow single as well as double quotes
            if {[regexp -- {^(['"])(.*)\1} $val x quote val2]} { ; # need a " for balance
               # Trim quotes and any extra crap after close quote
               # remove quoted quotation marks
               set val [string map {\\" "\"" \\' "\'"} $val2]
            }
            lappend paramList $key $val
	}
    }
    if {[llength $paramList]} {
	lappend results $paramList
    }
    return $results
}

# ::ncgi::multipart
#
#	This parses multipart form data.
#	Based on work by Steve Ball for TclHttpd, but re-written to use
#	string first with an offset to iterate through the data instead
#	of using a regsub/subst combo.
#
# Arguments:
#	type	The Content-Type, because we need boundary options
#	query	The raw multipart query data
#
# Results:
#	An alternating list of names and values
#	In this case, the value is a two element list:
#		headers, which in turn is a list names and values
#		content, which is the main value of the element
#	The header name/value pairs come primarily from the MIME headers
#	like Content-Type that appear in each part.  However, the
#	Content-Disposition header is handled specially.  It has several
#	parameters like "name" and "filename" that are important, so they
#	are promoted to to the same level as Content-Type.  Otherwise,
#	if a header like Content-Type has parameters, they appear as a list
#	after the primary value of the header.  For example, if the
#	part has these two headers:
#
#	Content-Disposition: form-data; name="Foo"; filename="/a/b/C.txt"
#	Content-Type: text/html; charset="iso-8859-1"; mumble='extra'
#	
#	Then the header list will have this structure:
#	{
#		content-disposition form-data
#		name Foo
#		filename /a/b/C.txt
#		content-type {text/html {charset iso-8859-1 mumble extra}}
#	}
#	Note that the header names are mapped to all lowercase.  You can
#	use "array set" on the header list to easily find things like the
#	filename or content-type.  You should always use [lindex $value 0]
#	to account for values that have parameters, like the content-type
#	example above.  Finally, not that if the value has a second element,
#	which are the parameters, you can "array set" that as well.
#	
proc ::ncgi::multipart {type query} {

    set parsedType [parseMimeValue $type]
    if {![string match multipart/* [lindex $parsedType 0]]} {
	return -code error "Not a multipart Content-Type: [lindex $parsedType 0]"
    }
    array set options [lindex $parsedType 1]
    if {![info exists options(boundary)]} {
	return -code error "No boundary given for multipart document"
    }
    set boundary $options(boundary)

    # The query data is typically read in binary mode, which preserves
    # the \r\n sequence from a Windows-based browser.
    # Also, binary data may contain \r\n sequences.

    if {[string match "*$boundary\r\n*" $query]} {
        set lineDelim "\r\n"
	#	puts "DELIM"
    } else {
        set lineDelim "\n"
	#	puts "NO"
    }

    # Iterate over the boundary string and chop into parts

    set len [string length $query]
    # [string length $lineDelim]+2 is for "$lineDelim--"
    set blen [expr {[string length $lineDelim] + 2 + \
            [string length $boundary]}]
    set first 1
    set results [list]
    set offset 0

    # Ensuring the query data starts
    # with a newline makes the string first test simpler
    if {[string first $lineDelim $query 0]!=0} {
        set query $lineDelim$query
    }
    while {[set offset [string first $lineDelim--$boundary $query $offset]] \
            >= 0} {
	if {!$first} {
	    lappend results $formName [list $headers \
		[string range $query $off2 [expr {$offset -1}]]]
	} else {
	    set first 0
	}
	incr offset $blen

	# Check for the ending boundary, which is signaled by --$boundary--

	if {[string equal "--" \
		[string range $query $offset [expr {$offset + 1}]]]} {
	    break
	}

	# Split headers out from content
	# The headers become a nested list structure:
	#	{header-name {
	#		value {
	#			paramname paramvalue ... }
	#		}
	#	}

        set off2 [string first "$lineDelim$lineDelim" $query $offset]
	set headers [list]
	set formName ""
        foreach line [split [string range $query $offset $off2] $lineDelim] {
	    if {[regexp -- {([^:	 ]+):(.*)$} $line x hdrname value]} {
		set hdrname [string tolower $hdrname]
		set valueList [parseMimeValue $value]
		if {[string equal $hdrname "content-disposition"]} {

		    # Promote Conent-Disposition parameters up to headers,
		    # and look for the "name" that identifies the form element

		    lappend headers $hdrname [lindex $valueList 0]
		    foreach {n v} [lindex $valueList 1] {
			lappend headers $n $v
			if {[string equal $n "name"]} {
			    set formName $v
			}
		    }
		} else {
		    lappend headers $hdrname $valueList
		}
	    }
	}

	if {$off2 > 0} {
            # +[string length "$lineDelim$lineDelim"] for the
            # $lineDelim$lineDelim
            incr off2 [string length "$lineDelim$lineDelim"]
	    set offset $off2
	} else {
	    break
	}
    }
    return $results
}

# ::ncgi::importFile --
#
#   get information about a file upload field
#
# Arguments:
#   cmd         one of '-server' '-client' '-type' '-data'
#   var         cgi variable name for the file field
#   filename    filename to write to for -server
# Results:
#   -server returns the name of the file on the server: side effect
#      is that the file gets stored on the server and the 
#      script is responsible for deleting/moving the file
#   -client returns the name of the file sent from the client 
#   -type   returns the mime type of the file
#   -data   returns the contents of the file 

proc ::ncgi::importFile {cmd var {filename {}}} {

    set vlist [valueList $var]

    array set fileinfo [lindex [lindex $vlist 0] 0]
    set contents [lindex [lindex $vlist 0] 1]

    switch -exact -- $cmd {
	-server {
	    ## take care not to write it out more than once
	    variable _tmpfiles
	    if {![info exists _tmpfiles($var)]} {
		if {$filename != {}} {
		    ## use supplied filename 
		    set _tmpfiles($var) $filename
		} else {
		    ## create a tmp file 
		    set _tmpfiles($var) [::fileutil::tempfile ncgi]
		}

		# write out the data only if it's not been done already
		if {[catch {open $_tmpfiles($var) w} h]} {
		    error "Can't open temporary file in ncgi::importFile ($h)"
		} 

		fconfigure $h -translation binary -encoding binary
		puts -nonewline $h $contents 
		close $h
	    }
	    return $_tmpfiles($var)
	}
	-client {
	    if {![info exists fileinfo(filename)]} {return {}}
	    return $fileinfo(filename)
	}
	-type {
	    if {![info exists fileinfo(content-type)]} {return {}}
	    return $fileinfo(content-type)
	}
	-data {
	    return $contents
	}
	default {
	    error "Unknown subcommand to ncgi::import_file: $cmd"
	}
    }
}


# ::ncgi::cookie
#
#	Return a *list* of cookie values, if present, else ""
#	It is possible for multiple cookies with the same key
#	to be present, so we return a list.
#
# Arguments:
#	cookie	The name of the cookie (the key)
#
# Results:
#	A list of values for the cookie

proc ::ncgi::cookie {cookie} {
    global env
    set result ""
    if {[info exists env(HTTP_COOKIE)]} {
	foreach pair [split $env(HTTP_COOKIE) \;] {
	    foreach {key value} [split [string trim $pair] =] { break ;# lassign }
	    if {[string compare $cookie $key] == 0} {
		lappend result $value
	    }
	}
    }
    return $result
}

# ::ncgi::setCookie
#
#	Set a return cookie.  You must call this before you call
#	ncgi::header or ncgi::redirect
#
# Arguments:
#	args	Name value pairs, where the names are:
#		-name	Cookie name
#		-value	Cookie value
#		-path	Path restriction
#		-domain	domain restriction
#		-expires	Time restriction
#
# Side Effects:
#	Formats and stores the Set-Cookie header for the reply.

proc ::ncgi::setCookie {args} {
    variable cookieOutput
    array set opt $args
    set line "$opt(-name)=$opt(-value) ;"
    foreach extra {path domain} {
	if {[info exists opt(-$extra)]} {
	    append line " $extra=$opt(-$extra) ;"
	}
    }
    if {[info exists opt(-expires)]} {
	switch -glob -- $opt(-expires) {
	    *GMT {
		set expires $opt(-expires)
	    }
	    default {
		set expires [clock format [clock scan $opt(-expires)] \
			-format "%A, %d-%b-%Y %H:%M:%S GMT" -gmt 1]
	    }
	}
	append line " expires=$expires ;"
    }
    if {[info exists opt(-secure)]} {
	append line " secure "
    }
    lappend cookieOutput $line
}
