
proc row {args} { puts |[join $args \t|]\t| }
proc f   {x}    { format %.2f $x }

set first 1
set max 1114112000 ;# number of codepoints

# Time information manually pulled out of the `bench.log`.

foreach {key time} {
    linear	682m52.782s
    2map	25m54.557s
    ternary	23m16.329s
    binary	21m44.001s
    map		14m11.575s
} {
    set size [file size i.$key/wcswidth.tcl]
    set time [expr [string map {s {} m {*60+} h {*3600+} } $time]]
    
    set pointss [expr {$max/double($time)}]
	      
    if {$first} { set fsize $size ; set fpointss $pointss }
    if {$first} { set lsize $size ; set lpointss $pointss }
    set first no

    set bover [f [expr {$size    / double($fsize)    }]]
    set iover [f [expr {$size    / double($lsize)    }]]
    set bgain [f [expr {$pointss / double($fpointss) }]]
    set igain [f [expr {$pointss / double($lpointss) }]]

    lappend x [list $key $size $bover $iover [f $time] [f $pointss] $bgain $igain]

    set lsize $size ; set lpointss $pointss
}

row Algorithm {Code Size} Overhead Overhead/I Time Points/s Gain Gain/I
row --- ---: ---: ---: ---: ---: ---: ---:
foreach row [lreverse $x] { row {*}$row }

puts ""

row Algorithm {Type Min} Max 50% 90% 99% {Width Min} Max 50% 90% 99%
row --- ---: ---: ---: ---: ---: ---: ---: ---: ---: ---:

foreach p [glob i.*/bench-stats.csv] {
    set c [open $p r]
    gets $c
    gets $c
    lassign [split [gets $c] ,] label _ tmin tmax tm tn tx wmin wmax wm wn wx
    set label [string map {i. {}} $label]
    
    row $label $tmin $tmax $tm $tn $tx $wmin $wmax $wm $wn $wx
}
