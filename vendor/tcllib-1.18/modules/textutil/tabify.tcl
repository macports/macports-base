#
# As the author of the procs 'tabify2' and 'untabify2' I suggest that the
# comments explaining their behaviour be kept in this file.
# 1) Beginners in any programming language (I am new to Tcl so I know what I
#    am talking about) can profit enormously from studying 'correct' code.
#    Of course comments will help a lot in this regard.
# 2) Many problems newbies face can be solved by directing them towards
#    available libraries - after all, libraries have been written to solve
#    recurring problems. Then they can just use them, or have a closer look
#    to see and to discover how things are done the 'Tcl way'.
# 3) And if ever a proc from a library should be less than perfect, having
#    comments explaining the behaviour of the code will surely help.
#
# This said, I will welcome any error reports or suggestions for improvements
# (especially on the 'doing things the Tcl way' aspect).
#
# Use of these sources is licensed under the same conditions as is Tcl.
#
# June 2001, Helmut Giese (hgiese@ratiosoft.com)
#
# ----------------------------------------------------------------------------
#
# The original procs 'tabify' and 'untabify' each work with complete blocks
# of $num spaces ('num' holding the tab size). While this is certainly useful
# in some circumstances, it does not reflect the way an editor works:
# 	Counting columns from 1, assuming a tab size of 8 and entering '12345'
#   followed by a tab, you expect to advance to column 9. Your editor might
#   put a tab into the file or 3 spaces, depending on its configuration.
#	Now, on 'tabifying' you will expect to see those 3 spaces converted to a
#	tab (and on the other hand expect the tab *at this position* to be
#	converted to 3 spaces).
#
#	This behaviour is mimicked by the new procs 'tabify2' and 'untabify2'.
#   Both have one feature in common: They accept multi-line strings (a whole
#   file if you want to) but in order to make life simpler for the programmer,
#   they split the incoming string into individual lines and hand each line to
#   a proc that does the real work.
#
#   One design decision worth mentioning here:
#      A single space is never converted to a tab even if its position would
#      allow to do so.
#   Single spaces occur very often, say in arithmetic expressions like
#   [expr (($a + $b) * $c) < $d]. If we didn't follow the above rule we might
#   need to replace one or more of them to tabs. However if the tab size gets
#   changed, this expression would be formatted quite differently - which is
#   probably not a good idea.
#
#   'untabifying' on the other hand might need to replace a tab with a single
#   space: If the current position requires it, what else to do?
#   As a consequence those two procs are unsymmetric in this aspect, but I
#   couldn't think of a better solution. Could you?
#
# ----------------------------------------------------------------------------
#

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.2
package require textutil::repeat

namespace eval ::textutil::tabify {}

# ### ### ### ######### ######### #########
## API implementation

namespace eval ::textutil::tabify {
    namespace import -force ::textutil::repeat::strRepeat
}

proc ::textutil::tabify::tabify { string { num 8 } } {
    return [string map [list [MakeTabStr $num] \t] $string]
}

proc ::textutil::tabify::untabify { string { num 8 } } {
    return [string map [list \t [MakeTabStr $num]] $string]
}

proc ::textutil::tabify::MakeTabStr { num } {
    variable TabStr
    variable TabLen

    if { $TabLen != $num } then {
	set TabLen $num
	set TabStr [strRepeat " " $num]
    }

    return $TabStr
}

# ----------------------------------------------------------------------------
#
# tabifyLine: Works on a single line of text, replacing 'spaces at correct
# 		positions' with tabs. $num is the requested tab size.
#		Returns the (possibly modified) line.
#
# 'spaces at correct positions': Only spaces which 'fill the space' between
# an arbitrary position and the next tab stop can be replaced. 
# Example: With tab size 8, spaces at positions 11 - 13 will *not* be replaced,
#          because an expansion of a tab at position 11 will jump up to 16.
# See also the comment at the beginning of this file why single spaces are
# *never* replaced by a tab.
#
# The proc works backwards, from the end of the string up to the beginning:
#	- Set the position to start the search from ('lastPos') to 'end'.
#	- Find the last occurrence of ' ' in 'line' with respect to 'lastPos'
#         ('currPos' below). This is a candidate for replacement.
#       - Find to 'currPos' the following tab stop using the expression
#           set nextTab [expr ($currPos + $num) - ($currPos % $num)]
#         and get the previous tab stop as well (this will be the starting 
#         point for the next iteration).
#	- The ' ' at 'currPos' is only a candidate for replacement if
#	  1) it is just one position before a tab stop *and*
#	  2) there is at least one space at its left (see comment above on not
#	     touching an isolated space).
#	  Continue, if any of these conditions is not met.
#	- Determine where to put the tab (that is: how many spaces to replace?)
#	  by stepping up to the beginning until
#		-- you hit a non-space or
#		-- you are at the previous tab position
#	- Do the replacement and continue.
#
# This algorithm only works, if $line does not contain tabs. Otherwise our 
# interpretation of any position beyond the tab will be wrong. (Imagine you 
# find a ' ' at position 4 in $line. If you got 3 leading tabs, your *real*
# position might be 25 (tab size of 8). Since in real life some strings might 
# already contain tabs, we test for it (and eventually call untabifyLine).
#

proc ::textutil::tabify::tabifyLine { line num } {
    if { [string first \t $line] != -1 } { 		
	# assure array 'Spaces' is set up 'comme il faut'
	checkArr $num
	# remove existing tabs
	set line [untabifyLine $line $num]
    }

    set lastPos end

    while { $lastPos > 0 } {
	set currPos [string last " " $line $lastPos]
	if { $currPos == -1 } {
	    # no more spaces
	    break;
	}

	set nextTab [expr {($currPos + $num) - ($currPos % $num)}]
	set prevTab [expr {$nextTab - $num}]

	# prepare for next round: continue at 'previous tab stop - 1'
	set lastPos [expr {$prevTab - 1}]

	if { ($currPos + 1) != $nextTab } {
	    continue			;# crit. (1)
	}

	if { [string index $line [expr {$currPos - 1}]] != " " } {
	    continue			;# crit. (2)
	}

	# now step backwards while there are spaces
	for {set pos [expr {$currPos - 2}]} {$pos >= $prevTab} {incr pos -1} {
	    if { [string index $line $pos] != " " } {
		break;
	    }
	}

	# ... and replace them
	set line [string replace $line [expr {$pos + 1}] $currPos \t]
    }
    return $line
}

#
# Helper proc for 'untabifyLine': Checks if all needed elements of array
# 'Spaces' exist and creates the missing ones if needed.
#

proc ::textutil::tabify::checkArr { num } {
    variable TabLen2
    variable Spaces

    if { $num > $TabLen2 } {
	for { set i [expr {$TabLen2 + 1}] } { $i <= $num } { incr i } {
	    set Spaces($i) [strRepeat " " $i]
	}
	set TabLen2 $num
    }
}


# untabifyLine: Works on a single line of text, replacing tabs with enough
#		spaces to get to the next tab position.
#		Returns the (possibly modified) line.
#
# The procedure is straight forward:
#	- Find the next tab.
#	- Calculate the next tab position following it.
#	- Delete the tab and insert as many spaces as needed to get there.
#

proc ::textutil::tabify::untabifyLine { line num } {
    variable Spaces

    set currPos 0
    while { 1 } {
	set currPos [string first \t $line $currPos]
	if { $currPos == -1 } {
	    # no more tabs
	    break
	}

	# how far is the next tab position ?
	set dist [expr {$num - ($currPos % $num)}]
	# replace '\t' at $currPos with $dist spaces
	set line [string replace $line $currPos $currPos $Spaces($dist)]

	# set up for next round (not absolutely necessary but maybe a trifle
	# more efficient)
	incr currPos $dist
    }
    return $line
}

# tabify2: Replace all 'appropriate' spaces as discussed above with tabs.
#	'string' might hold any number of lines, 'num' is the requested tab size.
#	Returns (possibly modified) 'string'.
#
proc ::textutil::tabify::tabify2 { string { num 8 } } {

    # split string into individual lines
    set inLst [split $string \n]

    # now work on each line
    set outLst [list]
    foreach line $inLst {
	lappend outLst [tabifyLine $line $num]
    }

    # return all as one string
    return [join $outLst \n]
}


# untabify2: Replace all tabs with the appropriate number of spaces.
#	'string' might hold any number of lines, 'num' is the requested tab size.
#	Returns (possibly modified) 'string'.
#
proc ::textutil::tabify::untabify2 { string { num 8 } } {

    # assure array 'Spaces' is set up 'comme il faut'
    checkArr $num

    set inLst [split $string \n]

    set outLst [list]
    foreach line $inLst {
	lappend outLst [untabifyLine $line $num]
    }

    return [join $outLst \n]
}



# ### ### ### ######### ######### #########
## Data structures

namespace eval ::textutil::tabify {
    variable TabLen  8
    variable TabStr  [strRepeat " " $TabLen]

    namespace export tabify untabify tabify2 untabify2
    
    # The proc 'untabify2' uses the following variables for efficiency.
    # Since a tab can be replaced by one up to 'tab size' spaces, it is handy
    # to have the appropriate 'space strings' available. This is the use of
    # the array 'Spaces', where 'Spaces(n)' contains just 'n' spaces.
    # The variable 'TabLen2' remembers the biggest tab size used.

    variable  TabLen2 0
    variable  Spaces
    array set Spaces {0 ""}
}

# ### ### ### ######### ######### #########
## Ready

package provide textutil::tabify 0.7
