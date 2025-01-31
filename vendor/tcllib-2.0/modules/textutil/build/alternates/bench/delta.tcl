proc main {} {
    lassign $::argv linear binary

    set lin [open $linear r]	; gets $lin	;# open and strip header
    set bin [open $binary r]	; gets $bin	;# ditto

    puts [join {Code Type Char} ,]

    lassign {0 0 0 0} lts lws bts bws
    
    while {![eof $lin] && ![eof $bin]} {
	lassign [split [gets $lin] ,] code ltype lwidth
	lassign [split [gets $bin] ,] code btype bwidth

	if {$code eq {}} continue

	# Assuming that binary is faster, compute how much slower linear is in comparison.

	set td [expr {$ltype/$btype}]
	set wd [expr {$lwidth/$bwidth}]

	# > 1 - Linear slower by that factor
	# = 1 - Same performance
	# < 1 - Linear faster by that factor
	
	puts [join [list $code $td $wd] ,]

	# Sum times for overall assessment
	set lts [expr {$lts + $ltype}]
	set lws [expr {$lws + $lwidth}]
	set bts [expr {$bts + $btype}]
	set bws [expr {$bws + $bwidth}]
    }

    # Overall performance difference
    set td [expr {$lts/$bts}]
    set wd [expr {$lws/$bws}]

    puts [join [list $code $td $wd] ,]
}

main
