# ascaller.tcl - 
#
#       A few utility procs that manage the evaluation of a command
#	or a script in the context of a caller, taking care of all 
#	the ugly details of proper return codes, errorcodes, and
#	a good stack trace in ::errorInfo as appropriate.
# -------------------------------------------------------------------------
#
# RCS: @(#) $Id: ascaller.tcl,v 1.3 2004/01/15 06:36:12 andreas_kupries Exp $

namespace eval ::control {

    proc CommandAsCaller {cmdVar resultVar {where {}} {codeVar code}} {
	set x [expr {[string equal "" $where] 
		? {} : [subst -nobackslashes {\n    ($where)}]}]
	set script [subst -nobackslashes -nocommands {
	    set $codeVar [catch {uplevel 1 $$cmdVar} $resultVar]
	    if {$$codeVar > 1} {
		return -code $$codeVar $$resultVar
	    }
	    if {$$codeVar == 1} {
		if {[string equal {"uplevel 1 $$cmdVar"} \
			[lindex [split [set ::errorInfo] \n] end]]} {
		    set $codeVar [join \
			    [lrange [split [set ::errorInfo] \n] 0 \
			    end-[expr {4+[llength [split $$cmdVar \n]]}]] \n]
		} else {
		    set $codeVar [join \
			    [lrange [split [set ::errorInfo] \n] 0 end-1] \n]
		}
		return -code error -errorcode [set ::errorCode] \
			-errorinfo "$$codeVar$x" $$resultVar
	    }
	}]
	return $script
    }

    proc BodyAsCaller {bodyVar resultVar codeVar {where {}}} {
	set x [expr {[string equal "" $where]
		? {} : [subst -nobackslashes -nocommands \
		{\n    ($where[string map {{    ("uplevel"} {}} \
		[lindex [split [set ::errorInfo] \n] end]]}]}]
	set script [subst -nobackslashes -nocommands {
	    set $codeVar [catch {uplevel 1 $$bodyVar} $resultVar]
	    if {$$codeVar == 1} {
		if {[string equal {"uplevel 1 $$bodyVar"} \
			[lindex [split [set ::errorInfo] \n] end]]} {
		    set ::errorInfo [join \
			    [lrange [split [set ::errorInfo] \n] 0 end-2] \n]
		} 
		set $codeVar [join \
			[lrange [split [set ::errorInfo] \n] 0 end-1] \n]
		return -code error -errorcode [set ::errorCode] \
			-errorinfo "$$codeVar$x" $$resultVar
	    }
	}]
	return $script
    }

    proc ErrorInfoAsCaller {find replace} {
	set info $::errorInfo
	set i [string last "\n    (\"$find" $info]
	if {$i == -1} {return $info}
	set result [string range $info 0 [incr i 6]]	;# keep "\n    (\""
	append result $replace			;# $find -> $replace
	incr i [string length $find]
	set j [string first ) $info [incr i]]	;# keep rest of parenthetical
	append result [string range $info $i $j]
        return $result
    }

}
