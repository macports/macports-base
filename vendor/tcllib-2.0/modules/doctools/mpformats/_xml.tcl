# -*- tcl -*-
# [expand] utilities for generating XML.
#
# Copyright (C) 2001 Joe English <jenglish@sourceforge.net>.
# Freely redistributable.
#
# Copyright (C) 2019 Andreas Kupries <andreas_kupries@sourceforge.net>
######################################################################

# Handling XML delimiters in content:
#
# Plain text is initially passed through unescaped;
# internally-generated markup is protected by preceding it with \1.
# The final PostProcess step strips the escape character from
# real markup and replaces markup characters from content
# with entity references.
#

variable attvalMap { {&} &amp;  {<} &lt;  {>} &gt; {"} &quot; {'} &apos; } ; # "
variable markupMap { {&} {\1&}  {<} {\1<}  {>} {\1>} }
variable finalMap  { {\1&} {&}  {\1<} {<}  {\1>} {>}
		     {&} &amp;  {<} &lt;   {>} &gt; }

proc fmt_postprocess {text} {
    variable finalMap
    return [string trim [string map $finalMap $text]]\n
}

# markup text --
#	Protect markup characters in $text with \1.
#	These will be stripped out in PostProcess.
#
proc markup {text} {
    variable markupMap
    return [string map $markupMap $text]
}

# attlist { n1 v1 n2 v2 ... } --
#	Return XML-formatted attribute list.
#	Does *not* escape markup -- the result must be passed through
#	[markup] before returning it to the expander.
#
proc attlist {nvpairs} {
    variable attvalMap
    if {[llength $nvpairs] == 1} { set nvpairs [lindex $nvpairs 0] }
    set attlist ""
    foreach {name value} $nvpairs {
    	append attlist " $name='[string map $attvalMap $value]'"
    }
    return $attlist
}

# startTag gi ?attname attval ... ? --
#	Return start-tag for element $gi with specified attributes.
#
proc startTag {gi args} {
    return [markup "<$gi[attlist $args]>"]
}

# endTag gi --
#	Return end-tag for element $gi.
#
proc endTag {gi} {
    return [markup "</$gi>"]
}

# emptyElement gi ?attribute  value ... ?
#	Return empty-element tag.
#
proc emptyElement {gi args} {
    return [markup "<$gi[attlist $args]/>"]
}

# xmlComment text --
#	Return XML comment declaration containing $text.
#	NB: if $text includes the sequence "--", it will be mangled.
#
proc xmlComment {text} {
    return [markup "<!-- [string map {-- { - - }} $text] -->"]
}

# wrap content gi --
#	Returns $content wrapped inside <$gi> ... </$gi> tags.
#
proc wrap {content gi} {
    return "[startTag $gi]${content}[endTag $gi]"
}

# wrap? content gi --
#	Same as [wrap], but returns an empty string if $content is empty.
#
proc wrap? {content gi} {
    if {![string length [string trim $content]]} { return "" }
    return "[startTag $gi]${content}[endTag $gi]"
}

# wrapLines? content gi ? gi... ?
#	Same as [wrap?], but separates entries with newlines
#       and supports multiple nesting levels.
#
proc wrapLines? {content args} {
    if {![string length $content]} { return "" }
    foreach gi $args {
	set content [join [list [startTag $gi] $content [endTag $gi]] "\n"]
    }
    return $content
}

# sequence args --
#	Handy combinator.
#
proc sequence {args} { join $args "\n" }

######################################################################
# XML context management.
#

variable elementStack [list]

# start gi ?attribute value ... ? --
#	Return start-tag for element $gi
#	As a side-effect, pushes $gi onto the element stack.
#
proc start {gi args} {
    if {[llength $args] == 1} { set args [lindex $args 0] }
    variable elementStack
    lappend elementStack $gi
    return [startTag $gi $args]
}

# xmlContext {gi1 ... giN} ?default?  --
#	Pops elements off the element stack until one of
#	the specified element types is found.
#
#	Returns: sequence of end-tags for each element popped.
#
#	If none of the specified elements are found, returns
# 	a start-tag for $default.
#
proc xmlContext {gis {default {}}} {
    variable elementStack
    set origStack $elementStack
    set endTags [list]
    while {[llength $elementStack]} {
	set current [lindex $elementStack end]
	if {[lsearch $gis $current] >= 0} {
	    return [join $endTags \n]
	}
	lappend endTags [endTag $current]
	set elementStack [lreplace $elementStack end end]
    }
    # Not found:
    set elementStack $origStack
    if {![string length $default]} {
    	set where "[join $elementStack /] - [info level 1]"
	puts_stderr "Warning: Cannot start context $gis ($where)"
    	set default [lindex $gis 0] 
    }
    lappend elementStack $default
    return [startTag $default]
}

# end ? gi ? --
#	Generate markup to close element $gi, including end-tags
#	for any elements above it on the element stack.
#
#	If element name is omitted, closes the current element.
#
proc end {{gi {}}} {
    variable elementStack
    if {![string length $gi]} {
    	set gi [lindex $elementStack end]
    }
    set prefix [xmlContext $gi]
    set elementStack [lreplace $elementStack end end]
    return [join [list $prefix [endTag $gi]] "\n"]
}

######################################################################
# Utilities for multi-pass processing.
#
# Not really XML-related, but I find them handy.
#

variable PassProcs
variable Buffers

# pass $passNo procName procArgs { body  } --
#	Specifies procedure definition for pass $n.
#
proc pass {pass proc arguments body} {
    variable PassProcs
    lappend PassProcs($pass) $proc $arguments $body
}

proc setPassProcs {pass} {
    variable PassProcs
    foreach {proc args body} $PassProcs($pass) {
	proc $proc $args $body
    }
}

# holdBuffers buffer ? buffer ...? --
#	Declare a list of hold buffers,
#	to collect data in one pass and output it later.
#
proc holdBuffers {args} {
    variable Buffers
    foreach arg $args {
	set Buffers($arg) [list]
    }
}

# hold buffer text --
#	Append text to named buffer
#
proc hold {buffer entry} {
    variable Buffers
    lappend Buffers($buffer) $entry
    return
}

# held buffer --
#	Returns current contents of named buffer and empty the buffer.
#
proc held {buffer} {
    variable Buffers
    set content [join $Buffers($buffer) "\n"]
    set Buffers($buffer) [list]
    return $content
}

#*EOF*
