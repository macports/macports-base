# huddle.tcl (working title)
#
# huddle.tcl 0.1.5 2011-08-23 14:46:47 KATO Kanryu(kanryu6@users.sourceforge.net)
#
#   It is published with the terms of tcllib's BSD-style license.
#   See the file named license.terms.
#
# This library provide functions to differentinate string/list/dict in multi-ranks.
#
# Copyright (c) 2008-2011 KATO Kanryu <kanryu6@users.sourceforge.net>
# Copyright (c) 2015 Miguel Martínez López <aplicacionamedida@gmail.com>

package require Tcl 8.5
package provide huddle 0.2

namespace eval ::huddle {
    namespace export huddle wrap unwrap isHuddle strip_node are_equal_nodes argument_to_node get_src

    variable types

    # Some subcommands conflict with Tcl builtin commands. So, we make
    # the convention of using the first letter in uppercase for
    # private procs (e.g. from "set" to "Set")

    namespace ensemble create -map {
        set                ::huddle::Set
        append            ::huddle::Append
        get                ::huddle::Get
        get_stripped    ::huddle::get_stripped
        unset            ::huddle::Unset
        combine            ::huddle::combine
        combine_relaxed    ::huddle::combine_relaxed
        type            ::huddle::type
        remove            ::huddle::remove
        equal            ::huddle::equal
        exists            ::huddle::exists
        clone            ::huddle::clone
        isHuddle        ::huddle::isHuddle
        wrap            ::huddle::wrap
        unwrap            ::huddle::unwrap
        addType            ::huddle::addType
        jsondump        ::huddle::jsondump
        compile            ::huddle::compile
    }
}

proc ::huddle::addType {typeNamespace} {
    variable types

    set typeName [namespace tail $typeNamespace]
    set typeCommand ::huddle::Type_$typeName

    namespace upvar $typeNamespace settings settings

    if {[dict exists $settings map]} {
        set ensemble_map_of_type [dict get $settings map]
        set renamed_subcommands [dict values $ensemble_map_of_type]
    } else {
        set renamed_subcommands [list]
    }

    dict set ensemble_map_of_type settings ${typeNamespace}::settings

    foreach path_to_subcommand [info procs ${typeNamespace}::*] {
        set subcommand [namespace tail $path_to_subcommand]

        if {$subcommand ni $renamed_subcommands} {
            dict set ensemble_map_of_type $subcommand ${typeNamespace}::$subcommand
        }
    }

    namespace eval $typeNamespace "
        namespace import ::huddle::wrap ::huddle::unwrap ::huddle::isHuddle ::huddle::strip_node ::huddle::are_equal_nodes ::huddle::argument_to_node ::huddle::get_src

        namespace ensemble create -unknown ::huddle::unknown_subcommand -command $typeCommand -prefixes false -map {$ensemble_map_of_type}

        proc settings {} {
            variable settings
            return \$settings
        }
    "

    set huddle_map [namespace ensemble configure ::huddle -map]

    dict with settings {
        foreach subcommand $publicMethods {
            dict set huddle_map $subcommand [list $typeCommand $subcommand]
        }

        if {[info exists superclass]} {
            set types(superclass:$tag) $superclass
        }

        set types(type:$tag) $typeName
        set types(callback:$tag) $typeCommand
        set types(isContainer:$tag) $isContainer
        set types(tagOfType:$typeName) $tag
    }

    namespace ensemble configure ::huddle -map $huddle_map
    return
}

proc ::huddle::is_superclass_of {tag1 tag2} {
    variable types

    if {![info exists types(list_of_superclasses:$tag1)]} {
        set types(list_of_superclasses:$tag1) [list]

        set superclass_tag $tag1

        while {true} {
            if {[info exists types(superclass:$superclass_tag)]} {
                set superclass $types(superclass:$superclass_tag)
                set superclass_tag $types(tagOfType:$superclass)

                lappend types(list_of_superclasses:$tag1) $superclass_tag
            } else {
                break
            }
        }
    }

    if {$tag2 in $types(list_of_superclasses:$tag1) } {
        return 1
    } else {
        return 0
    }
}

proc ::huddle::unknown_subcommand {ensembleCmd subcommand args} {
    set settings [$ensembleCmd settings]

    if {[dict exists $settings superclass]} {
        set superclass [dict get $settings superclass]

        set map [namespace ensemble configure $ensembleCmd -map]
        dict set map $subcommand [list ::huddle::Type_$superclass $subcommand]

        namespace ensemble configure $ensembleCmd -map $map
        return ""
    } else {
        error "Invalid subcommand '$subcommand' for type '$ensembleCmd'"
    }
}

proc ::huddle::isHuddle {obj} {
    if {[lindex $obj 0] ne "HUDDLE" || [llength $obj] != 2} {
        return 0
    }
    
    variable types
    set node [lindex $obj 1]
    set tag [lindex $node 0]

    if { [array get types "type:$tag"] == ""} {
        return 0
    }

    return 1
}

proc ::huddle::strip_node {node} {
    variable types
    foreach {head src} $node break
    if {[info exists types(type:$head)]} {
        if {$types(isContainer:$head)} {
            return [$types(callback:$head) strip $src]
        } else {
            return $src
        }
    } else {
        error "This head '$head' doesn't exists."
    }
}

proc ::huddle::call {tag cmd arguments} {
    variable types
    return [$types(callback:$tag) $cmd {*}$arguments]
}

proc ::huddle::combine {args} {
    variable types

    foreach {obj} $args {
        checkHuddle $obj
    }

    set first_object [lindex $args 0]
    set tag_of_group [lindex [unwrap $first_object] 0]

    foreach {obj} $args {
        set node [unwrap  $obj]
    
        foreach {tag src} $node break

        if {$tag_of_group ne $tag} {
            if {[is_superclass_of $tag $tag_of_group]} {
                set tag_of_group $tag
            } else {
                if {![is_superclass_of $tag_of_group $tag]} {
                    error "unmatched types are given or one type is not a superclass of the other."
                }
            }
        }
        
        lappend result {*}$src
    }

    set src [$types(callback:$tag_of_group) append_subnodes "" {} $result]
    return [wrap [list $tag $src]]
}

proc ::huddle::checkHuddle {huddle_object} {
    if {![isHuddle $huddle_object]} {
        error "\{$huddle_object\} is not a huddle."
    }
}

proc ::huddle::argument_to_node {src {default_tag s}} {
    if {[isHuddle $src]} {
        return [unwrap $src]
    } else {
        return [list $default_tag $src]
    }
}

proc ::huddle::wrap { node } {
    return [list HUDDLE $node]
}

proc ::huddle::unwrap { huddle_object } {
    return [lindex $huddle_object 1]
}

proc ::huddle::get_src { huddle_object } {
    return [lindex [unwrap $huddle_object] 1]
}

proc ::huddle::Get {huddle_object args} {
    return [retrieve_huddle $huddle_object $args 0]
}

proc ::huddle::get_stripped {huddle_object args} {
    return [retrieve_huddle $huddle_object $args 1]
}

proc ::huddle::retrieve_huddle {huddle_object path stripped} {
    checkHuddle $huddle_object

    set target_node [Find_node [unwrap $huddle_object] $path]

    if {$stripped} {
        return [strip_node $target_node]
    } else {
        return [wrap $target_node]
    }
}

proc ::huddle::type {huddle_object args} {
    variable types

    checkHuddle $huddle_object

    set target_node [Find_node [unwrap $huddle_object] $args]

    foreach {tag src} $target_node break

    return $types(type:$tag)
}

proc ::huddle::Find_node {node path} {
    variable types

    set subnode $node

    foreach subpath $path {
        foreach {tag src} $subnode break
        set subnode [$types(callback:$tag) get_subnode $src $subpath]
    }

    return $subnode
}

proc ::huddle::exists {huddle_object args} {
    variable types

    checkHuddle $huddle_object

    set subnode [unwrap $huddle_object]

    foreach key $args {
        foreach {tag src} $subnode break
        if {$types(isContainer:$tag) && [$types(callback:$tag) exists $src $key] } {
            set subnode [$types(callback:$tag) get_subnode $src $key]
        } else {
            return 0
        }
    }

    return 1
}

proc ::huddle::equal {obj1 obj2} {
    checkHuddle $obj1
    checkHuddle $obj2
    return [::huddle::are_equal_nodes [unwrap $obj1] [unwrap $obj2]]
}

proc ::huddle::are_equal_nodes {node1 node2} {
    variable types

    foreach {tag1 src1} $node1 break
    foreach {tag2 src2} $node2 break
    if {$tag1 ne $tag2} {return 0}
    return [$types(callback:$tag1) equal $src1 $src2]
}

proc ::huddle::Append {objvar args} {
    variable types
    upvar 1 $objvar obj

    checkHuddle $obj
    
    foreach {tag src} [unwrap $obj] break
    set src [$types(callback:$tag) append_subnodes $tag $src $args]
    set obj [wrap [list $tag $src]]
    return $obj
}

proc ::huddle::Set {objvar args} {
    upvar 1 $objvar obj

    checkHuddle $obj
    set path [lrange $args 0 end-1]

    set new_subnode [argument_to_node [lindex $args end]]

    set root_node [unwrap $obj]

    # We delete the internal reference of $obj to $root_node
    # Now refcount of $root_node is 1
    unset obj

    Apply_to_subnode set root_node [llength $path] $path $new_subnode
    set obj [wrap $root_node]
}

proc ::huddle::remove {obj args} {
    checkHuddle $obj

    set modified_node [remove_node [unwrap $obj] [llength $args] $args]

    set obj [wrap $modified_node]
}

proc ::huddle::remove_node {node len path} {
    variable types

    foreach {tag src} $node break

    set first_key_to_removed_subnode [lindex $path 0]

    if {$len > 1} {
        if { $types(isContainer:$tag) } {

            set subpath_to_removed_subnode [lrange $path 1 end]

            incr len -1

            set new_src ""

            foreach item [$types(callback:$tag) items $src] {
                foreach {key subnode} $item break
                if {$key eq $first_key_to_removed_subnode} {
                    set modified_subnode [::huddle::remove_node $subnode $len $subpath_to_removed_subnode]
                    $types(callback:$tag) set new_src $key $modified_subnode
                } else {
                    set cloned_subnode [Clone_node $subnode]
                    $types(callback:$tag) set new_src $key $cloned_subnode
                }
            }
        
            return [list $tag $new_src]
        } else {
            error "\{$src\} don't have any child node."
        }
    } else {
        $types(callback:$tag) remove src $first_key_to_removed_subnode
        return [list $tag $src]
    }
}

proc ::huddle::Unset {objvar args} {
    upvar 1 $objvar obj
    checkHuddle $obj

    set root_node [unwrap $obj]

    # We delete the internal reference of $obj to $root_node
    # Now refcount of $root_node is 1
    unset obj

    Apply_to_subnode remove root_node [llength $args] $args

    set obj [wrap $root_node]
}

proc ::huddle::clone {obj} {
    set cloned_node [Clone_node [unwrap $obj]]

    return [wrap $cloned_node]
}

proc ::huddle::Clone_node {node} {
    variable types

    foreach {tag src} $node break

    if { $types(isContainer:$tag) } {
        set cloned_src ""

        foreach item [$types(callback:$tag) items $src] {
            foreach {key subnode} $item break
            set cloned_subnode [Clone_node $subnode]
            $types(callback:$tag) set cloned_src $key $cloned_subnode
        }
        return [list $tag $cloned_src]
    } else {
        return $node
    }
}

proc ::huddle::Apply_to_subnode {subcommand node_var len path {subcommand_arguments ""}} {
    variable types
    upvar 1 $node_var node

    foreach {tag src} $node break

    # We delete $src from $node.
    # In that position there is only an empty string.
    # This way, the refcount of $src is 1
    lset node 1 ""

    # We get the fist key. This information is used in the recursive case ($len>1) and in the base case ($len==1).
    set key [lindex $path 0]

    if {$len > 1} {

        set subpath [lrange $path 1 end]

        incr len -1

        if { $types(isContainer:$tag) } {

            set subnode [$types(callback:$tag) get_subnode $src $key]

            # We delete the internal reference of $src to $subnode.
            # Now refcount of $subnode is 1
            $types(callback:$tag) delete_subnode_but_not_key src $key

            ::huddle::Apply_to_subnode $subcommand subnode $len $subpath $subcommand_arguments

            # We add again the new $subnode to the original $src
            $types(callback:$tag) set src $key $subnode

            # We add again the new $src to the parent node
            lset node 1 $src

        } else {
            error "\{$src\} don't have any child node."
        }
    } else {
        if {![info exists types(type:$tag)]} {error "\{$src\} is not a huddle node."}

        $types(callback:$tag) $subcommand src $key $subcommand_arguments
        lset node 1 $src
    }
}

proc ::huddle::jsondump {huddle_object {offset "  "} {newline "\n"} {begin ""}} {
    variable types
    set nextoff "$begin$offset"
    set nlof "$newline$nextoff"
    set sp " "
    if {[string equal $offset ""]} {set sp ""}

    set type [huddle type $huddle_object]

    switch -- $type {
        boolean -
        number -
        null {
            return [huddle get_stripped $huddle_object]
        }

        string {
            set data [huddle get_stripped $huddle_object]

            # JSON permits only oneline string
            set data [string map {
                    \n \\n
                    \t \\t
                    \r \\r
                    \b \\b
                    \f \\f
                    \\ \\\\
                    \" \\\"
                    / \\/
                } $data
            ]
        return "\"$data\""
        }
        
        list {
            set inner {}
            set len [huddle llength $huddle_object]
            for {set i 0} {$i < $len} {incr i} {
                set subobject [huddle get $huddle_object $i]
                lappend inner [jsondump $subobject $offset $newline $nextoff]
            }
            if {[llength $inner] == 1} {
                return "\[[lindex $inner 0]\]"
            }
            
            return "\[$nlof[join $inner ,$nlof]$newline$begin\]"
        }
        
        dict {
            set inner {}
            foreach {key} [huddle keys $huddle_object] {
                lappend inner [subst {"$key":$sp[jsondump [huddle get $huddle_object $key] $offset $newline $nextoff]}]
            }
            if {[llength $inner] == 1} {
                return $inner
            }
            return "\{$nlof[join $inner ,$nlof]$newline$begin\}"
        }
        
        default {
            return [$types(callback:$type) jsondump $data $offset $newline $nextoff]
        }
    }
}

# data is plain old tcl values
# spec is defined as follows:
# {string} - data is simply a string, "quote" it if it's not a number
# {list} - data is a tcl list of strings, convert to JSON arrays
# {list list} - data is a tcl list of lists
# {list dict} - data is a tcl list of dicts
# {dict} - data is a tcl dict of strings
# {dict xx list} - data is a tcl dict where the value of key xx is a tcl list
# {dict * list} - data is a tcl dict of lists
# etc..

proc ::huddle::compile {spec data} {
    while {[llength $spec]} {
        set type [lindex $spec 0]
        set spec [lrange $spec 1 end]

        switch -- $type {
            dict {
                if {![llength $spec]} {
                    lappend spec * string
                }

                set result [huddle create]
                foreach {key value} $data {
                    foreach {matching_key subspec} $spec {
                        if {[string match $matching_key $key]} {
                            Append result $key [compile $subspec $value]
                            break
                        }
                    }
                }
                
                return $result
            }
            
            list {
                if {![llength $spec]} {
                    set spec string
                } else {
                    set spec [lindex $spec 0]
                }
                
                set result [huddle list]
                foreach list_item $data {
                    Append result [compile $spec $list_item]
                }
            
                return $result
            }
        
            string {
                return [wrap [list s $data]]
            }
        
            number {
                if {[string is double -strict $data]} {
                    return [wrap [list num $data]]
                } else {
                    error "Bad number: $data"
                }
            }
        
            bool {
                if {$data} {
                    return [wrap [list bool true]]
                } else {
                    return [wrap [list bool false]]
                }
            }
        
            null {
                if {$data eq ""} {
                    return [wrap [list null]]
                } else {
                    error "Data must be an empty string: '$data'"
                }
            }
        
            huddle {
                if {[isHuddle $data]} {
                    return $data
                } else {
                    error "Data is not a huddle object: $data"
                }
            }
        
            default {error "Invalid type: '$type'"}
        }
    }
}

apply {{selfdir} {
    source [file join $selfdir huddle_types.tcl]

    foreach typeNamespace [namespace children ::huddle::types] {
        addType $typeNamespace
    }

    return
} ::huddle} [file dirname [file normalize [info script]]]
return
