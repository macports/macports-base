# -*- tcl -*-
# STUBS handling -- Code generation framework.
#
# (c) 2011,2022-2023 Andreas Kupries http://wiki.tcl.tk/andreas%20kupries

# A stubs table is represented by a dictionary value.
# A gen is a variable holding a stubs table value.

# # ## ### ##### ######## #############
## Requisites

package require Tcl 8.6 9
package require stubs::container

namespace eval ::stubs::gen::c {
    namespace import ::stubs::container::*
}

# # ## ### ##### ######## #############
## Implementation.

proc ::stubs::gen::warn {cmdprefix} {
    variable warnCmd $cmdprefix
    return
}

proc ::stubs::gen::uncap {text} {
    return [string tolower [string index $text 0]][string range $text 1 end]
}

proc ::stubs::gen::cap {text} {
    return [string toupper [string index $text 0]][string range $text 1 end]
}

proc ::stubs::gen::forall {table name emitCmd onAll {skipString {}}} {
    if {$skipString eq {}} {
	#checker exclude warnArgWrite
	set skipString "/* Slot @@ is reserved */\n"
    }

    set platforms [c::platforms $table $name]

    if {[lsearch -exact $platforms "generic"] >= 0} {
	# Emit integrated stubs block
	set lastNum [MAX [c::lastof $table $name]]

	for {set i 0} {$i <= $lastNum} {incr i} {

	    set slots [c::slotplatforms $table $name $i]
	    set emit 0
	    if {[lsearch -exact $slots "generic"] >= 0} {
		if {[llength $slots] > 1} {
		    WARN {conflicting generic and platform entries: $name $i}
		}

		append text [CALL generic $i]
		set emit 1

	    } elseif {[llength $slots] > 0} {

		array set slot {unix 0 x11 0 win 0 macosx 0 aqua 0}
		foreach s $slots { set slot($s) 1 }
		# "aqua", "macosx" and "x11" are special cases:
		# "macosx" implies "unix", "aqua" implies "macosx" and "x11"
		# implies "unix", so we need to be careful not to emit
		# duplicate stubs entries:
		if {($slot(unix) && $slot(macosx)) ||
		    (($slot(unix) || $slot(macosx)) &&
		     ($slot(x11)  || $slot(aqua)))} {
		    WARN {conflicting platform entries: $name $i}
		}
		## unix ##
		set temp {}
		set plat unix
		if {!$slot(aqua) && !$slot(x11)} {
		    if {$slot($plat)} {
			append temp [CALL $plat $i]
		    } elseif {$onAll} {
			append temp [SKIP]
		    }
		}
		if {$temp ne ""} {
		    append text [AddPlatformGuard $plat $temp]
		    set emit 1
		}
		## x11 ##
		set temp {}
		set plat x11
		if {!$slot(unix) && !$slot(macosx)} {
		    if {$slot($plat)} {
			append temp [CALL $plat $i]
		    } elseif {$onAll} {
			append temp [SKIP]
		    }
		}
		if {$temp ne ""} {
		    append text [AddPlatformGuard $plat $temp]
		    set emit 1
		}
		## win ##
		set temp {}
		set plat win
		if {$slot($plat)} {
		    append temp [CALL $plat $i]
		} elseif {$onAll} {
		    append temp [SKIP]
		}
		if {$temp ne ""} {
		    append text [AddPlatformGuard $plat $temp]
		    set emit 1
		}
		## macosx ##
		set temp {}
		set plat macosx
		if {!$slot(aqua) && !$slot(x11)} {
		    if {$slot($plat)} {
			append temp [CALL $plat $i]
		    } elseif {$slot(unix)} {
			append temp [CALL unix $i]
		    } elseif {$onAll} {
			append temp [SKIP]
		    }
		}
		if {$temp ne ""} {
		    append text [AddPlatformGuard $plat $temp]
		    set emit 1
		}
		## aqua ##
		set temp {}
		set plat aqua
		if {!$slot(unix) && !$slot(macosx)} {
		    if {[string range $skipString 0 1] ne "/*"} {
			# The code previously had a bug here causing
			# it to erroneously generate both a unix entry
			# and an aqua entry for a given stubs table
			# slot. To preserve backwards compatibility,
			# generate a dummy stubs entry before every
			# aqua entry (note that this breaks the
			# correspondence between emitted entry number
			# and actual position of the entry in the
			# stubs table, e.g.  TkIntStubs entry 113 for
			# aqua is in fact at position 114 in the
			# table, entry 114 at position 116 etc).
			append temp [SKIP]
			CHOP temp
			append temp " /*\
				Dummy entry for stubs table backwards\
				compatibility */\n"
		    }
		    if {$slot($plat)} {
			append temp [CALL $plat $i]
		    } elseif {$onAll} {
			append temp [SKIP]
		    }
		}
		if {$temp ne ""} {
		    append text [AddPlatformGuard $plat $temp]
		    set emit 1
		}
	    }
	    if {!$emit} {
		append text [SKIP]
	    }
	}
    } else {
	# Emit separate stubs blocks per platform
	array set block {unix 0 x11 0 win 0 macosx 0 aqua 0}
	foreach s $platforms { set block($s) 1 }

	## unix ##
	if {$block(unix) && !$block(x11)} {
	    set temp {}
	    set plat unix

	    # (1) put into helper method
	    set lastNum [c::lastof $table $name $plat]
	    for {set i 0} {$i <= $lastNum} {incr i} {
		if {[c::slot? $table $name $plat $i]} {
		    append temp [CALL $plat $i]
		} else {
		    append temp [SKIP]
		}
	    }
	    append text [AddPlatformGuard $plat $temp]
	}
	## win ##
	if {$block(win)} {
	    set temp {}
	    set plat win

	    # (1) put into helper method
	    set lastNum [c::lastof $table $name $plat]
	    for {set i 0} {$i <= $lastNum} {incr i} {
		if {[c::slot? $table $name $plat $i]} {
		    append temp [CALL $plat $i]
		} else {
		    append temp [SKIP]
		}
	    }
	    append text [AddPlatformGuard $plat $temp]
	}
	## macosx ##
	if {$block(macosx) && !$block(aqua) && !$block(x11)} {
	    set temp {}
	    set lastNum [MAX [list \
				  [c::lastof $table $name unix] \
				  [c::lastof $table $name macosx]]]

	    for {set i 0} {$i <= $lastNum} {incr i} {
		set emit 0
		foreach plat {unix macosx} {
		    if {[c::slot? $table $name $plat $i]} {
			append temp [CALL $plat $i]
			set emit 1
			break
		    }
		}
		if {!$emit} {
		    append temp [SKIP]
		}
	    }
	    append text [AddPlatformGuard macosx $temp]
	}
	## aqua ##
	if {$block(aqua)} {
	    set temp {}
	    set lastNum [MAX [list \
				  [c::lastof $table $name unix] \
				  [c::lastof $table $name macosx] \
				  [c::lastof $table $name aqua]]]

	    for {set i 0} {$i <= $lastNum} {incr i} {
		set emit 0
		foreach plat {unix macosx aqua} {
		    if {[c::slot? $table $name $plat $i]} {
			append temp [CALL $plat $i]
			set emit 1
			break
		    }
		}
		if {!$emit} {
		    append temp [SKIP]
		}
	    }
	    append text [AddPlatformGuard aqua $temp]
	}
	## x11 ##
	if {$block(x11)} {
	    set temp {}
	    set lastNum [MAX [list \
				  [c::lastof $table $name unix] \
				  [c::lastof $table $name macosx] \
				  [c::lastof $table $name x11]]]

	    for {set i 0} {$i <= $lastNum} {incr i} {
		set emit 0
		foreach plat {unix macosx x11} {
		    if {[c::slot? $table $name $plat $i]} {
			if {$plat ne "macosx"} {
			    append temp [CALL $plat $i]
			} else {
			    append temp [AddPlatformGuard $plat \
					     [CALL $plat $i] \
					     [SKIP]]
			}
			set emit 1
			break
		    }
		}
		if {!$emit} {
		    append temp [SKIP]
		}
	    }
	    append text [AddPlatformGuard x11 $temp]
	}
    }

    return $text
}

proc ::stubs::gen::rewrite {path newcode} {
    if {![file exists $path]} {
	return -code error "Cannot find file: $path"
    }

    set in  [open ${path}     r]
    set out [open ${path}.new w]

    # Hardwired use of unix line-endings in the output.
    fconfigure $out -translation lf

    # Copy the file header before the code section.
    while {![eof $in]} {
	set line [gets $in]
	if {[string match "*!BEGIN!*" $line]} break
	puts $out $line
    }

    puts $out "/* !BEGIN!: Do not edit below this line. */"

    # Insert the new code.
    puts $out $newcode

    # Skip over the input until the end of the code section.
    while {![eof $in]} {
	set line [gets $in]
	if {[string match "*!END!*" $line]} break
    }

    # Copy the trailer after the code section. This can be done fast,
    # as searching is not required anymore.
    puts $out "/* !END!: Do not edit above this line. */"
    puts -nonewline $out [read $in]

    # Close and commit to the changes (atomic rename).
    close $in
    close $out
    file rename -force -- ${path}.new ${path}
    return
}

# # ## ### #####
## Internal helpers.

proc ::stubs::gen::CALL {platform index} {
    upvar 1 table table name name emitCmd emitCmd
    set decl [c::slot $table $name $platform $index]
    return [uplevel \#0 [linsert $emitCmd end $name $decl $index]]
}

proc ::stubs::gen::WARN {text} {
    variable warnCmd
    if {$warnCmd eq {}} return
    return [uplevel \#0 [linsert $warnCmd end [uplevel 1 [list ::subst $text]]]]
}

proc ::stubs::gen::SKIP {} {
    upvar 1 skipString skipString i i
    #puts stderr SKIP/$i/[string map [list {$i} $i] $skipString]
    return [string map [list @@ $i] $skipString]
}

proc ::stubs::gen::CHOP {textvar} {
    upvar 1 $textvar text
    set text [string range $text 0 end-1]
    return
}

proc ::stubs::gen::AddPlatformGuard {platform iftext {elsetext {}}} {
    variable guard_begin
    variable guard_else
    variable guard_end

    set prefix [expr {![info exists guard_begin($platform)] ? "" : $guard_begin($platform)}]
    set middle [expr {![info exists guard_else($platform)]  ? "" : $guard_else($platform)}]
    set suffix [expr {![info exists guard_end($platform)]   ? "" : $guard_end($platform)}]

    return $prefix$iftext[expr {($elsetext eq "")
				? ""
				: "$middle$elsetext"}]$suffix
}

if {[package vsatisfies [package present Tcl] 8.5]} {
    #checker exclude warnRedefine
    proc ::stubs::gen::MAX {list} {
	return [tcl::mathfunc::max {*}$list]
    }
} else {
    #checker exclude warnRedefine
    proc ::stubs::gen::MAX {list} {
	set max {}
	foreach a $list {
	    if {($max ne {}) && ($max >= $a)} continue
	    set max $a
	}
	return $a
    }
}

# # ## ### #####

namespace eval ::stubs::gen {
    #checker -scope block exclude warnShadowVar
    variable guard_begin
    variable guard_else
    variable guard_end

    array set guard_begin {
	win    "#ifdef __WIN32__ /* WIN */\n"
	unix   "#if !defined(__WIN32__) && !defined(MAC_OSX_TCL) /* UNIX */\n"
	macosx "#ifdef MAC_OSX_TCL /* MACOSX */\n"
	aqua   "#ifdef MAC_OSX_TK /* AQUA */\n"
	x11    "#if !(defined(__WIN32__) || defined(MAC_OSX_TK)) /* X11 */\n"
    }
    array set guard_else {
	win    "#else /* WIN */\n"
	unix   "#else /* UNIX */\n"
	macosx "#else /* MACOSX */\n"
	aqua   "#else /* AQUA */\n"
	x11    "#else /* X11 */\n"
    }
    array set guard_end {
	win    "#endif /* WIN */\n"
	unix   "#endif /* UNIX */\n"
	macosx "#endif /* MACOSX */\n"
	aqua   "#endif /* AQUA */\n"
	x11    "#endif /* X11 */\n"
    }

    # Default command to report conflict and other warnings.
    variable warnCmd {puts stderr}

    namespace export forall rewrite warn cap uncap
}

# # ## ### #####
package provide stubs::gen 1.1.1
return
