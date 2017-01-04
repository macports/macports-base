# -*- tcl -*-
# ### ### ### ######### ######### #########
## Package description

## (struct::)Graph based ME Assembler, for use in grammar
## translations.

# ### ### ### ######### ######### #########
## Requisites

namespace eval grammar::me::cpu::gasm {}

# ### ### ### ######### ######### #########
## Implementation

proc ::grammar::me::cpu::gasm::begin {g n {mode okfail} {note {}}} {
    variable    gas
    array unset gas *

    # (Re)initialize the assmebler state, create the framework nodes
    # upon which we will hang all instructions on.

    set         gas(mode) $mode
    set         gas(node) $n
    set         gas(grap) $g
    array set   gas {last {} cond always}

    Nop $note           ; /Label entry ; /Clear
    if {$mode eq "okfail"} {
	Nop Exit'OK     ; /Label exit/ok     ; /Clear
	Nop Exit'FAIL   ; /Label exit/fail   ; /Clear
    } elseif {$mode eq "halt"} {
	Cmd icf_halt     ; /Label exit/return ; /Clear
    } else {
	Cmd icf_ntreturn ; /Label exit/return ; /Clear
    }

    /At entry
    return
}

proc ::grammar::me::cpu::gasm::done {__ t} {
    variable gas

    # Save the framework nodes in a grammar tree and shut the
    # assembler down.

    $t set $gas(node) gas::entry $gas(_entry)

    if {$gas(mode) eq "okfail"} {
	$t set $gas(node) gas::exit::ok   $gas(_exit/ok)
	$t set $gas(node) gas::exit::fail $gas(_exit/fail)
    } else {
	$t set $gas(node) gas::exit $gas(_exit/return)
    }

    # Remember the node in the grammar tree which is responsible for
    # this entry point.

    $gas(grap) node set $gas(_entry) expr $gas(node)

    array unset gas *
    return
}

proc ::grammar::me::cpu::gasm::lift {t dst __ src} {

    $t set $dst gas::entry      [$t get $src gas::entry]
    $t set $dst gas::exit::ok   [$t get $src gas::exit::ok]
    $t set $dst gas::exit::fail [$t get $src gas::exit::fail]
    return
}

proc ::grammar::me::cpu::gasm::state {} {
    variable gas
    return [array get gas]
}

proc ::grammar::me::cpu::gasm::state! {s} {
    variable  gas
    array set gas $s
}

proc ::grammar::me::cpu::gasm::Inline {t node label} {
    variable gas

    set gas(_${label}/entry)     [$t get $node gas::entry]
    set gas(_${label}/exit/ok)   [$t get $node gas::exit::ok]
    set gas(_${label}/exit/fail) [$t get $node gas::exit::fail]

    __Link $gas(_${label}/entry) $gas(cond)
    /At    ${label}/exit/ok
    return
}

proc ::grammar::me::cpu::gasm::Cmd {cmd args} {
    variable gas

    # Add a new instruction, and link it to the anchor. The created
    # instruction becomes the new anchor.

    upvar 0 gas(grap) g gas(last) anchor gas(cond) cond

    set node [$g node insert]
    $g  node set $node instruction $cmd
    $g  node set $node arguments   $args

    if {$anchor ne ""} {__Link $node $cond}

    set anchor $node
    set cond   always
    return
}

proc ::grammar::me::cpu::gasm::Bra {} {
    Cmd .BRA
}

proc ::grammar::me::cpu::gasm::Nop {{text {}}} {
    Cmd .NOP $text
}

proc ::grammar::me::cpu::gasm::Note {text} {
    Cmd .C $text
}

proc ::grammar::me::cpu::gasm::Jmp {label} {
    variable gas
    __Link $gas(_$label) $gas(cond)
    return
}

proc ::grammar::me::cpu::gasm::Exit {} {
    variable gas
    if {$gas(mode) eq "okfail"} {
	__Link $gas(_exit/$gas(cond)) $gas(cond)
    } else {
	__Link $gas(_exit/return) always
    }
    return
}

proc ::grammar::me::cpu::gasm::Who {label} {
    variable gas
    return  $gas(_$label)
}

proc ::grammar::me::cpu::gasm::__Link {to cond} {
    variable gas
    upvar 0 gas(grap) g gas(last) anchor

    set arc [$g arc insert $anchor $to]
    $g  arc set $arc condition $cond
    return
}

proc ::grammar::me::cpu::gasm::/Label {name} {
    variable gas
    set gas(_$name) $gas(last)
    return
}

proc ::grammar::me::cpu::gasm::/Clear {} {
    variable gas
    set gas(last) {}
    set gas(cond) always
    return
}

proc ::grammar::me::cpu::gasm::/Ok {} {
    variable gas
    set gas(cond) ok
    return
}

proc ::grammar::me::cpu::gasm::/Fail {} {
    variable gas
    set gas(cond) fail
    return
}

proc ::grammar::me::cpu::gasm::/At {name} {
    variable gas
    set gas(last) $gas(_$name)
    set gas(cond) always
    return
}

proc ::grammar::me::cpu::gasm::/CloseLoop {} {
    variable gas
    $gas(grap) node set $gas(last) LOOP .
    return
}

# ### ### ### ######### ######### #########
## Interfacing

namespace eval grammar::me::cpu::gasm {
    namespace export begin done lift state state!
    namespace export Inline Cmd Bra Nop Note Jmp Exit Who
    namespace export /Label /Clear /Ok /Fail /At /CloseLoop
}

# ### ### ### ######### ######### #########
## Ready

package provide grammar::me::cpu::gasm 0.1
