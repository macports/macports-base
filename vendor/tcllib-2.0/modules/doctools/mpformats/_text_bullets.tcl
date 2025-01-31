# -*- tcl -*-
#
# Copyright (c) 2019 Andreas Kupries <andreas_kupries@sourceforge.net>
# Freely redistributable.
#
# _text_bullets.tcl -- Bulleting configuration and use.

global itembullets      ; set itembullets      {* - # @ ~ %}
global enumbullets      ; set enumbullets      {[%] (%) <%>}

proc IB  {}        { global itembullets ; return $itembullets      }
proc EB  {}        { global enumbullets ; return $enumbullets      }
proc DIB {bullets} { global itembullets ; set itembullets $bullets }
proc DEB {bullets} { global enumbullets ; set enumbullets $bullets }

proc NB {bullets countervar} {
    upvar 1 $countervar counter
    set bullet  [lindex $bullets $counter]
    set counter [expr {($counter + 1) % [llength $bullets]}]
    return $bullet
}

proc ItemBullet {countervar} { upvar 1 $countervar counter ; NB [IB] counter }
proc EnumBullet {countervar} { upvar 1 $countervar counter ; NB [EB] counter }

# xref current content
proc IBullet {} { ItemBullet [CAttrRef itembullet] }
proc EBullet {} { EnumBullet [CAttrRef enumbullet] }

return
