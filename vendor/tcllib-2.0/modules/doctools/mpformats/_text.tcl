# -*- tcl -*-
#
# -- Core support for text engines.
#
# Copyright (c) 2003-2019 Andreas Kupries <andreas_kupries@sourceforge.net>
# Freely redistributable.

################################################################

if {0} {
    catch {rename proc proc__} msg ; puts_stderr >>$msg
    proc__ proc {cmd argl body} {
	puts_stderr "proc $cmd $argl ..."
	uplevel [list proc__ $cmd $argl $body]
    }
}

dt_package textutil::string ; # for adjust
dt_package textutil::repeat
dt_package textutil::adjust

if {0} {
    puts_stderr ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    rename proc {}
    rename proc__ proc
    puts_stderr ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
}


proc parray_stderr {a {pattern *}} {
    upvar 1 $a array
    if {![array exists array]} {
        error "\"$a\" isn't an array"
    }
    set maxl 0
    foreach name [lsort [array names array $pattern]] {
        if {[string length $name] > $maxl} {
            set maxl [string length $name]
        }
    }
    set maxl [expr {$maxl + [string length $a] + 2}]
    foreach name [lsort [array names array $pattern]] {
        set nameString [format %s(%s) $a $name]
        puts_stderr "    [format "%-*s = {%s}" $maxl $nameString $array($name)]"
    }
}

# # ## ### ##### ########
##

dt_source _text_utils.tcl
# Formatting utilities

dt_source _text_margin.tcl
# RMargin, LMI

dt_source _text_state.tcl
# On, Off, IsOff

dt_source _text_para.tcl
# Text, Text?, TextClear, TextPlain (-> IsOff)

dt_source _text_cstack.tcl
# ContextReset, ContextPush, ContextPop (-> CAttrCurrent, ContextSet)

dt_source _text_ccore.tcl
# ContextSetup, ContextSet, ContextNew, ContextCommit, CAttrName, CAttrCurrent,
# CAttrRef, CAttrUnset, CAttrSet, CAttrAppend, CAttrIncr, CAttrGet, CAttrHas

dt_source _text_bullets.tcl
# DIB, IBullet (-> CAttrRef)
# DEB, EBullet (-> CAttrRef)

dt_source _text_dlist.tcl
# DListClear, Section, Subsection, CloseParagraph (-> Text?, TextClear, CAttrCurrent)
# PostProcess
# - SECT    (-> SectTitle)
# - SUBSECT (-> SubsectTitle)
# - PARA (-> TEXT context accessors)

# # ## ### ##### ########
##

proc TextInitialize {} {
    DListClear
    TextClear
    ContextReset
    Off
    ContextSetup
    
    # Root context
    ContextNew Base {
	MarginReset
	PrefixReset
	WPrefixReset
	VerbatimOff
	ListNone
	BulletReset
	ItemReset
	EnumReset
    }
    return
}

# # ## ### ##### ########
## `text` formatting

proc SectTitle {lb title} {
    upvar 1 $lb lines
    #lappend lines ""
    lappend lines $title
    lappend lines [RepeatM = $title]
    return
}

proc SubsectTitle {lb title} {
    upvar 1 $lb lines
    #lappend lines ""
    lappend lines $title
    lappend lines [RepeatM - $title]
    return
}

proc Strong {text} { SplitLine $text _Strong }
proc Em     {text} { SplitLine $text _Em }

proc _Strong {text} { return *${text}* }
proc _Em     {text} { return _${text}_ }

proc SplitLine {text cmd} {
    #puts_stderr AAA/SLI=[string map [list \1 \\1 \t \\t { } \\s] <<[join [split $text \n] >>\n<<]>>]
    if {![string match *\n* $text]} {
	foreach {lead content} [LeadSplit $text] break
	return ${lead}[uplevel 1 [list $cmd $content]]
    }
    set r {}   
    foreach line [split $text \n] {
	foreach {lead content} [LeadSplit $line] break
	if {$content == {}} {
	    lappend r {}
	    continue
	}
	lappend r ${lead}[uplevel 1 [list $cmd $content]]
    }
    set text [string trimright [join $r \n]]\n
    #puts_stderr AAA/SLE=[string map [list \1 \\1 \t \\t { } \\s] <<[join [split $text \n] >>\n<<]>>]
    return $text
}

proc LeadSplit {line} {
    regexp {^([ \t]*)(.*)([ \t]*)$} $line -> lead content _
    list $lead $content
}

# # ## ### ##### ########
## Bulleting
#
# itembullet  = index of the bullet to use in the next itemized list
# enumbullet  = index of the bullet to use in the next enumerated list

proc EnumReset {} { CAttrSet enumbullet 0 }
proc ItemReset {} { CAttrSet itembullet 0 }

# # ## ### ##### ########
##

proc text_plain_text  {text} { TextPlain   $text }
proc text_postprocess {text} { PostProcess $text }

#return

# Debugging
proc text_postprocess {text} {
    if {[set code [catch {
	PostProcess $text
    } res]]} {
	global errorInfo errorCode
	puts_stderr
	puts_stderr $errorCode
	puts_stderr $errorInfo
	return -code $code -errorinfo $errorInfo -errorcode $errorCode $msg
    }
    return $res
}
