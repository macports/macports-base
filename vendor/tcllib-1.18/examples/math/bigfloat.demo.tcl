#!/usr/bin/env tclsh
## -*- tcl -*-

set scriptDir [file dirname [info script]]

########################################################################
# BigFloat for Tcl
# Copyright (C) 2003-2005  ARNOLD Stephane
#
# BIGFLOAT LICENSE TERMS
#
# This software is copyrighted by Stephane ARNOLD, (stephanearnold <at> yahoo.fr).
# The following terms apply to all files associated
# with the software unless explicitly disclaimed in individual files.
#
# The authors hereby grant permission to use, copy, modify, distribute,
# and license this software and its documentation for any purpose, provided
# that existing copyright notices are retained in all copies and that this
# notice is included verbatim in any distributions. No written agreement,
# license, or royalty fee is required for any of the authorized uses.
# Modifications to this software may be copyrighted by their authors
# and need not follow the licensing terms described here, provided that
# the new terms are clearly indicated on the first page of each file where
# they apply.
#
# IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
# FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
# ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
# DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
# IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
# NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
#
# GOVERNMENT USE: If you are acquiring this software on behalf of the
# U.S. government, the Government shall have only "Restricted Rights"
# in the software and related documentation as defined in the Federal
# Acquisition Regulations (FARs) in Clause 52.227.19 (c) (2).  If you
# are acquiring the software on behalf of the Department of Defense, the
# software shall be classified as "Commercial Computer Software" and the
# Government shall have only "Restricted Rights" as defined in Clause
# 252.227-7013 (c) (1) of DFARs.  Notwithstanding the foregoing, the
# authors grant the U.S. Government and others acting in its behalf
# permission to use and distribute the software in accordance with the
# terms specified in this license.
#
########################################################################

package require Tk

package require math::bigfloat
namespace import ::math::bigfloat::*

set nbButtons 0
proc addButton {command} {
    global nbButtons
    set ::buttons($nbButtons,command) _$command
    set ::buttons($nbButtons,texte) $command
    incr nbButtons
}

proc addButtonTwo {commande} {
    addButton $commande
    proc _$commande {} "if {\[catch {pop a} msg\]} {tk_messageBox -message \$msg;return}
    if {\[catch {pop b} msg\]} {push \$a
        tk_messageBox -message \$msg;return}
    if {\[catch {set result \[$commande \$a \$b\]} msg\]} {
        push \$b
        push \$a
        tk_messageBox -message \$msg
        return}
    push \$result"
}


proc addButtonOne {commande} {
    addButton $commande
    proc _$commande {} "if {\[catch {pop a} msg\]} {tk_messageBox -message \$msg;return}
    if {\[catch {set result \[$commande \$a\]} msg\]} {push \$a
        tk_messageBox -message \$msg
        return}
    push \$result"
}


proc drawButtons {} {
    global nbButtons
    set nbLines [expr {int(sqrt($nbButtons))}]
    for {set i 0} {$i<$nbButtons} {incr i} {
        set col [expr {$i%$nbLines}]
        set line [expr {$i/$nbLines}]
        set commande $::buttons($i,command)
        set texte $::buttons($i,texte)
        button .functions.$commande -text $texte -command $commande -width 10
        grid .functions.$commande -column $col -row $line -in .functions
        
    }
}

proc initStack {} {
    foreach i {1 2 3 4} {
        label .stack.l$i -text "[expr {5-$i}] :" -foreground #079 -width 5
        grid .stack.l$i -in .stack -row $i -column 1
        label .stack.n$i -text "Empty" -foreground #097 -width 85
        grid .stack.n$i -in .stack -row $i -column 2
    }
    set ::stack [list]
}

proc Push {} {
    set x [fromstr $::bignum]
    if {![isInt $x]} {
        set x [fromstr $::bignum $::zeros]
    }
    lappend ::stack $x
    set ::bignum 1.00
    set ::zeros 0
}


proc toStr {n} {
    set n [math::bigfloat::tostr $n]
    set resultat ""
    while {[string length $n]>80} {
        append resultat "[string range $n 0 79]...\n"
        set n [string range $n 80 end]
    }
    append resultat $n
}


proc drawStack {args} {
    set l [lrange $::stack end-3 end]
    for {set i 4} {$i>[llength $l]} {incr i -1} {
        .stack.n[expr {5-$i}] configure -text "Empty" -foreground #097
    }
    for {set i 0} {$i<[llength $l]} {incr i} {
        set number [lindex $::stack end-$i]
        .stack.n[expr {4-$i}] configure -text [toStr $number] -foreground #000
    }
}

proc init {} {
    wm title . "BigFloatDemo 1.2"
    # the stack (for RPN)
    frame .stack
    pack .stack
    initStack
    # the commands for input
    set c [frame .commands]
    pack $c -padx 10 -pady 10
    set ::bignum 1.00
    entry $c.bignum -textvariable ::bignum -width 16
    pack $c.bignum -in $c -side left
    label $c.labelZero -text "append zeros"
    pack $c.labelZero -in $c -side left
    set ::zeros 0
    entry $c.zeros -textvariable ::zeros -width 4
    pack $c.zeros -in $c -side left
    button $c.fenter -text "Push" -command Push
    pack $c.fenter -in $c -side left
    # the functions for numbers
    frame .functions
    pack .functions
    set f .functions
    # chaque fonction est associée, d'une part,
    # à un bouton portant un libellé, et d'autre part
    # à une commande Tcl
    # ici nous associons le bouton "add" à la commande "add"
    addButtonTwo add
    # toutes ces commandes se trouvent à la fin de ce fichier
    addButtonTwo sub
    addButtonTwo mul
    addButtonTwo div
    addButtonTwo mod
    addButtonOne opp
    addButtonOne abs
    addButtonOne round
    addButtonOne ceil
    addButtonOne floor
    addButtonTwo pow
    addButtonOne sqrt
    addButtonOne log
    addButtonOne exp
    addButtonOne cos
    addButtonOne sin
    addButtonOne tan
    addButtonOne acos
    addButtonOne asin
    addButtonOne atan
    addButtonOne cotan
    addButtonOne cosh
    addButtonOne sinh
    addButtonOne tanh
    addButtonOne pi
    addButtonOne rad2deg
    addButtonOne deg2rad
    addButtonOne int2float
    addButton del
    addButton swap
    addButton dup
    addButton help
    addButton save
    addButton exit
    drawButtons
    raise .
}

################################################################################
# procedures that corresponds to functions (add,mul,etc.)
################################################################################

proc _save {} {
    set fichier [tk_getSaveFile -filetypes {{{Text Files} {.txt}}} -title "Save the stack as ..."]
    if {$fichier == ""} {
        error "You should give a name to the file. Aborting saving operation. Sorry."
    }
    if {[lindex [split $fichier .] end]!="txt"} {
        append fichier .txt
    }
    if {[catch {set file [open $fichier w]}]} {
        error "Write impossible on file : '$fichier'"
    }
    foreach valeur $::stack {
        puts $file [::math::bigfloat::tostr $valeur]
    }
    close $file
}

proc ShowFile {filename buttonText} {
    if {[catch {toplevel .help}]} {
        tk_messageBox -message "Unable to create the window ; please close the current help window"
        return
    }
    frame .help.licence
    text .help.licence.t -yscrollcommand {.help.licence.s set}
    scrollbar .help.licence.s -command {.help.licence.t yview}
    grid .help.licence.t .help.licence.s -sticky nsew
    grid columnconfigure .help.licence 0 -weight 1
    grid rowconfigure .help.licence 0 -weight 1
    
    pack .help.licence -in .help
    set fd [open $filename]
    .help.licence.t insert 0.0 [read $fd]
    close $fd
    .help.licence.t configure -state disabled
    button .help.bouton -text $buttonText -command {destroy .help;raise .}
    pack .help.bouton -in .help
    focus -force .help
}

proc _help {args} {
    # display some help
    ShowFile [file join $::scriptDir bigfloat.help] Close
}

proc _del {} {
    if {[llength $::stack]<=1} {
        set ::stack {}
    } else  {
        set ::stack [lrange $::stack 0 end-1]
    }
}

proc _swap {} {
    set last [lindex $::stack end]
    lset ::stack end [lindex $::stack end-1]
    lset ::stack end-1 $last
}

# duplicate the last value
proc _dup {} {
    lappend ::stack [lindex $::stack end]
}



proc pop {varname} {
    if {[llength $::stack]==0} {
        error "too few arguments in the stack"
    }
    upvar $varname out
    set out [lindex $::stack end]
    set ::stack [lrange $::stack 0 end-1]
    return
}


proc push {x} {
    lappend ::stack $x
}

proc _exit {} {
    update
    exit
}



# initialize the calculator and create the widgets (GUI)
init
# chaque fois qu'une commande modifie la pile de nombres,
# la commande drawStack sera appelée pour la réactualiser
trace add variable ::stack write drawStack
