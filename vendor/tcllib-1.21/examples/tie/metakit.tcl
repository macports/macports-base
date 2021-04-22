# -*- tcl -*-
# Metakit backend for tie
#
# (C) 2005 Colin McCormack.
# Taken from http://wiki.tcl.tk/13716, with permission.
#
# CMcC 20050303 - a backend for the tie tcllib package. Persists an
#                 array in a metakit database. In conjunction with the
#                 "remote" array backend, this might have similar
#                 functionality to Tequila.

# Modified AK 2005-09-12

package require Mk4tcl
package require tie
package require snit

snit::type mktie {
    option -var    ""  ; # variable name in metakit
    option -vtype  S   ; # set the variable value type
    option -layout {}  ; # additional layout elements

    constructor {args} {
	$self configurelist $args

	if {$options(-var) eq ""} {
	    # no variable name supplied - use the caller's name
	    upvar 3 avar rv     ;# skip some snit nesting
	    #puts stderr "using $rv"
	    set options(-var) $rv
	}
	#puts stderr "$self - [array get options]"
	set layout [concat [list name text:$options(-vtype)] $options(-layout)]
	mk::view layout tqs.$options(-var) $layout
    }

    # return a list containing the names of all keys found in the
    # metakit database.

    method names {} {
	mk::loop c tqs.$options(-var) {
	    lappend result [mk::get $c name]
	}
    }

    # return an integer number specifying the number of keys found in
    # the metakit database.

    method size {} {
	return [mk::view size tqs.$options(-var)]
    }

    # return a dictionary containing the data found in the metakit
    # database.

    method get {} {
	set dict [dict create]
	mk::loop c tqs.$options(-var) {
	    set val [mk::get $c name text]
	    #puts stderr "get $options(-var)(\#$c) - $val"
	    dict set dict {*}$val
	}
	return $dict
    }

    # takes a dictionary and adds its contents to the metakit

    method set {dict} {
	dict for {key value} $dict {
	    $self setv $key $value
	}
    }

    # removes all elements whose keys match pattern

    method unset {pattern} {
	set matches [mk::select tqs.$options(-var) -glob name $pattern]
	foreach n [lsort -integer -decreasing $matches] {
	    mk::row delete tqs.$options(-var)!$n
	}
    }

    # save value under key

    method setv {key value} {
	set n [mk::select tqs.$options(-var) name $key]
	if {[llength $n] == 0} {
	    set n [mk::view size tqs.$options(-var)]
	} elseif {[mk::get tqs.$options(-var)!$n text] == $value} {
	    return ; # no change, ignore
	}
	#puts stderr "set $options(-var)($key) to $value / $n"
	mk::set tqs.$options(-var)!$n name $key text $value
    }

    # remove the value under key

    method unsetv {key} {
	set n [mk::select tqs.$options(-var) name $key]
	if {[llength $n] == 0} {
	    error "can't unset \"$options(-var)($key)\": no such element in array"
	    return
	}
	mk::row delete tqs.$options(-var)!$n
    }

    # return the value for key

    method getv {key} {
	set n [mk::select tqs.$options(-var) name $key]
	if {[llength $n] == 0} {
	    error "can't read \"$options(-var)($key)\": no such element in array"
	    return
	}
	return [mk::get tqs.$options(-var)!$n text]
    }
}

mk::file open tqs tie.dat -nocommit
::tie::register ::mktie as metakit

package provide mktie 1.0

# ### ### ### ######### ######### #########

if {[info script] eq $argv0} {
    unset -nocomplain av
    array set         av {}

    tie::tie av metakit
    set av(x) blah
    array set av {a 1 b 2 c 3 z 26}
    ::tie::untie av

    puts "second pass"
    unset av
    array set av {}
    tie::tie av metakit
    puts [array size av]
    puts [array get av]
}
