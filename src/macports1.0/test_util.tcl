# test_util.tcl
# $Id$
#
# Comprehensive test file for macports_util.tcl
# Written by Kevin Ballard <eridius@macports.org>

source ./macports_util.tcl

array set options {t 0 w 0}

set ::traceNest ""
set ::traceSquelch 0
set ::traceSquelchNest ""
proc dotrace {args} {
    global traceNest options
    flush stdout
    set command [lindex $args 0]
    if {$options(w) > 0} {
        # trim command to 1 line
        if {[llength [set lines [split $command "\n"]]] > 1} {
            set command "[lindex $lines 0] [ansi fg-blue]...[ansi reset]"
        }
    }
    set op [lindex $args end]
    switch $op {
        enter { append traceNest "#" }
        enterstep { append traceNest "+" }
    }
    switch $op {
        enter {
            puts stderr "[ansi fg-yellow inverse]$traceNest>[ansi reset] $command"
            set ::traceSquelch 0
        }
        enterstep {
            if {!$::traceSquelch} {
                puts stderr "[ansi fg-yellow]$traceNest>[ansi reset] $command"
                if {[llength [info procs [lindex [split $command] 0]]] > 0} {
                    # it's a proc, lets start squelching
                    set ::traceSquelch 1
                    set ::traceSquelchNest $::traceNest
                }
            }
        }
        leave -
        leavestep {
            if {$op eq "leavestep" && $::traceSquelch && $::traceNest eq $::traceSquelchNest} {
                set ::traceSquelch 0
            }
            if {$op eq "leave" || !$::traceSquelch} {
                set code [lindex $args 1]
                set result [lindex $args 2]
                if {$options(w) > 0} {
                    # trim result just like command
                    if {[llength [set lines [split $result "\n"]]] > 1} {
                        set result "[lindex $lines 0] [ansi fg-blue]...[ansi reset]"
                    }
                }
                if {$op eq "leave"} {
                    set prefix "[ansi fg-blue inverse]$traceNest"
                } else {
                    set prefix "[ansi fg-blue]$traceNest"
                }
                if {$code != 0} {
                    puts stderr "$prefix =\[$code\]>[ansi reset] $result"
                } else {
                    puts stderr "$prefix =>[ansi reset] $result"
                }
            }
        }
    }
    switch $op {
        leave -
        leavestep {
            set traceNest [string range $traceNest 0 end-1]
        }
    }
}
while {[llength $argv] > 0} {
    set arg [lshift argv]
    if {$arg eq "--"} {
        break
    } elseif {[string match -* $arg]} {
        set arg [string range $arg 1 end]
        while {[string length $arg] > 0} {
            set opt [string index $arg 0]
            set arg [string range $arg 1 end]
            switch $opt {
                t { incr options(t) }
                w { incr options(w) }
                default {
                    error "Unknown option: -$opt"
                }
            }
        }
    } else {
        lunshift argv $arg
        break
    }
}
if {$options(t) > 0} {
    set ops {enter leave}
    if {$options(t) > 1} {
        lappend ops enterstep leavestep
    }
    set util_list {ldindex lpop lpush lshift lunshift try throw}
    if {[llength $argv] > 0} {
        set list $argv
        if {[set idx [lsearch -exact $list *]] != -1} {
            set list [eval lreplace [list $list] $idx $idx $util_list]
        }
    } else {
        set list $util_list
    }
    foreach arg $list {
        trace add execution $arg $ops dotrace
    }
}

proc init {name value} {
    set name [list $name]
    set value [list $value]
    uplevel 1 [subst -nocommands {
        set $name $value
        set $name-bak [set $name]
    }]
}

proc restore {name} {
    set name [list $name]
    uplevel 1 [subst -nocommands {
        if {[info exists $name-bak]} {
            set $name [set $name-bak]
        } else {
            unset $name
        }
    }]
}

array set kStateToAnsiTable {
    error fg-magenta
    expected fg-cyan
    correct fg-green
    wrong fg-red
}

array set kAnsiTable {
    reset           0
    
    bold            1
    dim             2
    underline       4
    blink           5
    inverse         7
    hidden          8
    
    fg-black        30
    fg-red          31
    fg-green        32
    fg-yellow       33
    fg-blue         34
    fg-magenta      35
    fg-cyan         36
    fg-white        37
    fg-default      39
    
    bg-black        40
    bg-red          41
    bg-green        42
    bg-yellow       43
    bg-blue         44
    bg-magenta      45
    bg-cyan         46
    bg-white        47
    bg-default      49
}

proc ansi {args} {
    global kAnsiTable
    if {[llength $args] == 0} {
        error "wrong # args: should be \"ansi code ...\""
    }
    set colors {}
    foreach code $args {
        lappend colors $kAnsiTable($code)
    }
    return "\033\[[join $colors ";"]m"
}

proc state {code} {
    global kStateToAnsiTable
    return [ansi $kStateToAnsiTable($code)]
}

proc line {cmd expected args} {
    uplevel 1 [list block $cmd $cmd $expected] $args
}

proc block {name cmd expected args} {
    if {[set err [catch {uplevel 1 $cmd} value]]} {
        set savedErrorInfo $::errorInfo
        set savedErrorCode $::errorCode
        if {$expected eq "-error" && $err == 1} {
            if {[llength $args] > 0} {
                set errCode [lindex $args 0]
                if {$errCode == $savedErrorCode} {
                    if {[llength $args] > 1} {
                        set errMsg [lindex $args 1]
                        if {$errMsg == $value} {
                            set code expected
                        } else {
                            set code error
                        }
                    } else {
                        set code expected
                    }
                } else {
                    set code error
                }
            } else {
                set code expected
            }
        } elseif {$expected eq "-return" && $err == 2} {
            if {[llength $args] > 0} {
                set errMsg [lindex $args 0]
                if {$errMsg == $value} {
                    set code expected
                } else {
                    set code error
                }
            } else {
                set code expected
            }
        } elseif {$expected eq "-break" && $err == 3} {
            set code expected
        } else {
            set code error
        }
    } elseif {$value == $expected} {
        set code correct
    } else {
        set code wrong
    }
    if {$code eq "error"} {
        append value "\n$savedErrorInfo"
    }
    puts "[state $code]$name =[if {$err != 0} {format \[$err\]}]> $value[ansi reset]"
}

proc var {name expected} {
    set exists [uplevel 1 info exists [list $name]]
    if {!$exists} {
        set value "does not exist"
        if {$expected eq "-unset"} {
            set code expected
        } else {
            set code error
        }
    } else {
        set value [uplevel 1 set [list $name]]
        if {$value == $expected} {
            set code correct
        } else {
            set code wrong
        }
    }
    puts "[state $code]$name: $value[ansi reset]"
}

if {[set err [catch {
    namespace eval test {
        namespace eval vars {}
        init vars::ary(one) {1 2 {3 4}}
        init vars::ary(zero) {1 {2 3 {"4 5" 6} 7} 8 9}
        
        var vars::ary(zero) {1 {2 3 {"4 5" 6} 7} 8 9}
        line {ldindex vars::ary(zero) 1 2 0} {4 5}
        var vars::ary(zero) {1 {2 3 6 7} 8 9}
        line {ldindex vars::ary(zero) 1 1 0} 3
        var vars::ary(zero) {1 {2 {} 6 7} 8 9}
        line {ldindex vars::ary(zero) 1 2} 6
        var vars::ary(zero) {1 {2 {} 7} 8 9}
        line {ldindex vars::ary(zero) 1} {2 {} 7}
        var vars::ary(zero) {1 8 9}
        line {ldindex vars::ary(zero)} {1 8 9}
        var vars::ary(zero) {}
        
        var vars::ary(one) {1 2 {3 4}}
        line {lpop vars::ary(one)} {3 4}
        var vars::ary(one) {1 2}
        line {lpop vars::ary(one)} 2
        var vars::ary(one) 1
        line {lpop vars::ary(one)} 1
        var vars::ary(one) {}
        line {lpop vars::ary(one)} {}
        var vars::ary(one) {}
        
        line {lpop vars::foo} -error NONE {can't read "vars::foo": no such variable}
        
        restore vars::ary(one)
        var vars::ary(one) {1 2 {3 4}}
        line {lshift vars::ary(one)} 1
        var vars::ary(one) {2 {3 4}}
        line {lshift vars::ary(one)} 2
        var vars::ary(one) {{3 4}}
        line {lshift vars::ary(one)} {3 4}
        var vars::ary(one) {}
        line {lshift vars::ary(one)} {}
        var vars::ary(one) {}
        
        line {lshift vars::foo} -error NONE {can't read "vars::foo": no such variable}
        
        var vars::ary(two) -unset
        line {lpush vars::ary(two) 1} 1
        var vars::ary(two) 1
        line {lpush vars::ary(two) 2 3 4 5} {1 2 3 4 5}
        var vars::ary(two) {1 2 3 4 5}
        line {lpush vars::ary(two) "this is a test"} {1 2 3 4 5 {this is a test}}
        var vars::ary(two) {1 2 3 4 5 {this is a test}}
        line {lpop vars::ary(two)} {this is a test}
        var vars::ary(two) {1 2 3 4 5}
        
        line {lpush "foo bar" 3} {3}
        var {foo bar} 3
        
        restore vars::ary(two)
        var vars::ary(two) -unset
        line {lunshift vars::ary(two) 5} 5
        var vars::ary(two) 5
        line {lunshift vars::ary(two) 4} {4 5}
        var vars::ary(two) {4 5}
        line {lunshift vars::ary(two) 1 2 3} {1 2 3 4 5}
        var vars::ary(two) {1 2 3 4 5}
        line {lunshift vars::ary(two) "this is a test"} {{this is a test} 1 2 3 4 5}
        var vars::ary(two) {{this is a test} 1 2 3 4 5}
        line {lshift vars::ary(two)} {this is a test}
        var vars::ary(two) {1 2 3 4 5}
        
        # now test the try/throw stuff
        line {throw} -error NONE {error: throw with no parameters outside of a catch}
        line {throw 1 2 3 4} -error NONE {wrong # args: should be "throw ?type? ?message? ?info?"}
        line {try {format 3} catch {} {}} -error NONE {invalid syntax in catch clause: type-list must contain at least one type}
        line {try {format 3} finally {format 4} test} -error NONE {trailing args after finally clause}
        block {basic try} {
            try {
                error "random error"
            }
        } -error NONE "random error"
        block {try-finally} {
            try {
                error "try-finally error"
            } finally {
                set myVar "finally clause worked"
            }
        } -error NONE "try-finally error"
        var myVar "finally clause worked"
        block {try-finally-error} {
            try {
                error "try-finally error"
            } finally {
                error "finally error"
            }
        } -error NONE "finally error"
        block {try-catch} {
            try {
                error "try-catch error"
            } catch NONE {
                format "catch clause worked"
            }
        } "catch clause worked"
        block {try-catch-throw} {
            try {
                error "try-catch error"
            } catch NONE {
                set myVar "thrown"
                throw
            }
        } -error NONE "try-catch error" ;# really should test errorInfo but that's messy
        var myVar "thrown"
        unset myVar
        block {try-catch-finally} {
            try {
                error "try-catch-finally error"
            } catch NONE {
                set myVar "thrown"
                throw
            } finally {
                lappend myVar "finally"
            }
        } -error NONE "try-catch-finally error"
        var myVar "thrown finally"
        block {try-catch-all} {
            try {
                error "this is a test"
            } catch * {
                format "catch-all worked"
            }
        } "catch-all worked"
        block {try-catch-return} {
            try {
                error "this is a test"
            } catch * {
                return "catch-return worked"
            }
        } -return "catch-return worked"
        block {try-catch-break} {
            try {
                error "this is a test"
            } catch * {
                break
            }
        } -break
        block {try-catch-multiple} {
            try {
                error "this is a test"
            } catch POSIX {
                error "POSIX catch"
            } catch * {
                format "catch-all"
            }
        } "catch-all"
        unset myVar
        block {try-catch-multiple-finally} {
            try {
                error "this is a test"
            } catch * {
                lappend myVar "catch-all 1"
            } catch * {
                lappend myVar "catch-all 2"
            } finally {
                lappend myVar "finally"
            }
        } [list {catch-all 1}]
        var myVar [list "catch-all 1" "finally"]
        block {try-catch-types} {
            try {
                error "try-catch-types error" {} {MYERR arg1 arg2}
            } catch POSIX {
                error "POSIX catch"
            } catch {{MY* arg*} code} {
                format "caught code $code"
            }
        } "caught code MYERR arg1 arg2"
        block {try-catch-vars} {
            try {
                error "random error"
            } catch {* code msg info} {
                set list {}
                if {$code eq "NONE"} {
                    lappend list "code: correct"
                }
                if {$msg eq "random error"} {
                    lappend list "msg: correct"
                }
                if {[string match "random error\n*" $info]} {
                    lappend list "info: probably correct"
                }
                join $list ", "
            }
        } "code: correct, msg: correct, info: probably correct"
        block {try-break-catch} {
            try {
                break
            } catch {*} {
                error "catch triggered"
            }
        } -break
        
        # ensure the stack is sound
        var ::_trycatch::catchStack {}
    }
} result]]} {
    puts ""
    puts "error: $result"
    puts "code: $err"
    puts $::errorInfo
}
