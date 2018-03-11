# -*- tcl -*-
#
# -- nroff commands
#
# Copyright (c) 2003-2005 Andreas Kupries <andreas_kupries@sourceforge.net>


################################################################
# nroff specific commands
#
# All dot-commands (f.e. .PP) are returned with a leading \n\1,
# enforcing that they are on a new line and will be protected as markup.
# Any empty line created because of this is filtered out in the 
# post-processing step.


proc nr_lp      {}          {return \n\1.LP}
proc nr_ta      {{text {}}} {return "\1.ta$text"}
proc nr_bld     {}          {return \1\\fB}
proc nr_bldt    {t}         {return "\n\1.B $t\n"}
proc nr_ul      {}          {return \1\\fI}
proc nr_rst     {}          {return \1\\fR}
proc nr_p       {}          {return \n\1.PP\n}
proc nr_comment {text}      {return "\1'\1\\\" [join [split $text \n] "\n\1'\1\\\" "]"} ; # "
proc nr_enum    {num}       {nr_item " \[$num\]"}
proc nr_item    {{text {}}} {return "\n\1.IP$text"}
proc nr_vspace  {}          {return \n\1.sp\n}
proc nr_blt     {text}      {return "\n\1.TP\n$text"}
proc nr_bltn    {n text}    {return "\n\1.TP $n\n$text"}
proc nr_in      {}          {return \n\1.RS}
proc nr_out     {}          {return \n\1.RE}
proc nr_nofill  {}          {return \n\1.nf}
proc nr_fill    {}          {return \n\1.fi}
proc nr_title   {text}      {return "\n\1.TH $text"}
proc nr_include {file}      {return "\n\1.so $file"}
proc nr_bolds   {}          {return \n\1.BS}
proc nr_bolde   {}          {return \n\1.BE}
proc nr_read    {fn}        {return [nroffMarkup [dt_read $fn]]}
proc nr_cs      {}          {return \n\1.CS\n}
proc nr_ce      {}          {return \n\1.CE\n}

proc nr_section {name} {
    if {![regexp {[ 	]} $name]} {
	return "\n\1.SH [string toupper $name]"
    }
    return "\n\1.SH \"[string toupper $name]\""
}
proc nr_subsection {name}   {
    if {![regexp {[ 	]} $name]} {
	return "\n\1.SS [string toupper $name]"
    }
    return "\n\1.SS \"[string toupper $name]\""
}


################################################################

# Handling of nroff special characters in content:
#
# Plain text is initially passed through unescaped;
# internally-generated markup is protected by preceding it with \1.
# The final PostProcess step strips the escape character from
# real markup and replaces unadorned special characters in content
# with proper escapes.
#

global   markupMap
set      markupMap [list \
	"\\"   "\1\\" \
	"'"    "\1'" \
	"."    "\1." \
	"\\\\" "\\"]
global   finalMap
set      finalMap [list \
	"\1\\" "\\" \
	"\1'"  "'" \
	"\1."  "." \
        "."    "\\&." \
	"\\"   "\\\\"]
global   textMap
set      textMap [list "\\" "\\\\"]


proc nroffEscape {text} {
    global textMap
    return [string map $textMap $text]
}

# markup text --
#	Protect markup characters in $text.
#	These will be stripped out in PostProcess.
#
proc nroffMarkup {text} {
    global markupMap
    return [string map $markupMap $text]
}

proc nroff_postprocess {nroff} {
    global finalMap

    # Postprocessing final nroff text.
    # - Strip empty lines out of the text
    # - Remove leading and trailing whitespace from lines.
    # - Exceptions to the above: Keep empty lines and leading
    #   whitespace when in verbatim sections (no-fill-mode)

    set nfMode   [list \1.nf \1.CS]	; # commands which start no-fill mode
    set fiMode   [list \1.fi \1.CE]	; # commands which terminate no-fill mode
    set lines    [list]         ; # Result buffer
    set verbatim 0              ; # Automaton mode/state

    foreach line [split $nroff "\n"] {
	#puts_stderr |[expr {$verbatim ? "VERB" : "    "}]|$line|

	if {!$verbatim} {
	    # Normal lines, not in no-fill mode.

	    if {[lsearch -exact $nfMode [split $line]] >= 0} {
		# no-fill mode starts after this line.
		set verbatim 1
	    }

	    # Ensure that empty lines are not added.
	    # This also removes leading and trailing whitespace.

	    if {![string length $line]} {continue}
	    set line [string trim $line]
	    if {![string length $line]} {continue}

	    if {[regexp {^\x1\\f[BI]\.} $line]} {
		# We found confusing formatting at the beginning of
		# the current line. We lift this line up and attach it
		# at the end of the last line to remove this
		# irregularity. Note that the regexp has to look for
		# the special 0x01 character as well to be sure that
		# the sequence in question truly is formatting.
		# [bug-3601370] Only lift & attach if last line is not
		# a directive

		set last  [lindex   $lines end]
		if { ! [string match "\1.*" $last] } {
		    #puts_stderr \tLIFT
		    set lines [lreplace $lines end end]
		    set line "$last $line"
		}
	    } elseif {[string match {[']*} $line]} {
		# Apostrophes at the beginning of a line have to be
		# quoted to prevent misinterpretation as comments.
		# The true comments and are quoted with \1 already and
		# will therefore not detected by the code here.
		# puts_stderr \tQUOTE
		set line \1\\$line
	    } ; # We are not handling dots at the beginning of a line here.
	    #   # We are handling them in the finalMap which will quote _all_
	    #   # dots in a text with a zero-width escape (\&).
	} else {
	    # No-fill mode. We remove trailing whitespace, but keep
	    # leading whitespace and empty lines.

	    if {[lsearch -exact $fiMode [split $line]] >= 0} {
		# Normal mode resumes after this line.
		set verbatim 0
	    }
	    set line [string trimright $line]
	}
	lappend lines $line
    }

    set lines [join $lines "\n"]

    # Now remove all superfluous .IP commands (empty paragraphs). The
    # first identity mapping is present to avoid smashing a man macro
    # definition.

    lappend map	\n\1.IP\n\1.\1.\n  \n\1.IP\n\1.\1.\n
    lappend map \n\1.IP\n\1.       \n\1.

    set lines [string map $map $lines]

    # Return the modified result buffer
    return [string map $finalMap $lines]
}

