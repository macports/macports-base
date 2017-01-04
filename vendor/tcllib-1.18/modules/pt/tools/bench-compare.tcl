#!/usr/bin/env tclsh
# -*- tcl -*-

package require Tcl 8.5
package require bench::in
package require struct::matrix
package require report

proc main {} {
    write [calc [input 0]] [calc [input 1]]
}

proc input {n} {
    global argv

    set thefile [file join [file dirname [file dirname [file normalize [info script]]]] \
		     tests data ok peg_peg-fused 3_peg_itself]
    set chars [file size $thefile]

    set benchdata [bench::in::read [lindex $argv $n]]

    #array set DATA $benchdata
    #parray    DATA

    return [list $chars $benchdata]
}

proc calc {data} {

    lassign $data chars benchdata

    array set BENCH $benchdata

    set res {}
    set n 1
    foreach key [lsort -dict [array names BENCH usec*]] {
	lassign $key _ desc interp
	set useconds $BENCH($key)

	set seconds  [expr {double($useconds)/1000000}]
	set charsec  [expr {$chars/$seconds}]
	set usecchar [expr {$useconds/double($chars)}]

	lappend res [list $n $desc \
			 [format %.2f $useconds] \
			 [format %.2f $seconds] \
			 [format %.2f $charsec] \
			 [format %.2f $usecchar] \
			]
	incr n
    }

    return [list $chars $res]
}

proc write {base new} {
    global argv

    lassign $base chars benchbase
    lassign $new  chars benchnew
    lassign $argv base new

    ::struct::matrix M
    M add columns      6
    ::report::report R 6 style dcaptionedtable 2 4
    R pad 0 both " " ; R justify 0 center
    R pad 1 both " " ; R justify 1 left
    R pad 2 both " " ; R justify 2 right
    R pad 3 both " " ; R justify 3 right
    R pad 4 both " " ; R justify 4 right
    R pad 5 both " " ; R justify 5 right

    M add row [list {} {} $base $new {} {}]
    M add row [list {} "INPUT $chars chars" chars/sec chars/sec x %]

    lassign $benchbase a b c d e f g ; set benchbase [list $c $b $a $g $f $e $d]
    lassign $benchnew  a b c d e f g ; set benchnew  [list $c $b $a $g $f $e $d]

    foreach base $benchbase new $benchnew {
	lassign $base n desc usecbase _ csbase _
	lassign $new  _ _    usecnew  _ csnew  _

	set factor  [expr {double($usecbase)/double($usecnew)}]
	set percent [expr {100 * $factor - 100}]

	M add row [list $n $desc $csbase $csnew \
		       [format %.2f $factor] \
		       [format %.2f $percent] \
		      ]
    }

    puts [M format 2string R]
    return
}

::report::defstyle simpletable {} {
    data    set [split "[string repeat "| "   [columns]]|"]
    top     set [split "[string repeat "+ - " [columns]]+"]
    bottom  set [top get]
    top     enable
    bottom  enable
}

::report::defstyle captionedtable {{n 1}} {
    simpletable
    topdata   set [data get]
    topcapsep set [top get]
    topcapsep enable
    tcaption $n
}

::report::defstyle dcaptionedtable {{t 1} {b 1}} {
    simpletable
    topdata   set [data get]
    topcapsep set [top get]
    topcapsep enable

    botdata   set [data get]
    botcapsep set [top get]
    botcapsep enable
    tcaption $t
    bcaption $b
}

main
exit
