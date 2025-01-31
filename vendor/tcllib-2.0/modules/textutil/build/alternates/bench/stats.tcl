proc main {} {
    lassign $::argv algo code csv

    set csv [open $csv r]	; gets $csv	;# open and strip header

    lassign {Inf 0 Inf 0} tmin tmax wmin wmax
    
    while {![eof $csv]} {
	lassign [split [gets $csv] ,] code t w
	if {$code eq {}} continue
	
	set tmax [expr {max($tmax,$t)}]
	set tmin [expr {min($tmin,$t)}]
	set wmax [expr {max($wmax,$w)}]
	set wmin [expr {min($wmin,$w)}]

	lappend tl $t
	lappend wl $w
    }

    set tl [lsort -real -increasing $tl]
    set wl [lsort -real -increasing $wl]

    set tm [lindex $tl [expr { [llength $tl] >> 1 }]]		;# 50th quantile
    set wm [lindex $wl [expr { [llength $wl] >> 1 }]]
    
    set tn [lindex $tl [expr { ([llength $tl] * 9) / 10 }]]	;# 90th quantile
    set wn [lindex $wl [expr { ([llength $wl] * 9) / 10 }]]

    set tx [lindex $tl [expr { ([llength $tl] * 99) / 100 }]]	;# 99th quantile
    set wx [lindex $wl [expr { ([llength $wl] * 99) / 100 }]]

    # Write stats as CSV
    
    puts [join {Algorithm Code   Type  _     Qu  _   _   Width _     Qu  _   _    } ,]
    puts [join {{}        {}     Min   Max   50% 90% 99% Min   Max   50% 90% 99%  } ,]
    puts [join [list $algo $code $tmin $tmax $tm $tn $tx $wmin $wmax $wm $wn $wx  ] ,]
}

main
