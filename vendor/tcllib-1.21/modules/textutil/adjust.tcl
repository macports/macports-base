# trim.tcl --
#
#	Various ways of trimming a string.
#
# Copyright (c) 2000      by Ajuba Solutions.
# Copyright (c) 2000      by Eric Melski <ericm@ajubasolutions.com>
# Copyright (c) 2002-2004 by Johannes-Heinrich Vogeler <vogeler@users.sourceforge.net>
# Copyright (c) 2001-2006 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: adjust.tcl,v 1.16 2011/12/13 18:12:56 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.2
package require textutil::repeat
package require textutil::string

namespace eval ::textutil::adjust {}

# ### ### ### ######### ######### #########
## API implementation

namespace eval ::textutil::adjust {
    namespace import -force ::textutil::repeat::strRepeat
}

proc ::textutil::adjust::adjust {text args} {
    if {[string length [string trim $text]] == 0} {
        return ""
    }

    Configure $args
    Adjust text newtext

    return $newtext
}

proc ::textutil::adjust::Configure {args} {
    variable Justify      left
    variable Length       72
    variable FullLine     0
    variable StrictLength 0
    variable Hyphenate    0
    variable HyphPatterns    ; # hyphenation patterns (TeX)

    set args [ lindex $args 0 ]
    foreach { option value } $args {
	switch -exact -- $option {
	    -full {
		if { ![ string is boolean -strict $value ] } then {
		    error "expected boolean but got \"$value\""
		}
		set FullLine [ string is true $value ]
	    }
	    -hyphenate {
		# the word exceeding the length of line is tried to be
		# hyphenated; if a word cannot be hyphenated to fit into
		# the line processing stops! The length of the line should
		# be set to a reasonable value!

		if { ![ string is boolean -strict $value ] } then {
		    error "expected boolean but got \"$value\""
		}
		set Hyphenate [string is true $value]
		if { $Hyphenate && ![info exists HyphPatterns(_LOADED_)]} {
		    error "hyphenation patterns not loaded!"
		}
	    }
	    -justify {
		set lovalue [ string tolower $value ]
		switch -exact -- $lovalue {
		    left -
		    right -
		    center -
		    plain {
			set Justify $lovalue
		    }
		    default {
			error "bad value \"$value\": should be center, left, plain or right"
		    }
		}
	    }
	    -length {
		if { ![ string is integer $value ] } then {
		    error "expected positive integer but got \"$value\""
		}
		if { $value < 1 } then {
		    error "expected positive integer but got \"$value\""
		}
		set Length $value
	    }
	    -strictlength {
		# the word exceeding the length of line is moved to the
		# next line without hyphenation; words longer than given
		# line length are cut into smaller pieces

		if { ![ string is boolean -strict $value ] } then {
		    error "expected boolean but got \"$value\""
		}
		set StrictLength [ string is true $value ]
	    }
	    default {
		error "bad option \"$option\": must be -full, -hyphenate, \
			-justify, -length, or -strictlength"
	    }
	}
    }

    return ""
}

# ::textutil::adjust::Adjust
#
# History:
#      rewritten on 2004-04-13 for bugfix tcllib-bugs-882402 (jhv)

proc ::textutil::adjust::Adjust { varOrigName varNewName } {
    variable Length
    variable FullLine
    variable StrictLength
    variable Hyphenate

    upvar $varOrigName orig
    upvar $varNewName  text

    set pos 0;                                   # Cursor after writing
    set line ""
    set text ""


    if {!$FullLine} {
	regsub -all -- "(\n)|(\t)"     $orig   " "  orig
	regsub -all -- " +"            $orig  " "   orig
	regsub -all -- "(^ *)|( *\$)"  $orig  ""    orig
    }

    set words [split $orig]
    set numWords [llength $words]
    set numline 0

    for {set cnt 0} {$cnt < $numWords} {incr cnt} {

	set w [lindex $words $cnt]
	set wLen [string length $w]

	# the word $w doesn't fit into the present line
	# case #1: we try to hyphenate

	if {$Hyphenate && ($pos+$wLen >= $Length)} {
	    # Hyphenation instructions
	    set w2 [textutil::adjust::Hyphenation $w]

	    set iMax [llength $w2]
	    if {$iMax == 1 && [string length $w] > $Length} {
		# word cannot be hyphenated and exceeds linesize

		error "Word \"$w2\" can\'t be hyphenated\
			and exceeds linesize $Length!"
	    } else {
		# hyphenating of $w was successfull, but we have to look
		# that every sylable would fit into the line

		foreach x $w2 {
		    if {[string length $x] >= $Length} {
			error "Word \"$w\" can\'t be hyphenated\
				to fit into linesize $Length!"
		    }
		}
	    }

	    for {set i 0; set w3 ""} {$i < $iMax} {incr i} {
		set syl [lindex $w2 $i]
		if {($pos+[string length " $w3$syl-"]) > $Length} {break}
		append w3 $syl
	    }
	    for {set w4 ""} {$i < $iMax} {incr i} {
		set syl [lindex $w2 $i]
		append w4 $syl
	    }

	    if {[string length $w3] && [string length $w4]} {
		# hyphenation was successfull: redefine
		# list of words w => {"$w3-" "$w4"}

		set x [lreplace $words $cnt $cnt "$w4"]
		set words [linsert $x $cnt "$w3-"]
		set w [lindex $words $cnt]
		set wLen [string length $w]
		incr numWords
	    }
	}

	# the word $w doesn't fit into the present line
	# case #2: we try to cut the word into pieces

	if {$StrictLength && ([string length $w] > $Length)} {
	    # cut word into two pieces
	    set w2 $w

	    set over [expr {$pos+2+$wLen-$Length}]

	    incr Length -1
	    set w3   [string range $w2 0 $Length]
	    incr Length
	    set w4   [string range $w2 $Length end]

	    set x [lreplace $words $cnt $cnt $w4]
	    set words [linsert $x $cnt $w3 ]
	    set w [lindex $words $cnt]
	    set wLen [string length $w]
	    incr numWords
	}

	# continuing with the normal procedure

	if {($pos+$wLen < $Length)} {
	    # append word to current line

	    if {$pos} {append line " "; incr pos}
	    append line $w
	    incr pos $wLen
	} else {
	    # line full => write buffer and  begin a new line

	    if {[string length $text]} {append text "\n"}
	    append text [Justification $line [incr numline]]
	    set line $w
	    set pos $wLen
	}
    }

    # write buffer and return!

    if {[string length $text]} {append text "\n"}
    append text [Justification $line end]
    return $text
}

# ::textutil::adjust::Justification
#
# justify a given line
#
# Parameters:
#      line    text for justification
#      index   index for line in text
#
# Returns:
#      the justified line
#
# Remarks:
#      Only lines with size not exceeding the max. linesize provided
#      for text formatting are justified!!!

proc ::textutil::adjust::Justification { line index } {
    variable Justify
    variable Length
    variable FullLine

    set len [string length $line];               # length of current line

    if { $Length <= $len } then {
	# the length of current line ($len) is equal as or greater than
	# the value provided for text formatting ($Length) => to avoid
	# inifinite loops we leave $line unchanged and return!

	return $line
    }

    # Special case:
    # for the last line, and if the justification is set to 'plain'
    # the real justification is 'left' if the length of the line
    # is less than 90% (rounded) of the max length allowed. This is
    # to avoid expansion of this line when it is too small: without
    # it, the added spaces will 'unbeautify' the result.
    #

    set justify $Justify
    if { ( "$index" == "end" ) && \
	    ( "$Justify" == "plain" ) && \
	    ( $len < round($Length * 0.90) ) } then {
	set justify left
    }

    # For a left justification, nothing to do, but to
    # add some spaces at the end of the line if requested

    if { "$justify" == "left" } then {
	set jus ""
	if { $FullLine } then {
	    set jus [strRepeat " " [ expr { $Length - $len } ]]
	}
	return "${line}${jus}"
    }

    # For a right justification, just add enough spaces
    # at the beginning of the line

    if { "$justify" == "right" } then {
	set jus [strRepeat " " [ expr { $Length - $len } ]]
	return "${jus}${line}"
    }

    # For a center justification, add half of the needed spaces
    # at the beginning of the line, and the rest at the end
    # only if needed.

    if { "$justify" == "center" } then {
	set mr [ expr { ( $Length - $len ) / 2 } ]
	set ml [ expr { $Length - $len - $mr } ]
	set jusl [strRepeat " " $ml]
	set jusr [strRepeat " " $mr]
	if { $FullLine } then {
	    return "${jusl}${line}${jusr}"
	} else {
	    return "${jusl}${line}"
	}
    }

    # For a plain justification, it's a little bit complex:
    #
    # if some spaces are missing, then
    #
    # 1) sort the list of words in the current line by decreasing size
    # 2) foreach word, add one space before it, except if it's the
    #    first word, until enough spaces are added
    # 3) rebuild the line

    if { "$justify" == "plain" } then {
	set miss [ expr { $Length - [ string length $line ] } ]

	# Bugfix tcllib-bugs-860753 (jhv)

	set words [split $line]
	set numWords [llength $words]

	if {$numWords < 2} {
	    # current line consists of less than two words - we can't
	    # insert blanks to achieve a plain justification => leave
	    # $line unchanged and return!

	    return $line
	}

	for {set i 0; set totalLen 0} {$i < $numWords} {incr i} {
	    set w($i) [lindex $words $i]
	    if {$i > 0} {set w($i) " $w($i)"}
	    set wLen($i) [string length $w($i)]
	    set totalLen [expr {$totalLen+$wLen($i)}]
	}

	set miss [expr {$Length - $totalLen}]

	# len walks through all lengths of words of the line under
	# consideration

	for {set len 1} {$miss > 0} {incr len} {
	    for {set i 1} {($i < $numWords) && ($miss > 0)} {incr i} {
		if {$wLen($i) == $len} {
		    set w($i) " $w($i)"
		    incr wLen($i)
		    incr miss -1
		}
	    }
	}

	set line ""
	for {set i 0} {$i < $numWords} {incr i} {
	    set line "$line$w($i)"
	}

	# End of bugfix

	return "${line}"
    }

    error "Illegal justification key \"$justify\""
}

proc ::textutil::adjust::SortList { list dir index } {

    if { [ catch { lsort -integer -$dir -index $index $list } sl ] != 0 } then {
        error "$sl"
    }

    return $sl
}

# Hyphenation utilities based on Knuth's algorithm
#
# Copyright (C) 2001-2003 by Dr.Johannes-Heinrich Vogeler (jhv)
# These procedures may be used as part of the tcllib

# textutil::adjust::Hyphenation
#
#      Hyphenate a string using Knuth's algorithm
#
# Parameters:
#      str     string to be hyphenated
#
# Returns:
#      the hyphenated string

proc ::textutil::adjust::Hyphenation { str } {

    # if there are manual set hyphenation marks e.g. "Recht\-schrei\-bung"
    # use these for hyphenation and return

    if {[regexp {[^\\-]*[\\-][.]*} $str]} {
	regsub -all {(\\)(-)} $str {-} tmp
	return [split $tmp -]
    }

    # Don't hyphenate very short words! Minimum length for hyphenation
    # is set to 3 characters!

    if { [string length $str] < 4 } then { return $str }

    # otherwise follow Knuth's algorithm

    variable HyphPatterns;                       # hyphenation patterns (TeX)

    set w ".[string tolower $str].";             # transform to lower case
    set wLen [string length $w];                 # and add delimiters

    # Initialize hyphenation weights

    set s {}
    for {set i 0} {$i < $wLen} {incr i} {
	lappend s 0
    }

    for {set i 0} {$i < $wLen} {incr i} {
	set kmax [expr {$wLen-$i}]
	for {set k 1} {$k < $kmax} {incr k} {
	    set sw [string range $w $i [expr {$i+$k}]]
	    if {[info exists HyphPatterns($sw)]} {
		set hw $HyphPatterns($sw)
		set hwLen [string length $hw]
		for {set l1 0; set l2 0} {$l1 < $hwLen} {incr l1} {
		    set c [string index $hw $l1]
		    if {[string is digit $c]} {
			set sPos [expr {$i+$l2}]
			if {$c > [lindex $s $sPos]} {
			    set s [lreplace $s $sPos $sPos $c]
			}
		    } else {
			incr l2
		    }
		}
	    }
	}
    }

    # Replace all even hyphenation weigths by zero

    for {set i 0} {$i < [llength $s]} {incr i} {
	set c [lindex $s $i]
	if {!($c%2)} { set s [lreplace $s $i $i 0] }
    }

    # Don't start with a hyphen! Take also care of words enclosed in quotes
    # or that someone has forgotten to put a blank between a punctuation
    # character and the following word etc.

    for {set i 1} {$i < ($wLen-1)} {incr i} {
	set c [string range $w $i end]
	if {[regexp {^[:alpha:][.]*} $c]} {
	    for {set k 1} {$k < ($i+1)} {incr k} {
		set s [lreplace $s $k $k 0]
	    }
	    break
	}
    }

    # Don't separate the last character of a word with a hyphen

    set max [expr {[llength $s]-2}]
    if {$max} {set s [lreplace $s $max end 0]}

    # return the syllabels of the hyphenated word as a list!

    set ret ""
    set w ".$str."
    for {set i 1} {$i < ($wLen-1)} {incr i} {
	if {[lindex $s $i]} { append ret - }
	append ret [string index $w $i]
    }
    return [split $ret -]
}

# textutil::adjust::listPredefined
#
#      Return the names of the hyphenation files coming with the package.
#
# Parameters:
#      None.
#
# Result:
#       List of filenames (without directory)

proc ::textutil::adjust::listPredefined {} {
    variable here
    return [glob -type f -directory $here -tails *.tex]
}

# textutil::adjust::getPredefined
#
#      Retrieve the full path for a predefined hyphenation file
#       coming with the package.
#
# Parameters:
#      name     Name of the predefined file.
#
# Results:
#       Full path to the file, or an error if it doesn't
#       exist or is matching the pattern *.tex.

proc ::textutil::adjust::getPredefined {name} {
    variable here

    if {![string match *.tex $name]} {
        return -code error \
                "Illegal hyphenation file \"$name\""
    }
    set path [file join $here $name]
    if {![file exists $path]} {
        return -code error \
                "Unknown hyphenation file \"$path\""
    }
    return $path
}

# textutil::adjust::readPatterns
#
#      Read hyphenation patterns from a file and store them in an array
#
# Parameters:
#      filNam  name of the file containing the patterns

proc ::textutil::adjust::readPatterns { filNam } {

    variable HyphPatterns;                       # hyphenation patterns (TeX)

    # HyphPatterns(_LOADED_) is used as flag for having loaded
    # hyphenation patterns from the respective file (TeX format)

    if {[info exists HyphPatterns(_LOADED_)]} {
	unset HyphPatterns(_LOADED_)
    }

    # the array xlat provides translation from TeX encoded characters
    # to those of the ISO-8859-1 character set

    set xlat(\"s) \337;  # 223 := sharp s    "
    set xlat(\`a) \340;  # 224 := a, grave
    set xlat(\'a) \341;  # 225 := a, acute
    set xlat(\^a) \342;  # 226 := a, circumflex
    set xlat(\"a) \344;  # 228 := a, diaeresis "
    set xlat(\`e) \350;  # 232 := e, grave
    set xlat(\'e) \351;  # 233 := e, acute
    set xlat(\^e) \352;  # 234 := e, circumflex
    set xlat(\`i) \354;  # 236 := i, grave
    set xlat(\'i) \355;  # 237 := i, acute
    set xlat(\^i) \356;  # 238 := i, circumflex
    set xlat(\~n) \361;  # 241 := n, tilde
    set xlat(\`o) \362;  # 242 := o, grave
    set xlat(\'o) \363;  # 243 := o, acute
    set xlat(\^o) \364;  # 244 := o, circumflex
    set xlat(\"o) \366;  # 246 := o, diaeresis "
    set xlat(\`u) \371;  # 249 := u, grave
    set xlat(\'u) \372;  # 250 := u, acute
    set xlat(\^u) \373;  # 251 := u, circumflex
    set xlat(\"u) \374;  # 252 := u, diaeresis "

    set fd [open $filNam RDONLY]
    set status 0

    while {[gets $fd line] >= 0} {

	switch -exact $status {
	    PATTERNS {
		if {[regexp {^\}[.]*} $line]} {
		    # End of patterns encountered: set status
		    # and ignore that line
		    set status 0
		    continue
		} else {
		    # This seems to be pattern definition line; to process it
		    # we have first to do some editing
		    #
		    # 1) eat comments in a pattern definition line
		    # 2) eat braces and coded linefeeds

		    set z [string first "%" $line]
		    if {$z > 0} { set line [string range $line 0 [expr {$z-1}]] }

		    regsub -all {(\\n|\{|\})} $line {} tmp
		    set line $tmp

		    # Now $line should consist only of hyphenation patterns
		    # separated by white space

		    # Translate TeX encoded characters to ISO-8859-1 characters
		    # using the array xlat defined above

		    foreach x [array names xlat] {
			regsub -all {$x} $line $xlat($x) tmp
			set line $tmp
		    }

		    # split the line and create a lookup array for
		    # the repective hyphenation patterns

		    foreach item [split $line] {
			if {[string length $item]} {
			    if {![string match {\\} $item]} {
				# create index for hyphenation patterns

				set var $item
				regsub -all {[0-9]} $var {} idx
				# store hyphenation patterns as elements of an array

				set HyphPatterns($idx) $item
			    }
			}
		    }
		}
	    }
	    EXCEPTIONS {
		if {[regexp {^\}[.]*} $line]} {
		    # End of patterns encountered: set status
		    # and ignore that line
		    set status 0
		    continue
		} else {
		    # to be done in the future
		}
	    }
	    default {
		if {[regexp {^\\endinput[.]*} $line]} {
		    # end of data encountered, stop processing and
		    # ignore all the following text ..
		    break
		} elseif {[regexp {^\\patterns[.]*} $line]} {
		    # begin of patterns encountered: set status
		    # and ignore that line
		    set status PATTERNS
		    continue
		} elseif {[regexp {^\\hyphenation[.]*} $line]} {
		    # some particular cases to be treated separately
		    set status EXCEPTIONS
		    continue
		} else {
		    set status 0
		}
	    }
	}
    }

    close $fd
    set HyphPatterns(_LOADED_) 1

    return
}

#######################################################

# @c The specified <a text>block is indented
# @c by <a prefix>ing each line. The first
# @c <a hang> lines ares skipped.
#
# @a text:   The paragraph to indent.
# @a prefix: The string to use as prefix for each line
# @a prefix: of <a text> with.
# @a skip:   The number of lines at the beginning to leave untouched.
#
# @r Basically <a text>, but indented a certain amount.
#
# @i indent
# @n This procedure is not checked by the testsuite.

proc ::textutil::adjust::indent {text prefix {skip 0}} {
    set text [string trimright $text]

    set res [list]
    foreach line [split $text \n] {
	if {[string compare "" [string trim $line]] == 0} {
	    lappend res {}
	} else {
	    set line [string trimright $line]
	    if {$skip <= 0} {
		lappend res $prefix$line
	    } else {
		lappend res $line
	    }
	}
	if {$skip > 0} {incr skip -1}
    }
    return [join $res \n]
}

# Undent the block of text: Compute LCP (restricted to whitespace!)
# and remove that from each line. Note that this preverses the
# shaping of the paragraph (i.e. hanging indent are _not_ flattened)
# We ignore empty lines !!

proc ::textutil::adjust::undent {text} {

    if {$text == {}} {return {}}

    set lines [split $text \n]
    set ne [list]
    foreach l $lines {
	if {[string length [string trim $l]] == 0} continue
	lappend ne $l
    }
    set lcp [::textutil::string::longestCommonPrefixList $ne]

    if {[string length $lcp] == 0} {return $text}

    regexp "^(\[\t \]*)" $lcp -> lcp

    if {[string length $lcp] == 0} {return $text}

    set len [string length $lcp]

    set res [list]
    foreach l $lines {
	if {[string length [string trim $l]] == 0} {
	    lappend res {}
	} else {
	    lappend res [string range $l $len end]
	}
    }
    return [join $res \n]
}

# ### ### ### ######### ######### #########
## Data structures

namespace eval ::textutil::adjust {
    variable here [file dirname [info script]]

    variable Justify      left
    variable Length       72
    variable FullLine     0
    variable StrictLength 0
    variable Hyphenate    0
    variable HyphPatterns

    namespace export adjust indent undent
}

# ### ### ### ######### ######### #########
## Ready

package provide textutil::adjust 0.7.3
