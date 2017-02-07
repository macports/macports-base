# text_write.tcl --
#
#	Commands for the generation of TEXT
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: text_write.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require textutil::adjust

namespace eval ::text::write {
    namespace export \
	reset clear field fieldl fieldr /line prefix indent \
	store recall undef undo get getl maxlen fieldsep \
	push pop pop-append copy move clear-block exists


    namespace ensemble create
}

# ### ### ### ######### ######### #########
## API.

proc ::text::write::reset {} {
    # Reset state, fully (clear line and block buffers, , stack, set
    # the default field separator, and flush the named blocks)
    variable currentline    {}
    variable currentblock   {}
    variable stack          {}
    variable fieldseparator { }
    variable blocks
    array unset blocks *
    return
}

proc ::text::write::clear {} {
    # Reset state (clear line and block buffers, stack, and set the
    # default field separator)
    variable currentline    {}
    variable currentblock   {}
    variable stack          {}
    variable fieldseparator { }
    return
}

proc ::text::write::field {args} {
    # Extend line buffer, at end.
    variable currentline
    lappend  currentline {*}$args
    return
}

proc ::text::write::fieldl {fieldlength text} {
    # As field, but a text left-aligned in a field of given length.
    field [format %-${fieldlength}s $text]
    return
}

proc ::text::write::fieldr {fieldlength text} {
    # As field, but a text right-aligned in a field of given length.
    field [format %${fieldlength}s $text]
    return
}

proc ::text::write::fieldsep {char} {
    # Set field separator for '/line'
    variable fieldseparator $char
    return
}

proc ::text::write::get {} {
    # Return text of current block.
    variable currentblock
    set res $currentblock
    reset
    return [join $res \n]
}

proc ::text::write::getl {} {
    # As get, but retrieve the raw list of lines.
    variable currentblock
    set res $currentblock
    reset
    return $res
}

proc ::text::write::/line {} {
    # Commit current line to current block (added at end)
    variable currentline
    variable currentblock
    variable fieldseparator
    lappend  currentblock [string trimright [join $currentline $fieldseparator]]
    set      currentline {}
    return
}

proc ::text::write::undo {} {
    # Remove last line from current block.
    variable currentblock
    set      currentblock [lreplace $currentblock end end]
    return
}

proc ::text::write::prefix {prefix {n 0}} {
    # Indent current block using the prefix text, skipping the first n lines
    variable currentblock
    set currentblock \
	[split \
	     [textutil::adjust::indent \
		  [join $currentblock \n] \
		  $prefix $n] \
	     \n]
    return
}

proc ::text::write::indent {k {n 0}} {
    # Indent current block by k spaces, skipping the first n lines
    variable currentblock
    set currentblock \
	[split \
	     [textutil::adjust::indent \
		  [join $currentblock \n] \
		  [string repeat { } $k] $n] \
	     \n]
    return
}


proc ::text::write::store {name} {
    # Save current block and under a name. /store
    variable currentblock
    variable blocks
    set blocks($name) $currentblock
    return
}

proc ::text::write::recall {name} {
    # Append named block to current block. /recall
    variable currentblock
    variable blocks
    lappend currentblock {*}$blocks($name)
    return
}

proc ::text::write::undef {name} {
    # Remove the specified block from memory
    variable blocks
    unset    blocks($name)
    return
}

proc ::text::write::exists {name} {
    # Remove the specified block from memory
    variable blocks
    return [info exists blocks($name)]
}

proc ::text::write::copy {src dst} {
    # Copy named block to other named block, overwriting it.
    variable blocks
    set blocks($dst) $blocks($src)
    return
}

proc ::text::write::clear-block {name} {
    # Clear the named block.
    variable blocks
    set blocks($name) ""
    return
}

proc ::text::write::move {src dst} {
    # Move named block to other named block, overwriting it.
    variable blocks
    set   blocks($dst) $blocks($src)
    unset blocks($src)
    return
}

proc ::text::write::push {} {
    # Suspend current block.
    variable currentblock
    variable stack
    lappend stack $currentblock
    return
}

proc ::text::write::pop {} {
    # Recall the last suspended block, replace current block.
    variable currentblock
    variable stack
    set currentblock [lindex $stack end]
    set stack [lrange $stack 0 end-1]
    return
}

proc ::text::write::pop-append {} {
    # Recall the last suspended block, add to the current block.
    variable currentblock
    variable stack
    lappend currentblock {*}[lindex $stack end]
    set stack [lrange $stack 0 end-1]
    return
}

proc ::text::write::maxlen {list} {
    # Find the max length of the strings in the list.

    set lengths 0 ; # This will be the max if the list is empty, and
		    # prevents the mathfunc from throwing errors for
		    # that case.

    foreach str $list {
	lappend lengths [::string length $str]
    }

    return [tcl::mathfunc::max {*}$lengths]
}

# ### ### ### ######### ######### #########
## Internals.

# ### ### ### ######### ######### #########

namespace eval ::text::write {
    # State of the writer.

    variable currentline    {}  ; # List of text fragments which make
				  # up the current line.
    variable currentblock   {}  ; # List of lines which make up the
				  # current block.
    variable  blocks            ; # Set of named blocks.
    array set blocks        {}  ; #
    variable fieldseparator { } ; # Current field separator.
    variable stack          {}  ; # Stack of suspended blocks.
}

# ### ### ### ######### ######### #########
## Ready

package provide text::write 1
return
