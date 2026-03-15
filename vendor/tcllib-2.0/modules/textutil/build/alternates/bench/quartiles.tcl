proc main {} {
    lassign $::argv csv

    set csv [open $csv r]	; gets $csv	;# open and strip header

    lassign {Inf 0 Inf 0} tmin tmax wmin wmax
    
    while {![eof $csv]} {
	lassign [split [gets $csv] ,] code t w
	if {$code eq {}} continue
	lappend tl $t
	lappend wl $w
    }

    set tl [lsort -real -increasing $tl]
    set wl [lsort -real -increasing $wl]

    puts [join {Quart Type Width} ,]

    set nt [llength $tl] ; incr nt -1
    set nw [llength $wl] ; incr nw -1
    
    for {set q 0} {$q <= 100} {incr q} {
	set it [expr { ($nt * $q) / 100 }]
	set iw [expr { ($nw * $q) / 100 }]

	#puts stderr $q/$it/$iw/[llength $tl]/[llength $wl]
	
	set qt [lindex $tl $it]
	set qw [lindex $tl $iw]

	puts [join [list $q $qt $qw] ,]
    }

    return
}

main
