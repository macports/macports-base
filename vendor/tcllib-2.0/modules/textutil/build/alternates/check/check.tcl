proc main {} {
    foreach path $::argv {
	set key [file dirname $path]
	source $path
	rename ::textutil::wcswidth_type ${key}_type
	rename ::textutil::wcswidth_char ${key}_char
	rename ::textutil::wcswidth {}
	lappend codes $key
    }
    set codes [lsort -dict $codes]

    puts Order:$codes

    lassign {0 0} tmis wmis
    for {set code 0} {$code <= 1114111} {incr code} {
	puts -nonewline stderr \r$code\t$tmis\t$wmis
	
	set ts [lmap key $codes { ${key}_type $code }]
	set ws [lmap key $codes { ${key}_char $code }]

	set tsu [lsort -unique $ts]
	set wsu [lsort -unique $ws]

	if {[llength $tsu] > 1} {
	    puts Mismatch:T:${code}:$ts
	    incr tmis
	}
	if {[llength $wsu] > 1} {
	    puts Mismatch:W:${code}:$ws
	    incr wmis
	}
    }

    puts /Done
    puts stderr ""
}

main
