# -*- tcl -*-
#
# _text.tcl -- Core support for text engines.


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


################################################################
# Formatting constants ... Might be engine variables in the future.

global lmarginIncrement ; set lmarginIncrement 4
global rmarginThreshold ; set rmarginThreshold 20
global bulleting        ; set bulleting        {* - # @ ~ %}
global enumeration      ; set enumeration      {[%] (%) <%>}

proc Bullet {ivar} {
    global bulleting ; upvar $ivar i
    set res [lindex $bulleting $i]
    set i [expr {($i + 1) % [llength $bulleting]}]
    return $res
}

proc EnumBullet {ivar} {
    global enumeration ; upvar $ivar i
    set res [lindex $enumeration $i]
    set i [expr {($i + 1) % [llength $enumeration]}]
    return $res
}

################################################################

#
# The engine maintains several data structures per document and pass.
# Most important is an internal representation of the text better
# suited to perform the final layouting, the display list. Elements of
# the display list are lists containing 2 elements, an operation, and
# its arguments, in this order. The arguments are a list again, its
# contents are specific to the operation.
#
# The operations are:
#
# - SECT	Section.    Title.
# - SUBSECT     Subsection. Title.
# - PARA	Paragraph.  Environment reference and text.
#
# The PARA operation is the workhorse of the engine, dooing all the
# formatting, using the information in an "environment" as the guide
# for doing so. The environments themselves are generated during the
# second pass through the contents. They contain the information about
# nesting (i.e. indentation), bulleting and the like.
#

global cmds ; set cmds [list]   ; # Display list
global pEnv ; array set pEnv {} ; # Defined paragraph environments (bulleting, indentation, other).
global para ; set para ""       ; # Text buffer for paragraphs.

global nextId     ; set       nextId     0      ; # Counter for environment generation.
global currentId  ; set       currentId  {}     ; # Id of current environment in 'pEnv'
global currentEnv ; array set currentEnv {}     ; # Current environment, expanded form.
global contexts   ; set       contexts   [list] ; # Stack of saved environments.
global off        ; set off   1                 ; # Supression of plain text in some places.

################################################################
# Management of the current context.

proc Text  {text}    {global para ; append para $text ; return}
proc Store {op args} {global cmds ; lappend cmds [list $op $args] ; return}
proc Off   {}        {global off ; set off 1 ; return}
proc On    {}        {global off para ; set off 0 ; set para "" ; return}
proc IsOff {}        {global off ; return [expr {$off == 1}]}

# Debugging ...
#proc Text  {text}    {puts_stderr "TXT \{$text\}"; global para; append para $text ; return}
#proc Store {op args} {puts_stderr "STO $op $args"; global cmds; lappend cmds [list $op $args]; return}
#proc Off   {}        {puts_stderr OFF ; global off ; set off 1 ; return}
#proc On    {}        {puts_stderr ON_ ; global off para ; set off 0 ; set para "" ; return}


proc NewEnv {name script} {
    global currentId  nextId currentEnv

    #puts_stderr "NewEnv ($name)"

    set    parentId  $currentId
    set    currentId $nextId
    incr              nextId

    append currentEnv(NAME) -$parentId-$name
    set currentEnv(parent) $parentId
    set currentEnv(id)     $currentId

    # Always squash a verbatim environment inherited from the previous
    # environment ...
    catch {unset currentEnv(verbenv)}

    uplevel $script
    SaveEnv
    return $currentId
}

################################################################

proc TextInitialize {} {
    global off  ; set off 1
    global cmds ; set cmds [list]   ; # Display list
    global pEnv ; array set pEnv {} ; # Defined paragraph environments (bulleting, indentation, other).
    global para ; set para ""       ; # Text buffer for paragraphs.

    global nextId     ; set       nextId     0      ; # Counter for environment generation.
    global currentId  ; set       currentId  {}     ; # Id of current environment in 'pEnv'
    global currentEnv ; array set currentEnv {}     ; # Current environment, expanded form.
    global contexts   ; set       contexts   [list] ; # Stack of saved environments.

    # lmargin  = location of left margin for text.
    # prefix   = prefix string to use for all lines.
    # wspfx    = whitespace prefix for all but the first line
    # listtype = type of list, if any
    # bullet   = bullet to use for unordered, bullet template for ordered.
    # verbatim = flag if verbatim formatting requested.
    # next     = if present the environment to use after closing the paragraph using this one.

    NewEnv Base {
	array set currentEnv {
	    lmargin     0
	    prefix      {}
	    wspfx       {}
	    listtype    {}
	    bullet      {}
	    verbatim    0
	    bulleting   0
	    enumeration 0
	}
    }
    return
}

################################################################

proc Section    {name} {Store SECT    $name ; return}
proc Subsection {name} {Store SUBSECT $name ; return}

proc CloseParagraph {{id {}}} {
    global para currentId
    if {$para != {}} {
	if {$id == {}} {set id $currentId}
	Store PARA $id $para
	#puts_stderr "CloseParagraph $id"
    }
    set para ""
    return
} 

proc SaveContext {} {
    global  contexts  currentId
    lappend contexts $currentId

    #global currentEnv ; puts_stderr "Save>> $currentId ($currentEnv(NAME))"
    return
}

proc RestoreContext {} {
    global                contexts
    SetContext   [lindex $contexts end]
    set contexts [lrange $contexts 0 end-1]

    #global currentId currentEnv ; puts_stderr "<<Restored $currentId ($currentEnv(NAME))"
    return
}

proc SetContext {id} {
    global    currentId currentEnv pEnv
    set       currentId $id

    # Ensure that array is clean before setting hte new block of
    # information.
    unset     currentEnv
    array set currentEnv $pEnv($currentId)

    #puts_stderr "--Set $currentId ($currentEnv(NAME))"
    return
}

proc SaveEnv {} {
    global pEnv  currentId             currentEnv
    set    pEnv($currentId) [array get currentEnv]
    return
}

################################################################

proc NewVerbatim {} {
    global currentEnv
    return [NewEnv Verbatim {set currentEnv(verbatim) 1}]
}

proc Verbatim {} {
    global currentEnv
    if {![info exists currentEnv(verbenv)]} {
	SaveContext
	set verb [NewVerbatim]
	RestoreContext

	# Remember verbatim mode in the base environment
	set currentEnv(verbenv) $verb
	SaveEnv
    }
    return $currentEnv(verbenv)
}

################################################################

proc text_plain_text {text} {
    #puts_stderr "<<text_plain_text>>"

    if  {[IsOff]} {return}

    # Note: Whenever we get plain text it is possible that a macro for
    # visual markup actually generated output before the expander got
    # to the current text. This output was captured by the expander in
    # its current context. Given the current organization of the
    # engine we have to retrieve this formatted text from the expander
    # or it will be lost. This is the purpose of the 'ctopandclear',
    # which retrieves the data and also clears the capture buffer. The
    # latter to prevent us from retrieving it again later, after the
    # next macro added more data.

    set text [ex_ctopandclear]$text

    # ... TODO ... Handling of example => verbatim

    if {[string length [string trim $text]] == 0} return

    Text $text
    return
}

################################################################

proc text_postprocess {text} {

    #puts_stderr XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    #puts_stderr <<$text>>
    #puts_stderr XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

    global cmds
    # The argument is not relevant. Access the display list, perform
    # the final layouting and return its result.

    set linebuffer [list]
    array set state {lmargin 0 rmargin 0}
    foreach cmd $cmds {
	foreach {op arguments} $cmd break
	$op $arguments
    }

    #puts_stderr XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

    return [join $linebuffer \n]
}


proc SECT {text} {
    upvar linebuffer linebuffer

    # text is actually the list of arguments, having one element, the text.
    set text [lindex $text 0]
    #puts_stderr "SECT $text"
    #puts_stderr ""

    # Write section title, underline it

    lappend linebuffer ""
    lappend linebuffer $text
    lappend linebuffer [textutil::repeat::strRepeat = [string length $text]]
    return
}

proc SUBSECT {text} {
    upvar linebuffer linebuffer

    # text is actually the list of arguments, having one element, the text.
    set text [lindex $text 0]
    #puts_stderr "SUBSECT $text"
    #puts_stderr ""

    # Write subsection title, underline it (with less emphasis)

    lappend linebuffer ""
    lappend linebuffer $text
    lappend linebuffer [textutil::repeat::strRepeat - [string length $text]]
    return
}

proc PARA {arguments} {
    global pEnv
    upvar linebuffer linebuffer

    foreach {env text} $arguments break
    array set para $pEnv($env)

    #puts_stderr "PARA $env"
    #parray_stderr para
    #puts_stderr "     \{$text\}"
    #puts_stderr ""

    # Use the information in the referenced environment to format the paragraph.

    if {$para(verbatim)} {
	set text [textutil::adjust::undent $text]
    } else {
	# The size is determined through the set left and right margins
	# right margin is fixed at 80, left margin is variable. Size
	# is at least 20. I.e. when left margin > 60 right margin is
	# shifted out to the right.

	set size [expr {80 - $para(lmargin)}]
	if {$size < 20} {set size 20}

	set text [textutil::adjust::adjust $text -length $size]
    }

    # Now apply prefixes, (ws prefixes bulleting), at last indentation.

    if {[string length $para(prefix)] > 0} {
	set text [textutil::adjust::indent $text $para(prefix)]
    }

    if {$para(listtype) != {}} {
	switch -exact $para(listtype) {
	    bullet {
		# Indent for bullet, but not the first line. This is
		# prefixed by the bullet itself.

		set thebullet $para(bullet)
	    }
	    enum {
		# Handling the enumeration counter. Special case: An
		# example as first paragraph in an item has to use the
		# counter in environment it is derived from to prevent
		# miscounting.

		if {[info exists para(example)]} {
		    set parent $para(parent)
		    array set __ $pEnv($parent)
		    if {![info exists __(counter)]} {
			set __(counter) 1
		    } else {
			incr __(counter)
		    }
		    set pEnv($parent) [array get __] ; # Save context change ...
		    set n $__(counter)
		} else {
		    if {![info exists para(counter)]} {
			set para(counter) 1
		    } else {
			incr para(counter)
		    }
		    set pEnv($env) [array get para] ; # Save context change ...
		    set n $para(counter)
		}

		set thebullet [string map [list % $n] $para(bullet)]
	    }
	}

	set blen [string length $thebullet]
	if {$blen >= [string length $para(wspfx)]} {
	    set text    "$thebullet\n[textutil::adjust::indent $text $para(wspfx)]"
	} else {
	    set fprefix $thebullet[string range $para(wspfx) $blen end]
	    set text    "${fprefix}[textutil::adjust::indent $text $para(wspfx) 1]"
	}
    }

    if {$para(lmargin) > 0} {
	set text [textutil::adjust::indent $text \
		      [textutil::repeat::strRepeat " " $para(lmargin)]]
    }

    lappend linebuffer ""
    lappend linebuffer $text
    return
}

################################################################

proc strong      {text} {return *${text}*}
proc em          {text} {return _${text}_}

################################################################

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

################################################################
