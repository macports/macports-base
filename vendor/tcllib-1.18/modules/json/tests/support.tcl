
#use fileutil/fileutil.tcl fileutil

catch {unset JSON}
catch {unset TCL}
catch {unset DICTSORT}

proc dictsort3 {spec data} {
    while [llength $spec] {
        set type [lindex $spec 0]
        set spec [lrange $spec 1 end]
        
        switch -- $type {
            dict {
                lappend spec * string
                
                set json {}
                foreach {key} [lsort [dict keys $data]] {
                    set val [dict get $data $key]
                    foreach {keymatch valtype} $spec {
                        if {[string match $keymatch $key]} {
                            lappend json $key [dictsort3 $valtype $val]
                            break
                        }
                    }
                }
                return $json
            }
            list {
                lappend spec * string
                set json {}
                set idx 0
                foreach {val} $data {
                    foreach {keymatch valtype} $spec {
                        if {$idx == $keymatch || $keymatch eq "*"} {
                            lappend json [dictsort3 $valtype $val]
                            break
                        }
                    }
                    incr idx
                }
                return $json
            }
            string {
                return $data
            }
            default {
		error "Invalid type"
	    }
        }
    }
}

foreach f [TestFilesGlob tests/*.json] {
    set name [file rootname [file tail $f]]
    set JSON($name) [tcltest::viewFile $f]
}

foreach f [TestFilesGlob tests/*.result] {
    set name [file rootname [file tail $f]]
    set TCL($name) [tcltest::viewFile $f]
}

foreach f [TestFilesGlob tests/*.sort] {
    set name [file rootname [file tail $f]]
    set DICTSORT($name) [tcltest::viewFile $f]
}

# Postprocessing result of one test case, insert proper expected unicodepoint
set  TCL(menu) [string map [list @@@ \u6021]  $TCL(menu)]

set JSON(emptyList) {[]}
set  TCL(emptyList) {}

set JSON(emptyList2) {{"menu": []}}
set  TCL(emptyList2) {menu {}}

set JSON(emptyList3) {["menu", []]}
set  TCL(emptyList3) {menu {}}

set JSON(emptyList4) {[[]]}
set  TCL(emptyList4) {{}}

set JSON(escapes) {"\t\r\n\f\b\/\\\""}
set  TCL(escapes) "\t\r\n\f\b/\\\""



foreach f [TestFilesGlob tests/*.fail] {
    set name [file rootname [file tail $f]]
    set FAIL($name) [tcltest::viewFile $f]
}

foreach f [TestFilesGlob tests/*.err] {
    set name [file rootname [file tail $f]]
    set ERR($name) [tcltest::viewFile $f]
}

## Tcl has strict escape checking.
## C   uses Tcl_UtfBacklash, and allows lots of irregular escapes.

set FAIL(escape1)        {"\%"}
set  ERR(escape1-tcl)    {unexpected token ""\%"" at position 0; expecting STRING}
set  ERR(escape1-critcl) {bad escape 3 bytes before end, around ``%''}

set FAIL(escape2)        {"\."}
set  ERR(escape2-tcl)    {unexpected token ""\."" at position 0; expecting STRING}
set  ERR(escape2-critcl) {bad escape 3 bytes before end, around ``.''}

set FAIL(escape3)        {["\%"]}
set  ERR(escape3-tcl)    {unexpected token ""\%"" at position 1; expecting STRING}
set  ERR(escape3-critcl) {bad escape 4 bytes before end, around ``%''}

set FAIL(escape4)        {["\."]}
set  ERR(escape4-tcl)    {unexpected token ""\."" at position 1; expecting STRING}
set  ERR(escape4-critcl) {bad escape 4 bytes before end, around ``.''}

set FAIL(escape5)        {{"a":"\%"}}
set  ERR(escape5-tcl)    {unexpected token ""\%"" at position 3; expecting STRING}
set  ERR(escape5-critcl) {bad escape 4 bytes before end, around ``%''}

set FAIL(escape6)        {{"a":"\."}}
set  ERR(escape6-tcl)    {unexpected token ""\."" at position 3; expecting STRING}
set  ERR(escape6-critcl) {bad escape 4 bytes before end, around ``.''}



proc resultfor {name} {
    global TCL
    transform $TCL($name) $name
}

proc transform {res name} {
    global DICTSORT
    if {[info exists DICTSORT($name)]} {
        return [dictsort3 $DICTSORT($name) $res]
    } else {
        return $res
    }
}

proc transform* {res args} {
    set t {}
    foreach r $res n $args {
        lappend t [transform $r $n]
    }
    return $t
}
