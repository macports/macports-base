# Commands for handling and combining lists of port information ("portentries")

package provide portlist 1.0

namespace eval portlist {
    variable split_variants_re {([-+])([[:alpha:]_]+[\w\.]*)}
}

proc regex_pat_sanitize {s} {
    set sanitized [regsub -all {[\\(){}+$.^]} $s {\\&}]
    return $sanitized
}

# Form a composite version as is sometimes used for registry functions
# This function sorts the variants and presents them in a canonical representation
proc composite_version {version variations {emptyVersionOkay 0}} {
    # Form a composite version out of the version and variations

    # Select the variations into positive and negative
    set pos [list]
    set neg [list]
    foreach { key val } $variations {
        if {$val eq "+"} {
            lappend pos $key
        } elseif {$val eq "-"} {
            lappend neg $key
        }
    }

    # If there is no version, we have nothing to do
    set composite_version ""
    if {$version ne "" || $emptyVersionOkay} {
        set pos_str ""
        set neg_str ""

        if {[llength $pos]} {
            set pos_str "+[join [lsort -ascii $pos] "+"]"
        }
        if {[llength $neg]} {
            set neg_str "-[join [lsort -ascii $neg] "-"]"
        }

        set composite_version "$version$pos_str$neg_str"
    }

    return $composite_version
}

proc split_variants {variants} {
    set result [list]
    set l [regexp -all -inline -- $portlist::split_variants_re $variants]
    foreach { match sign variant } $l {
        lappend result $variant $sign
    }
    return $result
}

proc entry_for_portlist {portentry} {
    global global_options

    # Each portlist entry currently has the following elements in it:
    #   url             if any
    #   name
    #   version         (version_revision)
    #   variants array  (variant=>+-)
    #   requested_variants array  (variant=>+-)
    #   options array   (key=>value)
    #   fullname        (name/version_revision+-variants)
    #       Note: name always normalised to lower case in fullname

    array set port $portentry
    if {![info exists port(url)]}       { set port(url) "" }
    if {![info exists port(name)]}      { set port(name) "" }
    if {![info exists port(version)]}   { set port(version) "" }
    if {![info exists port(variants)]}  { set port(variants) "" }
    if {![info exists port(requested_variants)]}  { set port(requested_variants) "" }
    if {![info exists port(options)]}   { set port(options) [array get global_options] }

    # If neither portname nor url is specified, then default to the current port
    if { $port(url) eq "" && $port(name) eq "" } {
        set url file://.
        set portname [url_to_portname $url]
        set port(url) $url
        set port(name) $portname
        if {$portname eq ""} {
            ui_error "A default port name could not be supplied."
        }
    }

    # Form the fully discriminated portname: portname/version_revison+-variants
    set port(fullname) [string tolower $port(name)]/[composite_version $port(version) $port(variants)]

    return [array get port]
}


proc add_to_portlist {listname portentry} {
    upvar $listname portlist

    # Form portlist entry and add to portlist
    lappend portlist [entry_for_portlist $portentry]
}


proc add_ports_to_portlist {listname ports {overridelist ""}} {
    upvar $listname portlist

    array set overrides $overridelist

    # Add each entry to the named portlist, overriding any values
    # specified as overrides
    foreach portentry $ports {
        array set port $portentry
        if {[info exists overrides(version)]}   { set port(version) $overrides(version) }
        if {[info exists overrides(variants)]}  { set port(variants) $overrides(variants) }
        if {[info exists overrides(requested_variants)]}  { set port(requested_variants) $overrides(requested_variants) }
        if {[info exists overrides(options)]}   { set port(options) $overrides(options) }
        add_to_portlist portlist [array get port]
    }
}

# Execute the enclosed block once for every element in the portlist
# When the block is entered, the following variables will have been set:
#   portspec, porturl, portname, portversion, options, variations, requested_variations, portmetadata
proc foreachport {portlist block} {
    set savedir [pwd]
    foreach portspec $portlist {

        # Set the variables for the block
        uplevel 1 "array unset portspec; array set portspec { $portspec }"
        uplevel 1 {
            set porturl $portspec(url)
            set portname $portspec(name)
            set portversion $portspec(version)
            array unset variations
            array set variations $portspec(variants)
            array unset requested_variations
            array set requested_variations $portspec(requested_variants)
            array unset options
            array set options $portspec(options)
            array unset portmetadata
            if {[info exists portspec(metadata)]} {
                array set portmetadata $portspec(metadata)
            }
        }

        # Invoke block
        uplevel 1 $block

        # Restore cwd after each port, since mportopen changes it, and otherwise relative
        # urls would break on subsequent passes
        if {[file exists $savedir]} {
            cd $savedir
        } else {
            cd ~
        }
    }
}


proc portlist_compare { a b } {
    array set a_ $a
    array set b_ $b
    set namecmp [string equal -nocase $a_(name) $b_(name)]
    if {$namecmp != 1} {
        if {$a_(name) eq [lindex [lsort -dictionary [list $a_(name) $b_(name)]] 0]} {
            return -1
        }
        return 1
    }
    set avr_ [split $a_(version) "_"]
    set bvr_ [split $b_(version) "_"]
    set versioncmp [vercmp [lindex $avr_ 0] [lindex $bvr_ 0]]
    if {$versioncmp != 0} {
        return $versioncmp
    }
    set ar_ [lindex $avr_ 1]
    set br_ [lindex $bvr_ 1]
    if {$ar_ < $br_} {
        return -1
    } elseif {$ar_ > $br_} {
        return 1
    } else {
        return 0
    }
}

# Sort two ports in NVR (name@version_revision) order
proc portlist_sort { list } {
    return [lsort -command portlist_compare $list]
}

proc portlist_compareint { a b } {
    array set a_ [list "name" [lindex $a 0] "version" "[lindex $a 1]_[lindex $a 2]"]
    array set b_ [list "name" [lindex $b 0] "version" "[lindex $b 1]_[lindex $b 2]"]
    return [portlist_compare [array get a_] [array get b_]]
}

# Same as portlist_sort, but with numeric indexes {name version revision}
proc portlist_sortint { list } {
    return [lsort -command portlist_compareint $list]
}

proc unique_entries { entries } {
    # Form the list of all the unique elements in the list a,
    # considering only the port fullname, and taking the first
    # found element first
    set result [list]
    array unset unique
    foreach item $entries {
        array set port $item
        if {[info exists unique($port(fullname))]} continue
        set unique($port(fullname)) 1
        lappend result $item
    }
    return $result
}


proc opUnion { a b } {
    # Return the unique elements in the combined two lists
    return [unique_entries [concat $a $b]]
}


proc opIntersection { a b } {
    set result [list]

    # Rules we follow in performing the intersection of two port lists:
    #
    #   a/, a/          ==> a/
    #   a/, b/          ==>
    #   a/, a/1.0       ==> a/1.0
    #   a/1.0, a/       ==> a/1.0
    #   a/1.0, a/2.0    ==>
    #
    #   If there's an exact match, we take it.
    #   If there's a match between simple and discriminated, we take the later.

    # First create a list of the fully discriminated names in b
    array unset bfull
    set i 0
    foreach bitem [unique_entries $b] {
        array set port $bitem
        set bfull($port(fullname)) $i
        incr i
    }

    # Walk through each item in a, matching against b
    foreach aitem [unique_entries $a] {
        array set port $aitem

        # Quote the fullname and portname to avoid special characters messing up the regexp
        set safefullname [regex_pat_sanitize $port(fullname)]

        set simpleform [string equal -nocase "$port(name)/" $port(fullname)]
        if {$simpleform} {
            set pat "^${safefullname}"
        } else {
            set safename [regex_pat_sanitize [string tolower $port(name)]]
            set pat "^${safefullname}$|^${safename}/$"
        }

        set matches [array names bfull -regexp $pat]
        foreach match $matches {
            if {$simpleform} {
                set i $bfull($match)
                lappend result [lindex $b $i]
            } else {
                lappend result $aitem
            }
        }
    }

    return $result
}


proc opComplement { a b } {
    set result [list]

    # Return all elements of a not matching elements in b

    # First create a list of the fully discriminated names in b
    array unset bfull
    set i 0
    foreach bitem $b {
        array set port $bitem
        set bfull($port(fullname)) $i
        incr i
    }

    # Walk through each item in a, taking all those items that don't match b
    foreach aitem $a {
        array set port $aitem

        # Quote the fullname and portname to avoid special characters messing up the regexp
        set safefullname [regex_pat_sanitize $port(fullname)]

        set simpleform [string equal -nocase "$port(name)/" $port(fullname)]
        if {$simpleform} {
            set pat "^${safefullname}"
        } else {
            set safename [regex_pat_sanitize [string tolower $port(name)]]
            set pat "^${safefullname}$|^${safename}/$"
        }

        set matches [array names bfull -regexp $pat]

        # We copy this element to result only if it didn't match against b
        if {![llength $matches]} {
            lappend result $aitem
        }
    }

    return $result
}

