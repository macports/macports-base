# rtcore.tcl --
#
#	Runtime core for file type recognition engines written in pure Tcl.
#
# Copyright (c) 2004-2005 Colin McCormack <coldstore@users.sourceforge.net>
# Copyright (c) 2005      Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Copyright (c) 2016-2018 Poor Yorick     <tk.tcl.core.tcllib@pooryorick.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: rtcore.tcl,v 1.5 2005/09/28 04:51:19 andreas_kupries Exp $

#####
#
# "mime type recognition in pure tcl"
# http://wiki.tcl.tk/12526
#
# Tcl code harvested on:  10 Feb 2005, 04:06 GMT
# Wiki page last updated: ???
#
#####

# TODO
#    Required Functionality
#	implement full offset language}
#	    done
#
#	    by pooryorick
#
#	    time {2016 06}
#
#
#	implement pstring (pascal string)
#	    done
#
#	    by pooryorick
#
#	    time {2016 06}
#}
#
#	implement regex form
#	    done
#
#	    by pooryorick
#
#	    time {2016 06}
#
#
#	implement string qualifiers
#	    done
#	    
#	    by pooryorick
#
#	    time {2016 06}
#
#	implement correct handling of date types
#
#	finish implementing the indirect type} 
#	    done
#
#	    by pooryorick
#
#	    2018 08
#
#	Maybe distinguish between binary and text tests, like file(n)
#
#	    done
#
#	    by pooryorick
#
#	    2018 08
#	
#	process and use strength directives
#
#	    done
#
#	    by pooryorick
#
#	    2018 08
#
#	handle the "indirect" type
#
#	    done
#
#	    by pooryorick
#
#	    2018 08
#
#
#    }
#}




# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.5




# ### ### ### ######### ######### #########
## Implementation

namespace eval ::fileutil::magic::rt {
    # Configuration flag. (De)activate debugging output.
    # This is done during initialization.
    # Changes at runtime have no effect.

    variable debug 0

    # The maximum size of a substring to inspect from the file in question 
    variable maxstring 64

    # The maximum length of any %s substitution in a resulting description is
    variable maxpstring 64

    variable regexdefaultlen 4096

    # [*] The vast majority of magic strings are in the first 4k of the file.

    # Export APIs (full public, recognizer public)
    namespace export file_start result
    namespace export emit ext mime new offset strength \
	D Nv N O S Nvx Nx Sx L R T I U < >

    namespace eval _ {}

}




# ### ### ### ######### ######### #########
## Public API, general use.


proc ::fileutil::magic::rt::> {} {
    upvar #1 cursors cursors depth depth found found \
	level level lfound lfound strengths strengths \
	typematch typematch useful useful virtual virtual
    set prevlevel $level
    incr level
    incr depth
    set cursors($level) $cursors($prevlevel)
    set strengths($level) 0
    set useful($level) 0
    set virtual($level) $virtual($prevlevel)
    set found 0
    dict set lfound $level 0
    return
}


proc ::fileutil::magic::rt::< {} {
    upvar #1 class class ext ext found found level level mime mime \
	result result strengths strengths typematch typematch useful useful

    if {$level == 1 && [llength $result]} {
	set leveln $level
	set weight 0
	while {$leveln >= 0} {
	    set weight [
		expr {$weight + $useful($leveln) + $strengths($leveln) + $typematch($leveln)}]
	    incr leveln -1
	}

	foreach item $result[set result {}] {
	    set item [lmap {-> x ->} [regexp -all -inline \
		{(.+?)([[:punct:]][[:space:]]+|[:,+]*$)} $item[set item {}]] {

		regsub {"(.*)"} $x {\1} x
		regsub {'(.*)'} $x {\1} x
		regsub {\((.*)\)} $x {\1} x
		regsub {\{(.*)\}} $x {\1} x
		regsub {<(.*)>} $x {\1} x
		regsub {\[(.*)\]} $x {\1} x
		regsub {[[:space:]][[:space:]]+} $x { } x

		string trim $x
	    }]
	    lappend result {*}$item
	}

	yield [list $weight $result $mime $ext]
	set result {}
    }

    # $useful holds weight of the match at each level, Each weight is
    # basically length of the match.
    set useful($level) 0
    set strengths($level) 0

    incr level -1

    if {$level == 0} {
	set ext {}
	set found 0
	set mime {}
	set depth 0
    }
}


proc ::fileutil::magic::rt::classify {data} {
    set bin_rx {[\x00-\x08\x0b\x0e-\x1f]}
    if {[regexp $bin_rx $data] } {
        return binary
    } else {
        return text
    }
}

proc ::fileutil::magic::rt::executable {} {
    upvar #1 finfo finfo
    if {![dict exists $finfo mode]} {
	return 0
    }
    expr {([dict get $finfo mode] & 0o111) > 0} 
}


proc ::fileutil::magic::rt::ext value {
    upvar #1 ext ext
    set ext [split $value /]
}


# mark the start of a magic file in debugging
proc ::fileutil::magic::rt::file_start {name} {
    ::fileutil::magic::rt::Debug {puts stderr "File: $name"}
}


proc ::fileutil::magic::rt::message msg {
    upvar #1 finfo finfo
    set ranges [regexp -all -inline -indices {\$\{([^\}]*)\}} $msg]
    foreach {orange irange} $ranges {
	lassign $irange first last
	set sub [string range $msg $first $last] 

	if {[regexp {^x\?([^:]*?):(.*)$} $sub -> tmsg fmsg]} {
	    set part [expr {[executable] ? $tmsg : $fmsg}]
	    set msg [string replace $msg[set line {}] {*}$orange $part]
	} else {
	    parseerror error [list {unrecognized variable in description}] 
	}
    }
    return $msg
}


proc ::fileutil::magic::rt::mime value {
    upvar #1 mime mime
    set mime [split [message $value] /]
}


proc ::fileutil::magic::rt::new {finfo chan named tests} {
    coroutine _::[info cmdcount] [list [
	namespace which coro]] $finfo $chan $named $tests
}

# level #1 of a coroutine
proc ::fileutil::magic::rt::coro {finfo chan named tests} {
    array set cache {}	    ; # Cache of fetched and decoded numeric
			    ; # values.

    ::fconfigure $chan -translation binary

    # fill the string cache
    set strbuf [::read $chan 4096]  ; # Input cache [*].
    set class [classify $strbuf]    ; # text or binary

    # clear the fetch cache
    catch {unset cache}
    array set cache {}

    set depth 0		; # depth of the current branch
    set ext {}
    set extracted {}    ; # The value extracted for inspection
    set found 1		; # Whether the last test produced a match
    set level 0
    set lfound {}	; # For each level, whether a match was found
    dict set lfound 0 1
    set mime {}
    set result {}	; # The accumulated recognition result that is
			; # in progress.

    array unset cursors	; # the offset just after the last matching bytes,
			; # per nesting level.

    array unset strengths ; #strengths at each level

    set virtual(0) 0	; # the virtual start of the file at each level

    set strengths(0) 0
    set typematch(0) 0

    yield [info coroutine]
    yield $class

    if {[string length $strbuf] == 0} {
	yield [list 0 empty {} {}]
    } else {
	{*}$tests
    }
    rename [info coroutine] {}
    return -code break
}

proc ::fileutil::magic::rt::strength {expr} {
    upvar #1 level level strengths strengths
    upvar 0 strengths($level) strength
    # this expr must not be braced
    set strength [expr double($strength) $expr]
}

proc ::fileutil::magic::rt::use {named file name} {
    if [dict exists $named $file $name] {
	set script [dict get $named $file $name]
    } else {
	dict for {file1 val} $named {
	    if {[dict exists $val $name]} {
		set script [dict get $val $name]
		break
	    }
	}
    }
    if {![info exists script]} {
	return -code error [list {name not found} $file $name]
    }
    return $script
}



# ### ### ### ######### ######### #########
## Public API, for use by a recognizer.


# emit a description 
proc ::fileutil::magic::rt::emit msg {
    upvar #1 extracted extracted found found level level lfound lfound \
	result result
    variable maxpstring
    set found 1
    dict set lfound $level 1

    #set map [list \
    #    \\b "" \
    #    %c [apply {extracted {
    #        if {[catch {format %c $extracted} result]} {
    #    	return {}
    #        }
    #        return $result

    #    }} $extracted] \
    #    %s  [string trim [string range $extracted 0 $maxpstring]] \
    #    %ld $extracted \
    #    %d  $extracted \
    #]
    #[::string map $map $msg]

    # {to do} {Is only taking up to the first newline really a good general rule?}
    regexp {\A[^\n\r]*} $extracted extracted2

    regsub -all {\s+} $extracted2 { } extracted2

    set arguments {}
    set count [expr {[string length $msg] - [string length [
	string map {% {}} $msg]]}]
    for {set i 0} {$i < $count} {incr i} {
	lappend arguments $extracted2
    }
    catch {set msg [format $msg {*}$arguments]}

    # Assumption: [regexp] leaves $msg untouched if it fails
    regexp {\A(\b|\\b)?(.*)$} $msg match b msg

    set msg [message $msg[set msg {}]]

    if {$b ne {} && [llength $result]} {
	lset result end [lindex $result end]$msg
    } else {
	lappend result $msg
    }
    return
}

proc ::fileutil::magic::rt::D offset {
    upvar #1 found found
    expr {!$found}
}

proc ::fileutil::magic::rt::I {offset it ioi ioo iir io} {
    # Handling of base locations specified indirectly through the
    # contents of the inspected file.
    upvar #1 level level
    variable typemap
    foreach {size scan} $typemap($it) break

    set offset [Fetch $offset $size $scan]

    if {[catch {expr {$offset + 0}}]} {
	return [expr {-1 * 2 ** 128}]
    }

    if {$ioi && ![catch {$offset + 0}]} {
	set offset [expr {~$offset}]
    }

    if {$iir} {
	set io [Fetch [expr {$offset + $io}] $size $scan]
    }

    if {$ioo ne {}} {
	# no bracing this expression
	set offset [expr $offset $ioo $io]
    }
    return $offset
}


proc ::fileutil::magic::rt::L newlevel {
    upvar #1 level level
    set level $newlevel
    # Regenerate level information in the calling context.
    return
}


# Numeric - get bytes of $type at $offset and $compare to $val
# qual might be a mask
proc ::fileutil::magic::rt::N {
    type offset testinvert compinvert mod mand comp val} {

    upvar #1 class class cursors cursors extracted extracted level level \
	typematch typematch useful useful
    variable typemap

    # unpack the type characteristics
    foreach {size scan} $typemap($type) break

    # fetch the numeric field
    set extracted [Fetch $offset $size $scan]
    if {$extracted eq {}} {

	# Rules like the following, from the jpeg file, imply that
	# in the absence of an extracted value, a numerical value of 
	# 0 should be used

	# From jpeg:
	    ## Next, show thumbnail info, if it exists:
	    #>>18    byte        !0      \b, thumbnail %dx
	#
	# pyk 2018-08-16:
	#    Not necessarily.  The failure to extract might cause the rule to
	#    be skipped.  Consider doing something different here.
	set extracted 0
    }

    # Would moving this before the fetch be an optimisation ? The
    # tradeoff is that we give up filling the cache, and it is unclear
    # how often that value would be used. -- Profile!
    if {$comp eq {x}} {
	set useful($level) 0
	# anything matches - don't care
	if {$testinvert} {
	    return 0
	} else {
	    return 1
	}
    }

    if {$compinvert && $extracted ne {}} {
	set extracted [expr -$extracted]
    }

    # perform comparison
    if {$mod ne {}} {
	# there's a mask to be applied
	set extracted [expr $extracted $mod $mand]
    }
    switch $comp {
	& {
	    set c [expr {($extracted & $val) == $val}]
	}
	^ {
	    set c [expr {($extracted & ~$val) == $extracted}]
	}
	== - != - < - > {
	    set c [expr $extracted $comp $val]
	}
	default {
	    #Should never reach this
	    return -code error [list {unknown comparison operator} $comp]
	}
    }
    # Do this last to minimize shimmering
    set useful($level) [string length $extracted]

    if {$class eq {binary}} {
	set typematch($level)  1
    } else {
	set typematch($level)  0
    }

    ::fileutil::magic::rt::Debug {
	puts stderr "numeric $type: $val $t$comp $extracted / $mod - $c"
    }
    if {$testinvert} {
	set c [expr {!$c}]
	return $c 
    } else {
	return $c
    }
}


proc ::fileutil::magic::rt::Nv {type offset compinvert mod mand} {
    upvar #1 class class cursors cursors extracted extracted level level \
	offsets offsets useful useful
    variable typemap

    set offsets($level) $offset

    # unpack the type characteristics
    foreach {size scan} $typemap($type) break

    # fetch the numeric field from the file
    set extracted [Fetch $offset $size $scan]

    if {$compinvert && $extracted ne {}} {
	set extracted [expr ~$extracted]
    }
    if {$mod ne {} && $extracted ne {}} {
	# there's a mask to be applied
	set extracted [expr $extracted $mod $mand]
    }

    if {$class eq {binary}} {
	set typematch($level)  1
    } else {
	set typematch($level)  0
    }

    ::fileutil::magic::rt::Debug {puts stderr "NV $type $offset $mod: $extracted"}
    set useful($level) [string length $extracted]
    return $extracted
}


proc ::fileutil::magic::rt::O offset {
    # Handling of offset locations specified relative to the offset
    # last field one level up.
    upvar #1 offsets offsets level level
    upvar 0 offsets([expr {$level -1}]) base
    return [expr {$base + $offset}]
}


proc ::fileutil::magic::rt::R offset {
    # Handling of offset locations specified relative to the cursor one level
    # up.
    upvar #1 cursors cursors level level
    upvar 0 cursors([expr {$level -1}]) cursor
    return [expr {$cursor + $offset}]
}


proc ::fileutil::magic::rt::S {type offset testinvert mod mand comp val} {
    upvar #1 cursors cursors extracted extracted level level \
	lfound lfound useful useful
    variable maxstring
    variable regexdefaultlen

    upvar 0 cursors($level) cursor useful($level) used
    set cursor $offset

    # $compinvert is currently ignored for strings

    switch $type {
	pstring {
	    set ptype B
	    set vincluded 0
	    # The last pstring type specifier wins 
	    foreach item $mod {
		if {$item eq {J}} {
		    set vincluded 1
		} else {
		    set ptype $item
		}
	    }
	    lassign [dict get {B {b 1} H {S 2} h {s 2} L {I 4} l {i 4}} $ptype] scan slength
	    set length [GetString $offset $slength]
	    incr offset $slength
	    incr cursor $slength
	    set scanu ${scan}u
	    if {[binary scan $length $scanu length2]} {
		if {$vincluded} {
		    set length2 [expr {$length2 - $slength}]
		}
		set extracted [GetString $offset $length2]
		incr cursor [string length $extracted]
		    array get cursors]]
		set c [Smatch $val $comp $extracted $mod]
	    } else {
		set c 0
	    }
	}
	regex {
	    if {$mand eq {}} {
		set mand $regexdefaultlen 
	    }
	    set extracted [GetString $offset $mand]
	    if {[regexp -indices $val $extracted match indices]} {
		incr cursor [lindex $indices 1]
		set used [string length $match]
	        set c 1
	    } else {
	        set c 0
	    }
	}
	search {
	    set limit $mand
	    set extracted [GetString $offset $limit]
	    if {[set offset2 [string first $val $extracted]] >= 0} {
		set cursor [expr {$offset + $offset2 + [string length $val]}]
		set used [string length $val]
		set c 1
	    } else {
		set c 0
	    }
	} default {
	    # explicit "default" type, which is intended only to be used with
	    # the "x" pattern
	    set c [expr {[dict exists $lfound $level] ? ![dict get $lfound $level] : 1}]
	} default {
	    # get the string and compare it
	    switch $type bestring16 - lestring16 {
		set extracted [GetString $offset [
		    expr {2 * [string length $val]}]]
		switch $type bestring16 {
		    binary scan $extracted Su* extracted
		} lestring16 {
		    binary scan $extracted su* extracted
		}

		foreach ordinal $extracted[set extracted {}] {
		    append extracted [format %c $ordinal]
		}

	    } default {
		# If $val is 0, give [emit] something to work with .
		if {$val eq  "\0"} {
		    set extracted [GetString $offset $maxstring]
		} else {
		    set extracted [GetString $offset [string length $val]]
		}
	    }
	    incr cursor [string length $extracted]
	    set c [Smatch $val $comp $extracted $mod]
	}
    }


    ::fileutil::magic::rt::Debug {
	puts "String '$val' $comp '$extracted' - $c"
	if {$c} {
	    puts "offset $offset - $extracted"
	}
    }
    if {$testinvert} {
	return [expr {!$c}]
    } else {
	return $c
    }
}


proc ::fileutil::magic::rt::Smatch {val op string mod} {
    upvar #1 class class level level typematch typematch useful useful 
    if {$op eq {x}} {
	set useful($level) 0
	return 1
    }

    if {![string length $string] && $op in {eq == < <=}} {
	if {$op in {eq == < <=}} {
	    # Nothing matches an empty $string.
	    return 0
	}
	return 1
    }

    if {$op eq {>} && [string length $val] > [string length $string]} {
	return 1
    }

    # To preserve the semantics, the w operation must occur prior to the W
    # operation (Assuming the interpretation that w makes all whitespace
    # optional, relaxing the requirements of W) .
    if {{w} in $mod} {
	regsub -all {\s} $string[set string {}] {} string
	regsub -all {\s} $val[set val {}] {} val
    }

    if {{W} in $mod} {
	set blanklen [::tcl::mathfunc::max 0 {*}[
	    lmap {_unused_ blanks} [regexp -all -indices -inline {(\s+)} $val] {
	    expr {[lindex $blanks 1] - [lindex $blanks 0]}
	}]]
	if {![regexp "\s{$blanklen}" $string]} {
	    ::fileutil::magic::rt::Debug {
		puts "String '$val' $op '$string' - $c"
		if {$c} {
		    puts "offset $offset - $string"
		}
	    }
	    return 0
	}

	regsub -all {\s+} $string[set string {}] { } string
	regsub -all {\s+} $val[set val {}] { } val
    }


    if {{T} in $mod} {
	set string [string trim $string[set string {}]]
	set val [string tolower $val[set val {}]]
    }

    if {$class eq {binary} || {b} in $mod} {
	set typematch($level)  0
    } else {
	set typematch($level)  1
    }

    set string [string range $string  0 [string length $val]-1]

    # The remaining code may assume that $string and $val have the same length
    # .

    set opnum [dict get {< -1 == 0 eq 0 != 0 ne 0 > 1} $op]

    if {{c} in $mod || {C} in $mod} {
	set res 1
	if {{c} in $mod && {C} in $mod} {
	    set string [string tolower $string[set string {}]]
	    set val [string tolower $val[set val {}]]
	} elseif {{c} in $mod} {
	    foreach sc [split $string] vc [split $val] {
		if {[string is lower $sc]} {
		    set vc [string tolower $vc]
		}
		if {[::string compare $val $string] != $opnum} {
		    set res 0
		    break
		}
	    }
	} elseif {{C} in $mode} {
	    foreach vc [split $val] sc [split $string]  {
		if {[string is upper $vc]} {
		    set sc [string toupper $sc]
		}
		if {[::string compare $val $string] != $opnum} {
		    set res 0
		    break
		}
	    }
	}
    } else {
	set res [expr {[::string compare $string $val] == $opnum}]
    }
    if {$op in {!= ne}} {
	set res [expr {!$res}]
    }
    # use the extracted value here, not val, because in the case of
    # inequalities the extra information has weight
    set useful($level) [string length $string]
    return $res
}


proc ::fileutil::magic::rt::T {offset mod} {
    upvar #1 cursors cursors level level offsets offsets tests tests \
	virtual virtual
    if {{r} in $mod} {
	set offset [expr {$cursors($level) + $offset}]
    }
    set newvirtual [expr {$virtual($level) + $offset}]
    >
	set virtual($level) $newvirtual
	{*}$tests
    <
}


proc ::fileutil::magic::rt::U {file name offset} {
    upvar #1 level level named named offsets offsets
    set script [use $named $file $name]
    set offsets($level) $offset
    >
	::try $script
    <
}



# ### ### ### ######### ######### #########
## Internal. Retrieval of the data used in comparisons.


# fetch and cache a numeric value from the file
proc ::fileutil::magic::rt::Fetch {where what scan} {
    upvar #1 cache cache chan chan cursors cursors extracted extracted \
	level level offsets offsets strbuf strbuf virtual virtual

    set where [expr {$virtual($level) + $where}]
    set offsets($level) $where 

    # A negative offset means that an attempt to extract an indirect offset failed
    if {$where < 0} {
	return {}
    }
    # {to do} id3 length
    if {[info exists cache($where,$what,$scan)]} {
	lassign $cache($where,$what,$scan) extracted cursor
    } else {
	::seek $chan $where
	set data [::read $chan $what]
	set cursor [expr {$where + [string length $data]}]
	set extracted [rtscan $data $scan]
	set cache($where,$what,$scan) [list $extracted $cursor]

	# Optimization: If we got 4 bytes, i.e. long we implicitly
	# know the short and byte data as well. Should put them into
	# the cache. -- Profile: How often does such an overlap truly
	# happen ?
    }
    set cursors($level) $cursor 
    return $extracted
}


proc ::fileutil::magic::rt::GetString {offset len} {
    upvar #1 chan chan level level strbuf strbuf offsets offsets \
	virtual virtual
    # We have the first 1k of the file cached

    set offsets($level) $offset
    set offset [expr {$virtual($level) + $offset}]
    set end [expr {$offset + $len - 1}]
    if {$end < [string length $strbuf]} {
        # in the string cache, copy the requested part.
	try {
	    set string [::string range $strbuf $offset $end]
	} on error {tres topts} {
	    lassign [dict get $topts -errorcode] TCL VALUE INDEX
	    if {$TCL eq {TCL} && $VALUE eq {VALUE} && $INDEX eq {INDEX}} {
		set string {}
	    } else {
		return -options $topts $tres
	    }
	}
    } else {
	# an unusual one, move to the offset and read directly from
	# the file.
	::seek $chan $offset
	try {
	    # maybe offset is out of bounds
	    set string [::read $chan $len]
	} on error {tres topts} {
	    lassign [dict get $topts -errorcode] TCL VALUE INDEX
	    if {$TCL eq {TCL} && $VALUE eq {VALUE} && $INDEX eq {INDEX}} {
		set string {}
	    } else {
		return -options $topts $tres
	    }
	}
    }
    return $string
}


proc ::fileutil::magic::rt::me4 data {
	binary scan $data a4 chars
	set data [binary format a4 [lindex $chars 1] [
	lindex $chars 0] [lindex $chars 3] [lindex $chars 2]]
}


proc ::fileutil::magic::rt::rtscan {data scan} {
    if {$scan eq {me}} {
	set data [me4 $data]
	set scan I 
    }
    set numeric {}
    binary scan $data $scan numeric
    return $numeric
}



# ### ### ### ######### ######### #########
## Internal, debugging.

if {!$::fileutil::magic::rt::debug} {
    # This procedure definition is optimized out of using code by the
    # core bcc. It knows that neither argument checks are required,
    # nor is anything done. So neither results, nor errors are
    # possible, a true no-operation.
    proc ::fileutil::magic::rt::Debug {args} {}

} else {
    proc ::fileutil::magic::rt::Debug {script} {
	# Run the commands in the debug script. This usually generates
	# some output. The uplevel is required to ensure the proper
	# resolution of all variables found in the script.
	uplevel 1 $script
	return
    }
}



# ### ### ### ######### ######### #########
## Initializ package


proc ::fileutil::magic::rt::Init {} {
    variable typemap
    global tcl_platform

    # map magic typenames to field characteristics: size (#byte),

    # Types without explicit endianess assume/use 'native' byteorder.
    # We also put in special forms for the compiler, so that it can use short
    # names for the native-endian types as well.

    # {to do} {Is ldate done correctly in the procedure?  What is its byte
    # order anyway?  Native?}
    
    foreach {type sig} {
	bedate  {4 S}
	bedouble {8 Q}
	befloat {4 R}
	beid3 {4 n}
	beldate {4 I}
	belong  {4 I}
	beqdate {8 W}
	beqldate {8 W}
	beqwdate {8 W}
	beqldate {8 W}
	bequad {8 W} 
	beshort {2 S}
	bestring16 {2 S}
	byte    {1 c}
	date {4 n}
	double {8 d}
	float {4 f}
	ldate {4 n}
	ledate   {4 n}
	ledouble {8 q}
	leid3 {4 nu}
	lefloat {4 f}
	leldate  {4 i}
	lelong  {4 i}
	leqdate {8 w}
	leqldate {8 w}
	lequad {8 w}
	leqwdate {8 w}
	leshort {2 s}
	lestring16 {2 s}
	long  {4 n}
	medate  {4 me}
	meldate  {4 me}
	melong  {4 me}
	qdate {8 m}
	qdate {8 n}
	qldata {8 m}
	quad {8 m} 
	qwdate {8 m}
	short {2 t}
    } {
	set typemap($type) $sig
	lassign $sig size scan
	set typemap(u$type) [list $size ${scan}u]
    }

    # generate short form names
    foreach {n v} [array get typemap] {
	foreach {len scan} $v break
	set typemap($scan) [list $len $scan]
    }

    # Add the special Q and Y short forms using the proper native endianess.

    if {$tcl_platform(byteOrder) eq {littleEndian}} {
	array set typemap {Q {4 i} Y {2 s} quad {8 w}}
    } else {
	array set typemap {Q {4 I} Y {2 S} quad {8 W}}
    }
}

::fileutil::magic::rt::Init



# ### ### ### ######### ######### #########
## Ready for use.

package provide fileutil::magic::rt 3.0

# EOF
