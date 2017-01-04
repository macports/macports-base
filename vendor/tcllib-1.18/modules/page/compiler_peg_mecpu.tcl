# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Parser Generator / Transformation - Compile grammar to ME cpu instructions.

# This package assumes to be used from within a PAGE plugin. It uses
# the API commands listed below. These are identical across the major
# types of PAGE plugins, allowing this package to be used in reader,
# transform, and writer plugins. It cannot be used in a configuration
# plugin, and this makes no sense either.
#
# To ensure that our assumption is ok we require the relevant pseudo
# package setup by the PAGE plugin management code.
#
# -----------------+--
# page_info        | Reporting to the user.
# page_warning     |
# page_error       |
# -----------------+--
# page_log_error   | Reporting of internals.
# page_log_warning |
# page_log_info    |
# -----------------+--

# ### ### ### ######### ######### #########
## Dumping the input grammar. But not as Tcl or other code. In PEG
## format again, pretty printing.

# ### ### ### ######### ######### #########
## Requisites

# @mdgen NODEP: page::plugin

package require page::plugin ; # S.a. pseudo-package.

package require grammar::me::cpu::gasm
package require textutil
package require struct::graph

package require page::analysis::peg::emodes
package require page::util::quote
package require page::util::peg

namespace eval ::page::compiler::peg::mecpu {
    # Get the peg char de/encoder commands.
    # (unquote, quote'tcl)

    namespace import ::page::util::quote::*
    namespace import ::page::util::peg::*


    namespace eval gas {
	namespace import ::grammar::me::cpu::gas::begin
	namespace import ::grammar::me::cpu::gas::done
	namespace import ::grammar::me::cpu::gas::lift
	namespace import ::grammar::me::cpu::gas::state
	namespace import ::grammar::me::cpu::gas::state!
    }
    namespace import ::grammar::me::cpu::gas::*
    rename begin  {}
    rename done   {}
    rename lift   {}
    rename state  {}
    rename state! {}
}

# ### ### ### ######### ######### #########
## Data structures for the generated code.

## All data is held in node attributes of the tree. Per node:
##
## asm - List of instructions implementing the node.



# ### ### ### ######### ######### #########
## API

proc ::page::compiler::peg::mecpu {t} {
    # Resolve the mode hints. Every gen(X) having a value of 'maybe'
    # (or missing) is for the purposes of this code a 'yes'.

    if {![page::analysis::peg::emodes::compute $t]} {
	page_error "  Unable to generate a ME parser without accept/generate properties"
	return
    }

    foreach n [$t nodes] {
	if {![$t keyexists $n gen] || ([$t get $n gen] eq "maybe")} {
	    $t set $n gen 1
	}
	if {![$t keyexists $n acc]} {$t set $n acc 1}
    }

    # Synthesize a program, then the assembly code.

    mecpu::Synth $t
    return
}

# ### ### ### ######### ######### #########
## Internal. Helpers

proc ::page::compiler::peg::mecpu::Synth {t} {
    # Phase 2: Bottom-up, synthesized attributes

    # We use a global graph to capture instructions and their
    # relations. The graph is then converted into a linear list of
    # instructions, with proper labeling and jump instructions to
    # handle all non-linear control-flow.

    set g [struct::graph g]
    $t set root gas::called {}

    page_info "* Synthesize graph code"

    $t walk root -order post -type dfs n {
	SynthNode $n
    }

    status             $g  ;  gdump $g synth
    remove_unconnected $g  ;  gdump $g nounconnected
    remove_dead        $g  ;  gdump $g nodead
    denop              $g  ;  gdump $g nonops
    parcmerge          $g  ;  gdump $g parcmerge
    forwmerge          $g  ;  gdump $g fmerge
    backmerge          $g  ;  gdump $g bmerge
    status             $g  
    pathlengths        $g  ;  gdump $g pathlen
    jumps              $g  ;  gdump $g jumps
    status             $g
    symbols            $g $t

    set cc [2code $t $g]
    #write asm/mecode [join $cc \n]

    statistics $cc

    $t set root asm $cc
    $g destroy
    return
}

proc ::page::compiler::peg::mecpu::SynthNode {n} {
    upvar 1 t t g g
    if {$n eq "root"} {
	set code Root
    } elseif {[$t keyexists $n symbol]} {
	set code Nonterminal
    } elseif {[$t keyexists $n op]} {
	set code [$t get $n op]
    } else {
	return -code error "PANIC. Bad node $n, cannot classify"
    }

    page_log_info "  [np $n] := ([linsert [$t children $n] 0 $code])"

    SynthNode/$code $n
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/Root {n} {
    upvar 1 t t g g

    # Root is the grammar itself.

    set gstart [$t get root start]
    set gname  [$t get root name]

    if {$gstart eq ""} {
	page_error "  No start expression."
	return
    }

    gas::begin $g $n halt "<Start Expression> '$gname'"
    $g node set [Who entry] instruction .C
    $g node set [Who entry] START .

    Inline $t $gstart sexpr
    /At sexpr/exit/ok   ; /Ok   ; Jmp exit/return
    /At sexpr/exit/fail ; /Fail ; Jmp exit/return

    gas::done --> $t
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/Nonterminal {n} {
    upvar 1 t t g g

    # This is the root of a definition.
    #
    # The text is a procedure wrapping the match code of its
    # expression into the required the nonterminal handling (caching
    # and such), plus the support code for the expression matcher.

    set sym      [$t get $n symbol]
    set label    [$t get $n label]
    set gen      [$t get $n gen]
    set mode     [$t get $n mode]

    set pe       [lindex [$t children $n] 0]
    set egen     [$t get $pe gen]

    # -> inc_restore -found-> NOP  gen:  -> ok -> ias_push -> RETURN
    #               /!found             \                  /
    #              /                     \-fail --------->/
    #             /               !gen: -> RETURN
    #            /
    #            \-> icl_push (-> ias_mark) -> (*) -> SV -> inc_save (-> ias_mrewind) -X
    #
    # X -ok----> ias_push -> ier_nonterminal
    #  \                  /
    #   \-fail ----------/

    # Poking into the generated instructions, converting the initial
    # .NOP into a .C'omment.

    set first [gas::begin $g $n !okfail "Nonterminal '$sym'"]
    $g node set [Who entry] instruction .C
    $g node set [Who entry] START .

    Cmd inc_restore $label ; /Label restore ; /Ok

    if {$gen} {
	Bra ; /Label @
	/Fail ; Nop          ; Exit
	/At @
	/Ok   ; Cmd ias_push ; Exit
    } else {
	Nop ; Exit
    }

    /At restore ; /Fail
    Cmd icl_push ; # Balanced by inc_save (XX)
    Cmd icl_push ; # Balanced by pop after ier_terminal

    if {$egen} {
	# [*] Needed for removal of SV's from stack after handling by
	# this symbol, only if expression actually generates an SV.

	Cmd ias_mark
    }

    Inline $t $pe subexpr ; /Ok   ; Nop ; /Label unified
    /At subexpr/exit/fail ; /Fail ; Jmp unified
    /At unified

    switch -exact -- $mode {
	value   {Cmd isv_nonterminal_reduce $label}
	match   {Cmd isv_nonterminal_range  $label}
	leaf    {Cmd isv_nonterminal_leaf   $label}
	discard {Cmd isv_clear}
	default {return -code error "Bad nonterminal mode \"$mode\""}
    }

    Cmd inc_save $label ; # Implied icl_pop (XX)

    if {$egen} {
	# See [*], this is the removal spoken about before.
	Cmd ias_mrewind
    }

    /Label hold

    if {$gen} {
	/Ok
	Cmd ias_push
	Nop           ; /Label merge
	/At hold ; /Fail ; Jmp merge
	/At merge
    }

    Cmd ier_nonterminal "Expected $label"
    Cmd icl_pop
    Exit

    gas::done --> $t
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/? {n} {
    upvar 1 t t g g

    # The expression e? is equivalent to e/epsilon.
    # And like this it is compiled.

    set pe       [lindex [$t children $n] 0]

    gas::begin $g $n okfail ?

    # -> icl_push -> ier_push -> (*) -ok--> ier_merge/ok --> icl_pop -ok----------------> OK
    #                             \                                                    /
    #                              \-fail-> ier_merge/f ---> icl_rewind -> iok_ok -ok-/

    Cmd icl_push
    Cmd ier_push

    Inline $t $pe subexpr

    /Ok
    Cmd ier_merge
    Cmd icl_pop
    /Ok ; Exit

    /At subexpr/exit/fail ; /Fail
    Cmd ier_merge
    Cmd icl_rewind
    Cmd iok_ok
    /Ok ; Exit

    gas::done --> $t
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/* {n} {
    upvar 1 t t g g

    # Kleene star is like a repeated ?

    # Note: Compilation as while loop, as done now
    # means that the parser has no information about
    # the intermediate structure of the input in his
    # cache.

    # Future: Create a helper symbol X and compile
    # the expression e = e'* as:
    #     e = X; X <- (e' X)?
    # with match data for X put into the cache. This
    # is not exactly equivalent, the structure of the
    # AST is different (right-nested tree instead of
    # a list). This however can be handled with a
    # special nonterminal mode to expand the current
    # SV on the stack.

    # Note 2: This is a transformation which can be
    # done on the grammar itself, before the actual
    # backend is let loose. This "strength reduction"
    # allows us to keep this code here.

    set pe       [lindex [$t children $n] 0]
    set egen     [$t get $pe gen]

    # Build instruction graph.

    #  /<---------------------------------------------------------------\
    #  \_                                                                \_
    # ---> icl_push -> ier_push -> (*) -ok--> ier_merge/ok --> icl_pop ->/
    #                               \
    #                                \-fail-> ier_merge/f ---> icl_rewind -> iok_ok -> OK

    gas::begin $g $n okfail *

    Cmd icl_push ; /Label header
    Cmd ier_push

    Inline $t $pe loop

    /Ok
    Cmd ier_merge
    Cmd icl_pop
    Jmp header ; /CloseLoop

    /At loop/exit/fail ; /Fail
    Cmd ier_merge
    Cmd icl_rewind
    Cmd iok_ok
    /Ok ; Exit

    gas::done --> $t
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/+ {n} {
    upvar 1 t t g g

    # Positive Kleene star x+ is equivalent to x x*
    # This is how it is compiled. See also the notes
    # at the * above, they apply in essence here as
    # well, except that the transformat scheme is
    # slighty different:
    #
    # e = e'*  ==> e = X; X <- e' X?

    set pe [lindex [$t children $n] 0]

    # Build instruction graph.

    # icl_push -> ier_push -> (*) -fail-> ier_merge/fl -> icl_rewind -> FAIL
    #                          \
    #                           \--ok---> ier_merge/ok -> icl_pop ->\_
    #                                                               /
    #    /<--------------------------------------------------------/
    #   /
    #  /<---------------------------------------------------------------\
    #  \_                                                                \_
    #   -> icl_push -> ier_push -> (*) -ok--> ier_merge/ok --> icl_pop ->/
    #                               \
    #                                \-fail-> ier_merge/f ---> icl_rewind -> iok_ok -> OK

    gas::begin $g $n okfail +

    Cmd icl_push
    Cmd ier_push

    Inline $t $pe first
    /At first/exit/fail ; /Fail
    Cmd ier_merge
    Cmd icl_rewind
    /Fail ; Exit

    /At first/exit/ok ; /Ok
    Cmd ier_merge
    Cmd icl_pop

    # Loop copied from Kleene *, it is *

    Cmd icl_push ; /Label header
    Cmd ier_push

    # For the loop we create the sub-expression instruction graph a
    # second time. This is done by walking the subtree a second time
    # and constructing a completely new node set. The result is
    # imported under a new name.

    set save [gas::state]
    $t walk $pe -order post -type dfs n {SynthNode $n}
    gas::state! $save
    Inline $t $pe loop

    /Ok
    Cmd ier_merge
    Cmd icl_pop
    Jmp header ; /CloseLoop

    /At loop/exit/fail ; /Fail
    Cmd ier_merge
    Cmd icl_rewind
    Cmd iok_ok
    /Ok ; Exit

    gas::done --> $t
    return
}

proc ::page::compiler::peg::mecpu::SynthNode// {n} {
    upvar 1 t t g g

    set args [$t children $n]

    if {![llength $args]} {
	error "PANIC. Empty choice."

    } elseif {[llength $args] == 1} {
	# A choice over one branch is no real choice. The code
	# generated for the child applies here as well.

	gas::lift $t $n <-- [lindex $args 0]
	return
    }

    # Choice over at least two branches.
    # Build instruction graph.

    # -> BRA
    #
    # BRA -> icl_push (-> ias_mark) -> ier_push -> (*) -ok -> ier_merge -> BRA'OK
    #                                              \-fail -> ier_merge (-> ias_mrewind) -> icl_rewind -> BRA'FAIL
    #
    # BRA'FAIL -> BRA
    # BRA'FAIL -> FAIL (last branch)
    #
    # BRA'OK -> icl_pop -> OK

    gas::begin $g $n okfail /

    /Clear
    Cmd icl_pop ; /Label BRA'OK ; /Ok ; Exit
    /At entry

    foreach pe $args {
	set egen [$t get $pe gen]

	# Note: We do not check for static match results. Doing so is
	# an optimization we can do earlier, directly on the tree.

	Cmd icl_push
	if {$egen} {Cmd ias_mark}

	Cmd ier_push
	Inline $t $pe subexpr

	/Ok
	Cmd ier_merge
	Jmp BRA'OK

	/At subexpr/exit/fail ; /Fail
	Cmd ier_merge
	if {$egen} {Cmd ias_mrewind}
	Cmd icl_rewind

	# Branch failed. Go to the next branch. Fail completely at
	# last branch.
    }

    /Fail ; Exit

    gas::done --> $t
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/x {n} {
    upvar 1 t t g g

    set args [$t children $n]

    if {![llength $args]} {
	error "PANIC. Empty sequence."

    } elseif {[llength $args] == 1} {
	# A sequence of one element is no real sequence. The code
	# generated for the child applies here as well.

	gas::lift $t $n <-- [lindex $args 0]
	return
    }

    # Sequence of at least two elements.
    # Build instruction graph.

    # -> icl_push -> SEG
    #
    # SEG (-> ias_mark) -> ier_push -> (*) -ok -> ier_merge -> SEG'OK
    #                                  \-fail -> ier_merge -> SEG'FAIL
    #
    # SEG'OK -> SEG
    # SEG'OK -> icl_pop -> OK (last segment)
    #
    # SEG'FAIL (-> ias_mrewind) -> icl_rewind -> FAIL

    gas::begin $g $n okfail x

    /Clear
    Cmd icl_rewind ; /Label SEG'FAIL ; /Fail ; Exit

    /At entry
    Cmd icl_push

    set gen 0
    foreach pe $args {
	set egen [$t get $pe gen]
	if {$egen && !$gen} {
	    set gen 1

	    # From here on out is the sequence able to generate
	    # semantic values which have to be canceled when
	    # backtracking.

	    Cmd ias_mark ; /Label @mark

	    /Clear
	    Cmd ias_mrewind ; Jmp SEG'FAIL ; /Label SEG'FAIL

	    /At @mark
	}

	Cmd ier_push
	Inline $t $pe subexpr

	/At subexpr/exit/fail ; /Fail
	Cmd ier_merge
	Jmp SEG'FAIL

	/At subexpr/exit/ok ; /Ok
	Cmd ier_merge 
    }

    Cmd icl_pop
    /Ok ; Exit

    gas::done --> $t
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/& {n} {
    upvar 1 t t g g
    SynthLookahead $n no
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/! {n} {
    upvar 1 t t g g
    SynthLookahead $n yes
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/dot {n} {
    upvar 1 t t g g
    SynthTerminal $n {} "any character"
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/epsilon {n} {
    upvar 1 t t g g

    gas::begin $g $n okfail epsilon

    Cmd iok_ok ; /Ok ; Exit

    gas::done --> $t
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/alnum {n} {
    upvar 1 t t g g
    SynthClass $n alnum
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/alpha {n} {
    upvar 1 t t g g
    SynthClass $n alpha
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/digit {n} {
    upvar 1 t t g g
    SynthClass $n digit
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/xdigit {n} {
    upvar 1 t t g g
    SynthClass $n xdigit
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/punct {n} {
    upvar 1 t t g g
    SynthClass $n punct
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/space {n} {
    upvar 1 t t g g
    SynthClass $n space
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/.. {n} {
    upvar 1 t t g g
    # Range is [x-y]

    set b [$t get $n begin]
    set e [$t get $n end]

    set tb [quote'tcl $b]
    set te [quote'tcl $e]

    set pb [quote'tclstr $b]
    set pe [quote'tclstr $e]

    SynthTerminal $n [list ict_match_tokrange $tb $te] "\\\[${pb}..${pe}\\\]"
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/t {n} {
    upvar 1 t t g g

    # Terminal node. Primitive matching.
    # Code is parameterized by gen(X) of this node X.

    set ch  [$t get $n char]
    set tch [quote'tcl    $ch]
    set pch [quote'tclstr $ch]

    SynthTerminal $n [list ict_match_token $tch] $pch
    return
}

proc ::page::compiler::peg::mecpu::SynthNode/n {n} {
    upvar 1 t t g g

    # Nonterminal node. Primitive matching.
    # The code is parameterized by acc(X) of this node X, and gen(D)
    # of the invoked nonterminal D.

    set sym   [$t get $n sym]
    set def   [$t get $n def]

    gas::begin $g $n okfail call'$sym'

    if {$def eq ""} {
	# Invokation of an undefined nonterminal. This will always fail.

	Note "Match for undefined symbol '$sym'"
	Cmdd iok_fail ; /Fail ; Exit
	gas::done --> $t

    } else {
	# Combinations
	# Acc Gen Action
	# --- --- ------
	#   0   0 Plain match
	#   0   1 Match with canceling of the semantic value.
	#   1   0 Plain match
	#   1   1 Plain match
	# --- --- ------

	if {[$t get $n acc] || ![$t get $def gen]} {
	    Cmd icf_ntcall sym_$sym ; /Label CALL
	    /Ok   ; Exit
	    /Fail ; Exit

	} else {
	    Cmd ias_mark
	    Cmd icf_ntcall sym_$sym ; /Label CALL
	    Cmd ias_mrewind
	    /Ok   ; Exit
	    /Fail ; Exit
	}

	set caller [Who CALL]
	gas::done --> $t

	$t lappend $def gas::callers $caller
	$t lappend root gas::called  $def
    }

    return
}

proc ::page::compiler::peg::mecpu::SynthLookahead {n negated} {
    upvar 1 g g t t

    # Note: Per the rules about expression modes (! is a lookahead
    # ____| operator) this node has a mode of 'discard', and its child
    # ____| has so as well.

    # assert t get n  mode == discard
    # assert t get pe mode == discard

    set op       [$t get $n op]
    set pe       [lindex [$t children $n] 0]
    set eop      [$t get $pe op]

    # -> icl_push -> (*) -ok--> icl_rewind -> OK
    #                 \--fail-> icl_rewind -> FAIL

    # -> icl_push -> (*) -ok--> icl_rewind -> iok_negate -> FAIL
    #                 \--fail-> icl_rewind -> iok_negate -> OK

    gas::begin $g $n okfail [expr {$negated ? "!" : "&"}]

    Cmd icl_push
    Inline $t $pe subexpr

    /Ok
    Cmd icl_rewind
    if {$negated} { Cmd iok_negate ; /Fail } else /Ok ; Exit

    /At subexpr/exit/fail ; /Fail
    Cmd icl_rewind
    if {$negated} { Cmd iok_negate ; /Ok } else /Fail ; Exit

    gas::done --> $t
    return
}

proc ::page::compiler::peg::mecpu::SynthClass {n op} {
    upvar 1 t t g g
    SynthTerminal $n [list ict_match_tokclass $op] <$op>
    return
}

proc ::page::compiler::peg::mecpu::SynthTerminal {n cmd msg} {
    upvar 1 t t g g

    # 4 cases (+/- cmd, +/- sv).
    #
    # (A) +cmd+sv
    #     entry -> advance -ok-> match -ok-> sv -> OK
    #              \             \
    #               \             \-fail----------> FAIL
    #                \-fail----------------------/
    #
    # (B) -cmd+sv
    #     entry -> advance -ok-> sv -> OK
    #              \
    #               \-fail-----------> FAIL
    #
    # (C) +cmd-sv
    #     entry -> advance -ok-> match -ok-> OK
    #              \             \
    #               \             \-fail---> FAIL
    #                \-fail---------------/
    #
    # (D) -cmd-sv
    #     entry -> advance -ok-> OK
    #              \
    #               \-fail-----> FAIL

    gas::begin $g $n okfail M'[lindex $cmd 0]

    Cmd ict_advance "Expected $msg (got EOF)"
    /Fail ; Exit
    /Ok

    if {[llength $cmd]} {
	lappend cmd "Expected $msg"
	eval [linsert $cmd 0 Cmd]
	/Fail ; Exit
	/Ok
    }

    if {[$t get $n gen]} {
	Cmd isv_terminal
	/Ok
    }

    Exit

    gas::done --> $t
    return
}

# ### ### ### ######### ######### #########
## Internal. Extending the graph of instructions (expression
## framework, new instructions, (un)conditional sequencing).

# ### ### ### ######### ######### #########
## Internal. Working on the graph of instructions.

proc ::page::compiler::peg::mecpu::2code {t g} {
    page_info "* Generating ME assembler code"

    set insn  {}
    set start [$t get root gas::entry]
    set cat 0
    set calls [list $start]

    while {$cat < [llength $calls]} {
	set  now [lindex $calls $cat]
	incr cat

	set at 0
	set pending [list $now]

	while {$at < [llength $pending]} {
	    set  current [lindex $pending $at]
	    incr at

	    while {$current ne ""} {
		if {[$g node keyexists $current WRITTEN]} break

		insn $g $current insn
		$g node set $current WRITTEN .

		if {[$g node keyexists $current SAVE]} {
		    lappend pending [$g node get $current SAVE]
		}
		if {[$g node keyexists $current CALL]} {
		    lappend calls [$g node get $current CALL]
		}

		set  current [$g node get $current NEXT]
		if {$current eq ""} break
		if {[$g node keyexists $current WRITTEN]} {
		    lappend insn [list {} icf_jalways \
			    [$g node get $current LABEL]]
		    break
		}

		# Process the following instruction,
		# if there is any.
	    }
	}
    }

    return $insn
}

proc ::page::compiler::peg::mecpu::insn {g current iv} {
    upvar 1 $iv insn

    set code [$g node get $current instruction]
    set args [$g node get $current arguments]

    set label {}
    if {[$g node keyexists $current LABEL]} {
	set label [$g node get $current LABEL]
    }

    lappend insn [linsert $args 0 $label $code]
    return
}

if 0 {
    if {[lindex $ins 0] eq "icf_ntcall"} {
	set tmp {}
	foreach b $branches {
	    if {[$g node keyexists $b START]} {
		set sym [$g node get $b symbol]
		lappend ins     sym_$sym
	    } else {
		lappend tmp $b
	    }
	}
	set branches $tmp
    }
}

# ### ### ### ######### ######### #########
## Optimizations.
#
## I. Remove all nodes which are not connected to anything.
##    There should be none.

proc ::page::compiler::peg::mecpu::remove_unconnected {g} {
    page_info "* Remove unconnected instructions"

    foreach n [$g nodes] {
	if {[$g node degree $n] == 0} {
	    page_error "$n ([printinsn $g $n])"
	    page_error "Found unconnected node. This should not have happened."
	    page_error "Removing the bad node."

	    $g node delete $n
	}
    }
}

proc ::page::compiler::peg::mecpu::remove_dead {g} {
    page_info "* Remove dead instructions"

    set count 0
    set runs 0
    set hasdead 1
    while {$hasdead} {
	set hasdead 0
	foreach n [$g nodes] {
	    if {[$g node keyexists $n START]} continue
	    if {[$g node degree -in $n] > 0}  continue

	    page_log_info "    [np $n] removed, dead ([printinsn $g $n])"

	    $g node delete $n

	    set hasdead 1
	    incr count
	}
	incr runs
    }

    page_info "  Removed [plural $count instruction] in [plural $runs run]"
    return
}

# ### ### ### ######### ######### #########
## Optimizations.
#
## II. We have lots of .NOP instructions in the control flow, as part
##     of the framework. They made the handling of expressions easier,
##     providing clear and fixed anchor nodes to connect to from
##     inside and outside, but are rather like the epsilon-transitions
##     in a (D,N)FA. Now is the time to get rid of them.
#
##     We keep the .C'omments, and explicit .BRA'nches.
##     We should not have any .NOP which is a dead-end (without
##     successor), nor should we find .NOPs with more than one
##     successor. The latter should have been .BRA'nches. Both
##     situations are reported on. Dead-ends we
##     remove. Multi-destination NOPs we keep.
#
##     Without the nops in place to confus the flow we can perform a
##     series peep-hole optimizations to merge/split branches.

proc ::page::compiler::peg::mecpu::denop {g} {
    # Remove the .NOPs and reroute control flow. We keep the pseudo
    # instructions for comments (.C) and the explicit branch points
    # (.BRA).

    page_info "* Removing the helper .NOP instructions."

    set count 0
    foreach n [$g nodes] {
	# Skip over nodes already deleted by a previous iteration.
	if {[$g node get $n instruction] ne ".NOP"} continue

	# We keep branching .NOPs, and warn user. There shouldn't be
	# any. such should explicit bnrachpoints.

	set destinations [$g arcs -out $n]

	if {[llength $destinations] > 1} {
	    page_error "$n ([printinsn $g $n])"
	    page_error "Found a .NOP with more than one destination."
	    page_error "This should have been a .BRA instruction."
	    page_error "Not removed. Internal error. Fix the transformation."
	    continue
	}

	# Nops without a destination, dead-end's are not wanted. They
	# should not exist either too. We will do a general dead-end
	# and dead-start removal as well.

	if {[llength $destinations] < 1} {
	    page_error "$n ([printinsn $g $n])"
	    page_error "Found a .NOP without any destination, i.e. a dead end."
	    page_error "This should not have happened. Removed the node."

	    $g node delete $n
	    continue
	}

	page_log_info "    [np $n] removed, updated cflow ([printinsn $g $n])"

	# As there is exactly one destination we can now reroute all
	# incoming arcs around the nop to the new destination.

	set target [$g arc target [lindex $destinations 0]]
	foreach a [$g arcs -in $n] {
	    $g arc move-target $a $target
	}

	$g node delete $n
	incr count
    }

    page_info "  Removed [plural $count instruction]"
    return
}


# ### ### ### ######### ######### #########
## Optimizations.
#

# Merge parallel arcs (remove one, make the other unconditional).

proc ::page::compiler::peg::mecpu::parcmerge {g} {
    page_info "* Search for identical parallel arcs and merge them"

    #puts [join  [info loaded] \n] /seg.fault induced with tcllibc! - tree!

    set count 0
    foreach n [$g nodes] {
	set arcs [$g arcs -out $n]

	if {[llength $arcs] < 2} continue
	if {[llength $arcs] > 2} {
	    page_error "  $n ([printinsn $g $n])"
	    page_error "  Instruction has more than two destinations."
	    page_error "  That is not possible. Internal error."
	    continue
	}
	# Two way branch. Both targets the same ?

	foreach {a b} $arcs break

	if {[$g arc target $a] ne [$g arc target $b]} continue

	page_log_info "    [np $n] outbound arcs merged ([printinsn $g $n])"

	$g arc set $a condition always
	$g arc delete $b

	incr count 2
    }

    page_info "  Merged [plural $count arc]"
    return
}

# Use knowledge of the match status before and after an instruction to
# label the arcs a bit better (This may guide the forward and backward
# merging.).

# Forward merging of instructions.
# An ok/fail decision is done as late as possible.
#
#  /- ok ---> Y -> U               /- ok ---> U
# X                    ==>   X -> Y
#  \- fail -> Y -> V               \- fail -> V

# The Y must not have additional inputs. This more complex case we
# will look at later.

proc ::page::compiler::peg::mecpu::forwmerge {g} {
    page_info "* Forward merging of identical instructions"
    page_info "  Delaying decisions"
    set count 0
    set runs 0

    set merged 1
    while {$merged} {
	set merged 0
	foreach n [$g nodes] {
	    # Skip nodes already killed in previous rounds.
	    if {![$g node exists $n]} continue

	    set outbound [$g arcs -out $n]
	    if {[llength $outbound] != 2} continue

	    foreach {aa ab} $outbound break
	    set na [$g arc target $aa]
	    set nb [$g arc target $ab]

	    set ia [$g node get $na instruction][$g node get $na arguments]
	    set ib [$g node get $nb instruction][$g node get $nb arguments]
	    if {$ia ne $ib} continue

	    # Additional condition: Inbounds in the targets not > 1

	    if {([$g node degree -in $na] > 1) ||
		([$g node degree -in $nb] > 1)} continue

	    page_log_info "    /Merge [np $n] : [np $na] <- [np $nb] ([printinsn $g $na])"

	    # Label all arcs out of na with the condition of the arc
	    # into it.  Ditto for the arcs out of nb. The latter also
	    # get na as their new origin. The arcs out of n relabeled
	    # to always. The nb is deleted. This creates the desired
	    # control structure without having to create a new node
	    # and filling it. We simply use na, discard nb, and
	    # properly rewrite the arcs to have the correct
	    # conditions.

	    foreach a [$g arcs -out $na] {
		$g arc set $a condition [$g arc get $aa condition]
	    }
	    foreach a [$g arcs -out $nb] {
		$g arc set $a condition [$g arc get $ab condition]
		$g arc move-source $a $na
	    }
	    $g arc set     $aa condition always
	    $g node delete $nb
	    set merged 1
	    incr count
	}
	incr runs
    }

    # NOTE: This may require a parallel arc merge, with identification
    #       of merge-able arcs based on the arc condition, i.e. labeling.

    page_info "  Merged [plural $count instruction] in [plural $runs run]"
    return
}

# Backward merging of instructions.
# Common backends are put together.
#
# U -> Y ->\             U ->\
#           -> X   ==>        -> Y -> X
# V -> Y ->/             V ->/

# Note. It is possible for an instruction to be amenable to both for-
# and backward merging. No heuristics are known to decide which is
# better.

proc ::page::compiler::peg::mecpu::backmerge {g} {
    page_info "* Backward merging of identical instructions"
    page_info "  Unifying paths"
    set count 0
    set runs 0

    set merged 1
    while {$merged} {
	set merged 0
	foreach n [$g nodes] {
	    # Skip nodes already killed in previous rounds.
	    if {![$g node exists $n]} continue

	    set inbound [$g arcs -in $n]
	    if {[llength $inbound] < 2} continue

	    # We have more than 1 inbound arcs on this node. Check all
	    # pairs of pre-decessors for possible unification.

	    # Additional condition: Outbounds in the targets not > 1
	    # We check in different levels, to avoid redundant calls.

	    while {[llength $inbound] > 2} {
		set aa   [lindex $inbound 0]
		set tail [lrange $inbound 1 end]

		set na [$g arc source $aa]
		if {[$g node degree -out $na] > 1} {
		    set inbound $tail
		    continue
		}

		set inbound {}
		foreach ab $tail {
		    set nb [$g arc source $ab]
		    if {[$g node degree -out $nb] > 1} continue

		    set ia [$g node get $na instruction][$g node get $na arguments]
		    set ib [$g node get $nb instruction][$g node get $nb arguments]

		    if {$ia ne $ib} {
			lappend inbound $ab
			continue
		    }

		    page_log_info "    \\Merge [np $n] : [np $na] <- [np $nb] ([printinsn $g $na])"

		    # Discard the second node in the pair. Move all
		    # arcs inbound into it so that they reach the
		    # first node instead.

		    foreach a [$g arcs -in $nb] {$g arc move-target $a $na}
		    $g node delete $nb
		    set merged 1
		    incr count
		}
	    }
	}
	incr runs
    }

    page_info "  Merged [plural $count instruction] in [plural $runs run]"
    return
}

# ### ### ### ######### ######### #########

proc ::page::compiler::peg::mecpu::pathlengths {g} {
    page_info "* Find maximum length paths"

    set pending [llength [$g nodes]]

    set nodes {}
    set loops {}
    foreach n [$g nodes] {
	$g node set $n WAIT [$g node degree -out $n]
	set insn [$g node get $n instruction]
	if {($insn eq "icf_halt") || ($insn eq "icf_ntreturn")} {
	    lappend nodes $n
	}
	if {[$g node keyexists $n LOOP]} {
	    lappend loops $n
	}
    }

    set level 0
    while {[llength $nodes]} {
	incr pending -[llength $nodes]
	set nodes [closure $g $nodes $level]
	incr level
    }

    if {[llength $loops]} {
	page_info "  Loop levels"

	set nodes $loops
	while {[llength $nodes]} {
	    incr pending -[llength $nodes]
	    set nodes [closure $g $nodes $level]
	    incr level
	}
    }

    if {$pending} {
	page_info  "  Remainder"

	while {$pending} {
	    set nodes {}
	    foreach n [$g nodes] {
		if {[$g node keyexists $n LEVEL]} continue
		if {[$g node get $n WAIT] < [$g node degree -out $n]} {
		    lappend nodes $n
		}
	    }
	    while {[llength $nodes]} {
		incr pending -[llength $nodes]
		set nodes [closure $g $nodes $level]
		incr level
	    }
	}
    }
    return
}

proc ::page::compiler::peg::mecpu::closure {g nodes level} {
    page_log_info "  \[[format %6d $level]\] : $nodes"

    foreach n $nodes {$g node set $n LEVEL $level}

    set tmp {}
    foreach n $nodes {
	foreach pre [$g nodes -in $n] {
	    # Ignore instructions already given a level.
	    if {[$g node keyexists $pre LEVEL]} continue
	    $g node set $pre WAIT [expr {[$g node get $pre WAIT] - 1}]
	    if {[$g node get $pre WAIT] > 0} continue
	    lappend tmp $pre
	}
    }
    return [lsort -uniq -dict $tmp]
}

proc ::page::compiler::peg::mecpu::jumps {g} {
    page_info "* Insert explicit jumps and branches"

    foreach n [$g nodes] {
	# Inbound > 1, at least one is from a jump, so a label is
	# needed.

	if {[llength [$g arcs -in $n]] > 1} {
	    set go bra[string range $n 4 end]
	    $g node set $n LABEL $go
	}

	set darcs [$g arcs -out $n]

	if {[llength $darcs] == 0} {
	    $g node set $n NEXT ""
	    continue
	}

	if {[llength $darcs] == 1} {
	    set da [lindex $darcs 0]
	    set dn [$g arc target $da]

	    if {[$g node get $dn LEVEL] > [$g node get $n LEVEL]} {
		# Flow is backward, an uncond. jump
		# is needed here.

		set go bra[string range $dn 4 end]
		$g node set $dn LABEL $go
		set j [$g node insert]
		$g arc move-target $da $j
		$g node set $j instruction icf_jalways
		$g node set $j arguments   $go

		$g arc insert $j $dn

		$g node set $n NEXT $j
		$g node set $j NEXT ""
	    } else {
		$g node set $n NEXT $dn
	    }
	    continue
	}

	set aok {}
	set afl {}
	foreach a $darcs {
	    if {[$g arc get $a condition] eq "ok"} {
		set aok $a
	    } else {
		set afl $a
	    }
	}
	set nok [$g arc target $aok]
	set nfl [$g arc target $afl]

	if {[$g node get $n instruction] eq "inc_restore"} {
	    set go bra[string range $nok 4 end]
	    $g node set $nok LABEL $go

	    $g node set $n NEXT $nfl
	    $g node set $n SAVE $nok

	    $g node set $n arguments [linsert [$g node get $n arguments] 0 $go]
	    continue
	}

	if {[$g node get $n instruction] ne ".BRA"} {
	    set bra [$g node insert]
	    $g arc move-source $aok $bra
	    $g arc move-source $afl $bra
	    $g arc insert $n $bra
	    $g node set $n NEXT $bra
	    set n $bra
	}

	if {[$g node get $nok LEVEL] > [$g node get $nfl LEVEL]} {
	    # Ok branch is direct, Fail is jump.

	    $g node set $n NEXT $nok
	    $g node set $n SAVE $nfl

	    set go bra[string range $nfl 4 end]
	    $g node set $nfl LABEL $go
	    $g node set $n instruction icf_jfail
	    $g node set $n arguments   $go
	} else {

	    # Fail branch is direct, Ok is jump.

	    $g node set $n NEXT $nfl
	    $g node set $n SAVE $nok

	    set go bra[string range $nok 4 end]
	    $g node set $nok LABEL $go
	    $g node set $n instruction icf_jok
	    $g node set $n arguments   $go
	}
    }
}

proc ::page::compiler::peg::mecpu::symbols {g t} {
    page_info "* Label subroutine heads"

    # Label and mark the instructions where subroutines begin.
    # These markers are used by 2code to locate all actually
    # used subroutines.

    foreach def [lsort -uniq [$t get root gas::called]] {
	set gdef [$t get $def gas::entry]
	foreach caller [$t get $def gas::callers] {

	    # Skip callers which are gone because of optimizations.
	    if {![$g node exists $caller]} continue

	    $g node set $caller CALL $gdef
	    $g node set $gdef LABEL \
		    [lindex [$g node set $caller arguments] 0]
	}
    }
    return
}

# ### ### ### ######### ######### #########

proc ::page::compiler::peg::mecpu::statistics {code} {
    return
    # disabled
    page_info "* Statistics"
    statistics_si $code

    # All higher order statistics are done only on the instructions in
    # a basic block, i.e. a linear sequence. We are looking for
    # high-probability blocks in itself, and then also for
    # high-probability partials.

    set blocks [basicblocks $code]

    # Basic basic block statistics (full blocks)

    Init bl
    foreach b $blocks {Incr bl($b)}
    wrstat  bl asm/statistics_bb.txt
    wrstatk bl asm/statistics_bbk.txt

    # Statistics of all partial blocks, i.e. all possible
    # sub-sequences with length > 1.

    Init ps
    foreach b $blocks {
	for {set s 0} {$s < [llength $b]} {incr s} {
	    for {set e [expr {$s + 1}]} {$e < [llength $b]} {incr e} {
		Incr ps([lrange $b $s $e]) $bl($b)
	    }
	}
    }

    wrstat  ps asm/statistics_ps.txt
    wrstatk ps asm/statistics_psk.txt
    return
}

proc ::page::compiler::peg::mecpu::statistics_si {code} {
    page_info "  Single instruction probabilities."

    # What are the most used instructions, statically speaking,
    # without considering context ?

    Init si
    foreach i $code {
	foreach {label name} $i break
	if {$name eq ".C"} continue
	Incr si($name)
    }

    wrstat si asm/statistics_si.txt
    return
}

proc ::page::compiler::peg::mecpu::Init {v} {
    upvar 1 $v var total total
    array set var {}
    set total 0
    return
}

proc ::page::compiler::peg::mecpu::Incr {v {n 1}} {
    upvar 1 $v var total total
    if {![info exists var]} {set var $n ; incr total ; return}
    incr var $n
    incr total $n
    return
}

proc ::page::compiler::peg::mecpu::wrstat {bv file} {
    upvar 1 $bv buckets total total

    set tmp  {}
    foreach {name count} [array get buckets] {
	lappend tmp [list $name $count]
    }

    set     lines {}
    lappend lines "Total: $total"

    set half [expr {$total / 2}]
    set down $total

    foreach item [lsort -index 1 -decreasing -integer [lsort -index 0 $tmp]] {
	foreach {key count} $item break

	set percent [format %6.2f [expr {$count*100.0/$total}]]%
	set fcount  [format %8d $count]

	lappend lines "  $fcount $percent $key"
	incr down -$count
	if {$half && ($down < $half)} {
	    lappend lines **
	    set half 0
	}
    }

    write $file [join $lines \n]\n
    return
}

proc ::page::compiler::peg::mecpu::wrstatk {bv file} {
    upvar 1 $bv buckets total total

    set tmp  {}
    foreach {name count} [array get buckets] {
	lappend tmp [list $name $count]
    }

    set     lines {}
    lappend lines "Total: $total"

    set half [expr {$total / 2}]
    set down $total

    foreach item  [lsort -index 0 [lsort -index 1 -decreasing -integer $tmp]] {
	foreach {key count} $item break

	set percent [format %6.2f [expr {$count*100.0/$total}]]%
	set fcount  [format %8d $count]

	lappend lines "  $fcount $percent $key"
	incr down -$count
	if {$down < $half} {
	    lappend lines **
	    set half -1
	}
    }

    write $file [join $lines \n]\n
    return
}

proc ::page::compiler::peg::mecpu::basicblocks {code} {
    set blocks {}
    set block {}

    foreach i $code {
	foreach {label name} $i break
	if {
	    ($name eq ".C")          ||
	    ($name eq "icf_jok")     ||
	    ($name eq "icf_jfail")   ||
	    ($name eq "icf_jalways") ||
	    ($name eq "icf_ntreturn")
	} {
	    # Jumps stop a block, and are not put into the block
	    # Except if the block is of length 1. Then it is of
	    # interest to see if certain combinations are used
	    # often.

	    if {[llength $block]} {
		if {[llength $block] == 1} {lappend block $name}
		lappend blocks $block
	    }
	    set block {}
	    continue
	} elseif {$label ne ""} {
	    # A labeled instruction starts a new block and belongs to
	    # it. Note that the previous block is saved only if it is
	    # of length > 1. A single instruction block is not
	    # something we can optimize.

	    if {[llength $block] > 1} {lappend blocks $block}
	    set block [list $name]
	    continue
	}
	# Extend current block
	lappend block $name
    }

    if {[llength $block]} {lappend blocks $block}
    return $blocks
}

# ### ### ### ######### ######### #########

proc ::page::compiler::peg::mecpu::printinsn {g n} {
    return "[$g node get $n instruction] <[$g node get $n arguments]>"
}

proc ::page::compiler::peg::mecpu::plural {n prefix} {
    return "$n ${prefix}[expr {$n == 1 ? "" : "s"}]"
}

proc ::page::compiler::peg::mecpu::np {n} {
    format %-*s 8 $n
}

proc ::page::compiler::peg::mecpu::status {g} {
    page_info "[plural [llength [$g nodes]] instruction]"
    return
}

proc ::page::compiler::peg::mecpu::gdump {g file} {
    return
    # disabled
    variable gnext
    page_info "  %% Saving graph to \"$file\" %%"
    write asm/[format %02d $gnext]_${file}.sgr [$g serialize]
    incr gnext
    return
}

# ### ### ### ######### ######### #########
## Internal. Strings.

namespace eval ::page::compiler::peg::mecpu {
    variable gnext 0
}

# ### ### ### ######### ######### #########
## Ready

package provide page::compiler::peg::mecpu 0.1.1
