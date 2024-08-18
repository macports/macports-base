# Commands for handling and combining lists of port information ("portentries")

package provide portlist 1.0

namespace eval portlist {
    variable split_variants_re {([-+])([[:alpha:]_]+[\w\.]*)}
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
    # Each portlist entry currently has the following elements in it:
    #   url             if any
    #   name
    #   version         (version_revision)
    #   variants array  (variant=>+-)
    #   requested_variants array  (variant=>+-)
    #   options array   (key=>value)
    #   fullname        (name/version_revision+-variants)
    #       Note: name always normalised to lower case in fullname

    foreach key {url name version variants requested_variants options} {
        if {![dict exists $portentry $key]} {
            dict set portentry $key ""
        }
    }

    # Form the fully discriminated portname: portname/version_revison+-variants
    set normname [string tolower [dict get $portentry name]]
    set fullvers [composite_version [dict get $portentry version] [dict get $portentry variants]]
    dict set portentry fullname ${normname}/${fullvers}

    return $portentry
}


proc add_to_portlist {listname portentry} {
    upvar $listname portlist

    # Form portlist entry and add to portlist
    lappend portlist [entry_for_portlist $portentry]
}


proc add_ports_to_portlist {listname ports {overrides ""}} {
    upvar $listname portlist

    # Add each entry to the named portlist, overriding any values
    # specified as overrides (typically version, variants,
    # requested_variants, options).
    foreach portentry $ports {
        add_to_portlist portlist [dict merge $portentry $overrides]
    }
}

# Execute the enclosed block once for every element in the portlist
# When the block is entered, the following variables will have been set:
#   portspec, porturl, portname, portversion, options, variations, requested_variations, portmetadata
proc foreachport {portlist block} {
    set savedir [pwd]
    foreach portspec $portlist {

        # Set the variables for the block
        uplevel 1 [list set portspec $portspec]
        uplevel 1 {
            set porturl [dict get $portspec url]
            set portname [dict get $portspec name]
            set portversion [dict get $portspec version]
            set variations [dict get $portspec variants]
            set requested_variations [dict get $portspec requested_variants]
            set options [dict get $portspec options]
            if {[dict exists $portspec metadata]} {
                set portmetadata [dict get $portspec metadata]
            } else {
                set portmetadata ""
            }
        }

        # Invoke block
        uplevel 1 $block

        # Restore cwd after each port, since mportopen changes it, and otherwise relative
        # urls would break on subsequent passes
        if {[file exists $savedir]} {
            cd $savedir
        } else {
            # XXX Tcl9 unsafe
            cd ~
        }
    }
}


proc portlist_compare { a b } {
    set namecmp [string equal -nocase [dict get $a name] [dict get $b name]]
    if {$namecmp != 1} {
        if {[dict get $a name] eq [lindex [lsort -dictionary [list [dict get $a name] [dict get $b name]]] 0]} {
            return -1
        }
        return 1
    }
    # the version proper is everything up to the last underscore
    set avr_ [split [dict get $a version] _]
    set bvr_ [split [dict get $b version] _]
    set av_ [join [lrange $avr_ 0 end-1] _]
    set bv_ [join [lrange $bvr_ 0 end-1] _]
    set versioncmp [vercmp $av_ $bv_]
    if {$versioncmp != 0} {
        return $versioncmp
    }
    # revision comes after the last underscore
    set ar_ [lindex $avr_ end]
    set br_ [lindex $bvr_ end]
    if {$ar_ < $br_} {
        return -1
    } elseif {$ar_ > $br_} {
        return 1
    } else {
        return 0
    }
}

# Sort two ports in NVR (name@version_revision) order
proc portlist_sort {portlist} {
    return [lsort -command portlist_compare $portlist]
}

proc portlist_compareint {a b} {
    set a_ [dict create name [lindex $a 0] version [lindex $a 1]_[lindex $a 2]]
    set b_ [dict create name [lindex $b 0] version [lindex $b 1]_[lindex $b 2]]
    return [portlist_compare $a_ $b_]
}

# Same as portlist_sort, but with numeric indexes {name version revision}
proc portlist_sortint {portlist} {
    return [lsort -command portlist_compareint $portlist]
}

proc portlist_compareregrefs {a b} {
    set aname [$a name]
    set bname [$b name]
    if {![string equal -nocase $aname $bname]} {
        # There's no -dictionary option for string compare as of Tcl 8.6
        if {$aname eq [lindex [lsort -dictionary [list $aname $bname]] 0]} {
            return -1
        }
        return 1
    }
    set byvers [vercmp [$a version] [$b version]]
    if {$byvers != 0} {
        return $byvers
    }
    set byrevision [expr {[$a revision] - [$b revision]}]
    if {$byrevision != 0} {
        return $byrevision
    }
    return [string compare -nocase [$a variants] [$b variants]]
}

# Sort a list of registry references
proc portlist_sortregrefs {reflist} {
    return [lsort -command portlist_compareregrefs $reflist]
}

proc portlist::unique_entries {entries} {
    # Form the list of all the unique elements in the list a,
    # considering only the port fullname, and taking the first
    # found element first
    set unique [dict create]
    foreach item $entries {
        set fullname [dict get $item fullname]
        if {[dict exists $unique $fullname]} continue
        dict set unique $fullname $item
    }
    return [dict values $unique]
}


proc portlist::opUnion {a b} {
    # Return the unique elements in the combined two lists
    return [unique_entries [concat $a $b]]
}


proc portlist::opIntersection {a b} {
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

    # First create a 2-level dict of the items in b.
    # Top level keys are normalised port names.
    # Second level is a dict mapping fully discriminated names to the
    # corresponding full entry.
    set bdict [dict create]
    foreach bitem [unique_entries $b] {
        dict set bdict [string tolower [dict get $bitem name]] [dict get $bitem fullname] $bitem
    }

    # Walk through each item in a, matching against b
    foreach aitem [unique_entries $a] {

        set normname [string tolower [dict get $aitem name]]
        if {![dict exists $bdict $normname]} {
            # this port name is not in b at all
            continue
        }
        if {[dict get $aitem version] eq "" && [dict get $aitem variants] eq ""} {
            # just a port name, append all entries with this name in b
            lappend result {*}[dict values [dict get $bdict $normname]]
        } else {
            # append if either the fullname or a simple entry with a matching name is in b
            set fullname [dict get $aitem fullname]
            if {[dict exists $bdict $normname $fullname] || [dict exists $bdict $normname ${normname}/]} {
                lappend result $aitem
            }
        }
    }

    return $result
}


proc portlist::opComplement {a b} {
    set result [list]

    # Return all elements of a not matching elements in b

    # First create a 2-level dict of the items in b.
    # Top level keys are normalised port names.
    # Second level is a dict mapping fully discriminated names (to empty
    # strings since we don't need the full entries from b.)
    set bdict [dict create]
    foreach bitem $b {
        dict set bdict [string tolower [dict get $bitem name]] [dict get $bitem fullname] ""
    }

    # Walk through each item in a, taking all those items that don't match b
    foreach aitem $a {
        set normname [string tolower [dict get $aitem name]]
        if {![dict exists $bdict $normname]} {
            # this port name is not in b at all
            lappend result $aitem
            continue
        }

        # We now know the port name is in b, so only fully discriminated entries might not match
        if {[dict get $aitem version] ne "" || [dict get $aitem variants] ne ""} {
            set fullname [dict get $aitem fullname]
            # append if neither the fullname nor a simple entry with a matching name is in b
            if {![dict exists $bdict $normname $fullname] && ![dict exists $bdict $normname ${normname}/]} {
                lappend result $aitem
            }
        }
    }

    return $result
}

