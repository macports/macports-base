#
#   YAML parser for Tcl.
#
#   See http://www.yaml.org/spec/1.1/
#
#   yaml.tcl,v 0.3.6 2011-08-23 15:06:25 KATO Kanryu(kanryu6@users.sourceforge.net)
#
#   It is published with the terms of tcllib's BSD-style license.
#   See the file named license.terms.
#
# It currently supports a very limited subsection of the YAML spec.
#
#

package require Tcl 8.5
package provide yaml 0.4.1
package require cmdline
package require huddle 0.1.7

namespace eval ::yaml {
    namespace export load setOptions dict2dump list2dump
    variable data
    array set data {}

    # fixed value groups for some yaml-types.
    variable fixed

    # a plane scalar is worked for matching and converting to the specific type.
    # proc some_command {value} {
    #   return [list !!type $treatmented-value]
    #     or
    #   return ""
    # }
    variable parsers

    # scalar/collection treatment for matched specific yaml-tag
    # proc some_composer {type value} {
    #   return [list 1 $result-type $treatmented-value]
    #     or
    #   return ""
    # }
    variable composer

    variable defaults
    array set defaults {
        isfile   0
        validate 0
        types {timestamp int float null true false}
        composer {
            !!binary ::yaml::_composeBinary
	    !!float  ::yaml::_composeFloat
        }
        parsers {
            timestamp ::yaml::_parseTimestamp
        }
        shorthands {
            !! {tag:yaml.org,2002:}
        }
        fixed {
            null:Value  ""
            null:Group  {null "" ~}
            true:Value  1
            true:Group  {true on + yes y}
            false:Value 0
            false:Group {false off - no n}
        }
    }

    variable _dumpIndent   2
    variable _dumpWordWrap 40

    variable result
    variable opts [lrange [::cmdline::GetOptionDefaults {
        {file             {input is filename}}
        {stream           {input is stream}}
        {m.arg        ""  {fixed-modifiers bulk settings(null/true/false)}}
        {m:null.arg   ""  {null modifier settings(default {"" {null "" ~}})}}
        {m:true.arg   ""  {true modifier settings(default {1 {true on + yes y}})}}
        {m:false.arg  ""  {false modifier settings(default {0 {false off - no n}})}}
        {types.arg    ""  {modifier list settings(default {nop timestamp integer null true false})}}
        {validate         {to validate the input(not dumped tcl content)}}
    } result] 2 end] ;# Remove ? and help.

    variable errors
    array set errors {
        TAB_IN_PLAIN        {Tabs can be used only in comments, and in quoted "..." '...'.}
        AT_IN_PLAIN         {Reserved indicators {@} can't start a plain scalar.}
        BT_IN_PLAIN         {Reserved indicators {`} can't start a plain scalar.}
        SEQEND_NOT_IN_SEQ   {There is a flow-sequence end '\]' not in flow-sequence [v, ...].}
        MAPEND_NOT_IN_MAP   {There is a flow-mapping end '\}' not in flow-mapping {k: v, ...}.}
        ANCHOR_NOT_FOUND    {Could not find the anchor-name(current-version, "after refering" is not supported)}
        MALFORM_D_QUOTE     {Double quote "..." parsing error. end of quote is missing?}
        MALFORM_S_QUOTE     {Single quote '...' parsing error. end of quote is missing?}
        TAG_NOT_FOUND       {The "$p1" handle wasn't declared.}
        INVALID_MERGE_KEY   {merge-key "<<" is not impremented in not mapping scope(e.g. in sequence).}
        MALFORMED_MERGE_KEY {malformed merge-key "<<" using.}
    }
}

####################
# Public APIs
####################

proc ::yaml::yaml2dict {args} {
    variable data
    _getOption $args

    set result [_parseBlockNode]

    set a [huddle get_stripped $result]

    if {$data(validate)} {
        set result [string map "{\n} {\\n}" $result]
    }

    return [huddle get_stripped $result]
}

proc ::yaml::yaml2huddle {args} {
    variable data
    _getOption $args

    set result [_parseBlockNode]
    if {$data(validate)} {
        set result [string map "{\n} {\\n}" $result]
    }
    return $result
}

proc ::yaml::setOptions {argv} {
    variable defaults
    array set options [_imp_getOptions argv]
    array set defaults [array get options]
}

# Dump TCL List to YAML
#

proc ::yaml::list2yaml {list {indent 2} {wordwrap 40}} {
    return [huddle2yaml [huddle list {*}$list] $indent $wordwrap]
}

proc ::yaml::dict2yaml {dict {indent 2} {wordwrap 40}} {
    return [huddle2yaml [huddle create {*}$dict] $indent $wordwrap]
}

proc ::yaml::huddle2yaml {huddle {indent 2} {wordwrap 40}} {
    set yaml::_dumpIndent   $indent
    set yaml::_dumpWordWrap $wordwrap

    # Start at the base of the array and move through it.
    set out [join [list "---\n" [_imp_huddle2yaml $huddle] "\n"] ""]
    return $out
}


####################
# Option settings
####################

proc ::yaml::_getOption {argv} {
    variable data
    variable parsers
    variable fixed
    variable composer

    # default settings
    array set options [_imp_getOptions argv]

    array set fixed    $options(fixed)
    array set parsers  $options(parsers)
    array set composer $options(composer)
    array set data [list validate $options(validate) types $options(types)]
    set isfile $options(isfile)

    foreach {buffer} $argv break
    if {$isfile} {
        set fd [open $buffer r]
        set buffer [read $fd]
        close $fd
    }
    set data(buffer) $buffer
    set data(start)  0
    set data(length) [string length $buffer]
    set data(current) 0
    set data(finished) 0
}

proc ::yaml::_imp_getOptions {{argvvar argv}} {
    upvar 1 $argvvar argv

    variable defaults
    variable opts
    array set options [array get defaults]

    # default settings
    array set fixed $options(fixed)

    # parse argv
    set argc [llength $argv]
    while {[set err [::cmdline::getopt argv $opts opt arg]]} {
        if {$err eq -1} break
        switch -- $opt {
            "file" {
                set options(isfile) 1
            }
            "stream" {
                set options(isfile) 0
            }
            "m" {
                array set options(fixed) $arg
            }
            "validate" {
                set options(validate) 1
            }
            "types" {
                set options(types) $arg
            }
            default {
                if {[regexp {m:(\w+)} $opt nop type]} {
                    if {$arg eq ""} {
                        set fixed(${type}:Group) ""
                    } else {
                        foreach {value group} $arg {
                            set fixed(${type}:Value) $value
                            set fixed(${type}:Group) $group
                        }
                    }
                }
            }
        }
    }
    set options(fixed) [array get fixed]
    return [array get options]
}

#########################
# Scalar/Block Composers
#########################
proc ::yaml::_composeTags {tag value} {
    variable composer
    if {$tag eq ""} {return $value}
    set value [huddle get_stripped $value]
    if {$tag eq "!!str"} {
        set pair [list $tag $value]
    } elseif {[info exists composer($tag)]} {
        set pair [$composer($tag) $value]
    } else {
        error [_getErrorMessage TAG_NOT_FOUND $tag]
    }
    return  [huddle wrap $pair]
}

proc ::yaml::_composeFloat {value} {
    return [list !!float [expr {double($value)}]]
}

proc ::yaml::_composeBinary {value} {
    package require base64
    return [list !!binary [::base64::decode $value]]
}

proc ::yaml::_composePlain {value} {
    if {$value ne ""} {
        if {[huddle type $value] ne "plain"} {return $value}
        set value [huddle get_stripped $value]
    }
    set pair [_toType $value]
    return  [huddle wrap $pair]
}

proc ::yaml::_toType {value} {
    variable data
    variable parsers
    variable fixed
    if {$value eq ""} {return [list !!str ""]}

    set lowerval [string tolower $value]
    foreach {type} $data(types) {
        if {[info exists parsers($type)]} {
            set pair [$parsers($type) $value]
            if {$pair ne ""} {return $pair}
            continue
        }
        switch -- $type {
            int {
                # YAML 1.1
                if {[regexp {^-?\d[\d,]*\d$|^\d$} $value]} {
                    regsub -all "," $value "" integer
                    return [list !!int $integer]
                }
            }
            float {
                # don't run before "integer"
                regsub -all "," $value "" val
                if {[string is double $val]} {
                    return [list !!float $val]
                }
            }
            default {
                # !!null !!true !!false
                if {[info exists fixed($type:Group)] \
                 && [lsearch $fixed($type:Group) $lowerval] >= 0} {
                    set value $fixed($type:Value)
                    return [list !!$type $value]
                }
            }
        }
    }

    # the others
    return [list !!str $value]
}

####################
# Block Node parser
####################
proc ::yaml::_parseBlockNode {{status ""} {indent -1}} {
    variable data
    set prev {}
    set result {}
    set scalar 0
    set pos 0
    set tag ""
    while {1} {
        if {$data(finished) == 1} {
            break
        }
        _skipSpaces 1
        set type [_getc]
        set current [_getCurrent]
        if {$type eq "-"} {
            set cc "[_getc][_getc]"
            if {"$type$cc" eq "---" && $current == 0} {
                set result {}
                continue
            } else {
                _ungetc 2

                # [Spec]
                # Since people perceive the "-" indicator as indentation,
                # nested block sequences may be indented by one less space
                # to compensate, except, of course,
                # if nested inside another block sequence.
                incr current
            }
        }
        if {$type eq "."} {
            set cc "[_getc][_getc]"
            if {"$type$cc" eq "..." && $current == 0} {
                set data(finished) 1
                break
            } else {
                _ungetc 2

#                 # [Spec]
#                 # Since people perceive the "-" indicator as indentation,
#                 # nested block sequences may be indented by one less space
#                 # to compensate, except, of course,
#                 # if nested inside another block sequence.
#                 incr current
            }
        }
        if {$type eq ""  || $current <= $indent} { ; # end document
            _ungetc
            break
        }
        switch -- $type {
            "-" { ; # block sequence entry
                set pos $current
                # [196]      l-block-seq-entry(n,c)
                foreach {scalar value} [_parseSubBlock $pos "SEQUENCE"] break
            }
            "?" { ; # mapping key
                foreach {scalar nop} [_parseSubBlock $pos ""] break
            }
            ":" { ; # mapping value
                if {$current < $pos} {set pos [expr {$current+1}]}
                foreach {scalar value} [_parseSubBlock $pos "MAPPING"] break
            }
            "|" { ; # literal block scalar
                set value [_parseBlockScalar $indent "\n"]
            }
            ">" { ; # folded block scalar
                set value [_parseBlockScalar $indent " "]
            }
            "<" { ; # mergeing
                set c [_getc]
                if {"$type$c" eq "<<"} {
                    set pos [_getCurrent]
                    _skipSpaces 1
                    set c [_getc]
                    if {$c ne ":"} {error [_getErrorMessage INVALID_MERGE_KEY]}
                    if {$status ne "" && $status ne "MAPPING"} {error [_getErrorMessage INVALID_MERGE_KEY]}
                    set status "MAPPING"
                    foreach {result prev} [_mergeExpandedAliases $result $pos $prev] break
                } else {
                    _ungetc
                    set scalar 1
                }
            }
            "&" { ; # node's anchor property
                set anchor [_getToken]
            }
            "*" { ; # alias node
                set alias [_getToken]
                if {$data(validate)} {
                    set status "ALIAS"
                    set value *$alias
                } else {
                    set value [_getAnchor $alias]
                }
            }
            "!" { ; # node's tag
                _ungetc
                set tag [_getToken]
            }
            "%" { ; # directive line
                _getLine
            }
            default {
                if {[regexp {^[\[\]\{\}\"']$} $type]} {
                    set pos [expr {1 + $current}]
                    _ungetc
                    set value [_parseFlowNode]
                } else {
                    set scalar 1
                }
            }
        }
        if {$scalar} {
            set pos [_getCurrent]
            _ungetc
            set value [_parseScalarNode $type "BLOCK" $pos]
            set value [_composeTags $tag $value]
            set tag ""
            set scalar 0
        }
        if {[info exists value]} {
            if {$status eq "NODE"} {return $value}
            foreach {result prev} [_pushValue $result $prev $status $value "BLOCK"] break
            unset value
        }
    }
    if {$status eq "SEQUENCE"} {
        set result [huddle sequence {*}$result]
    } elseif {$status eq "MAPPING"} {
        if {[llength $prev] == 2} {
            set result [_set_huddle_mapping $result $prev]
        }
    } else {
        if {[info exists prev]} {
            set result $prev
        }
        set result [lindex $result 0]
        set result [_composePlain $result]
        if {![huddle isHuddle $result]} {
            set result [huddle wrap [list !!str $result]]
        }
    }
    if {$tag ne ""} {
        set result [_composeTags $tag $result]
        unset tag
    }
    if {[info exists anchor]} {
        _setAnchor $anchor $result
        unset anchor
    }
    return $result
}

proc ::yaml::_mergeExpandedAliases {result pos prev} {
    if {$result eq ""} {set result [huddle mapping]}
    if {$prev ne ""} {
        if {[llength $prev] < 2} {error [_getErrorMessage MALFORMED_MERGE_KEY]}
        set result [_set_huddle_mapping $result $prev]
        set prev {}
    }

    set value [_parseBlockNode "" $pos]
    set type_name [huddle type $value]

    if {$type_name eq "list" || $type_name  eq "sequence"} {
        set len [huddle llength $value]
        for {set i 0} {$i < $len} {incr i} {
            set sub [huddle get $value $i]
            set result [huddle combine $result $sub]
        }

    } else {
        set result [huddle combine $result $value]
    }
    return [list $result $prev]
}

proc ::yaml::_parseSubBlock {pos statusnew} {
    upvar 1 status status
    set scalar 0
    set value ""
    if {[_next_is_blank]} {
        if {$statusnew ne ""} {
            set status $statusnew
            set value [_parseBlockNode "" $pos]
        }
    } else {
        _ungetc
        set scalar 1
    }
    return [list $scalar $value]
}

proc ::yaml::_set_huddle_mapping {result prev} {

    foreach {key val} $prev break

    set val [_composePlain $val]
    if {[huddle isHuddle $key]} {
        set key [huddle get_stripped $key]
    }


    if {$result eq ""} {
        set result [huddle mapping $key $val]
    } else {
        huddle append result $key $val
    }
    return $result
}


# remove duplications with saving key order
proc ::yaml::_remove_duplication {dict} {
    array set tmp $dict
    array set tmp2 {}
    foreach {key nop} $dict {
        if {[info exists tmp2($key)]} continue
        lappend result $key $tmp($key)
        set tmp2($key) 1
    }
    return $result
}


# literal "|" (line separator is "\n")
# folding ">" (line separator is " ")
proc ::yaml::_parseBlockScalar {base separator} {
    foreach {explicit chomping} [_parseBlockIndicator] break

    set idch [string repeat " " $explicit]
    set sep $separator
    foreach {indent c line} [_getLine] break
    if {$indent < $base} {return ""}
    # the first line, NOT ignored comment (as a normal-string)
    set first $indent
    set value $line
    set stop 0

    while {![_eof]} {
        set pos [_getpos]
        foreach {indent c line} [_getLine] break
        if {$line eq ""} {
            regsub " " $sep "" sep
            append sep "\n"
            continue
        }
        if {$c eq "#"} {
            # skip comments
            continue
        }
        if {$indent <= $base} {
            set stop 1
            break
        }
        append value $sep[string repeat " " [expr {$indent - $first}]]$line
        set sep $separator
    }
    if {[info exists pos] && $stop} {_setpos $pos}
    switch -- $chomping {
        "strip" {
        }
        "keep" {
            append value $sep
        }
        "clip" {
            append value "\n"
        }
	default {
	    error "Should not be reached (chomping = $chomping)"
	}
    }
    return [huddle wrap [list !!str $value]]
}

# in {> |}
proc ::yaml::_parseBlockIndicator {} {
    set chomping "clip"
    set explicit 0
    while {1} {
        set type [_getc]
        if {[regexp {[1-9]} $type digit]} { ; # block indentation
            set explicit $digit
        } elseif {$type eq "-"} {   ; # strip chomping
            set chomping "strip"
        } elseif {$type eq "+"} {   ; # keep chomping
            set chomping "keep"
        } else {
            _ungetc
            break
        }
    }
    # Note: skipped after the indicator
    _getLine
    return [list $explicit $chomping]
}

# [162]    ns-plain-multi(n,c)
proc ::yaml::_parsePlainScalarInBlock {base {loop 0}} {
    if {$loop == 5} { return }
    variable data
    set start $data(start)
    set reStr {(?:[^:#\t \n]*(?::[^\t \n]+)*(?:#[^\t \n]+)* *)*[^:#\t \n]*}
    set result [_getFoldedString $reStr]

    set result [string trim $result]
    set c [_getc 0]
    if {$c eq "\n" || $c eq "#"} { ; # multi-line
        set lb ""
        while {1} {
            set fpos [_getpos]
            foreach {indent nop line} [_getLine] break
            if {[_eof]} {break}

            if {$line ne "" && [string index $line 0] ne "#"} {
                break
            }
            append lb "\n"
        }
        set lb [string range $lb 1 end]
        if {!$data(finished)} {
            _setpos $fpos
        }
        if {$start == $data(start)} {
            return $result
        }
        if {$base <= $indent} {
            if {$lb eq ""} {
                set lb " "
            }
            set subs [_parsePlainScalarInBlock $base [expr {$loop+1}]]
           if {$subs ne ""} {
                append result "$lb$subs"
            }
        }
    }
    return $result
}

####################
# Flow Node parser
####################
proc ::yaml::_parseFlowNode {{status ""}} {
    set scalar 0
    set result {}
    set tag ""
    set prev {}
    while {1} {
        _skipSpaces 1
        set type [_getc]
        switch -- $type {
            "" {
                break
            }
            "?" -
            ":" { ; # mapping value
                if {[_next_is_blank]} {
                    set value [_parseFlowNode "NODE"]
                } else {
                    set scalar 1
                }
            }
            "," { ; # ends a flow collection entry
                if {$status eq"NODE"} {
                    _ungetc
                    return $value
                }
            }
            "\{" { ; # starts a flow mapping
                set value [_parseFlowNode "MAPPING"]
            }
            "\}" { ; # ends a flow mapping
                if {$status ne "MAPPING"}  {error [_getErrorMessage MAPEND_NOT_IN_MAP] }
                return $result
            }
            "\[" { ; # starts a flow sequence
                 set value [_parseFlowNode "SEQUENCE"]
            }
            "\]" { ; # ends a flow sequence
                if {$status ne "SEQUENCE"} {error [_getErrorMessage SEQEND_NOT_IN_SEQ] }
                set result [huddle sequence {*}$result]
                return $result
            }
            "&" { ; # node's anchor property
                set anchor [_getToken]
            }
            "*" { ; # alias node
                set alias [_getToken]
                set value [_getAnchor $alias]
            }
            "!" { ; # node's tag
                _ungetc
                set tag [_getToken]
            }
            "%" { ; # directive line
                _ungetc
                _parseDirective
            }
            default {
                set scalar 1
            }
        }
        if {$scalar} {
            _ungetc
            set value [_parseScalarNode $type "FLOW"]
            set value [_composeTags $tag $value]
            set tag ""
            set scalar 0
        }
        if {[info exists value]} {
            if {[info exists anchor]} {
                _setAnchor $anchor $value
                unset anchor
            }
            if {$status eq "" || $status eq "NODE"} {return $value}
            foreach {result prev} [_pushValue $result $prev $status $value "FLOW"] break
            unset value
        }
    }
    return $result
}

proc ::yaml::_pushValue {result prev status value scope} {
    switch -- $status {
        "SEQUENCE" {
            lappend result [_composePlain $value]
        }
        "MAPPING" {
            if {$scope eq "BLOCK"} {
                if {[llength $prev] == 2} {
                    set result [_set_huddle_mapping $result $prev]
                    set prev [list $value]
                } else {
                    lappend prev $value
                }
            } else {
                lappend prev $value
                if {[llength $prev] == 2} {
                    set result [_set_huddle_mapping $result $prev]
                    set prev ""
                }
            }
        }
        default {
            if {$scope eq "BLOCK"} {lappend prev $value}
        }
    }
    return [list $result $prev]
}

proc ::yaml::_parseScalarNode {type scope {pos 0}} {
    set tag !!str
    switch -- $type {
        \" { ; # surrounds a double-quoted flow scalar
            set value [_parseDoubleQuoted]
        }
        {'} { ; # surrounds a single-quoted flow scalar
            set value [_parseSingleQuoted]
        }
        "\t" {error [_getErrorMessage TAB_IN_PLAIN] }
        "@"  {error [_getErrorMessage AT_IN_PLAIN] }
        "`"  {error [_getErrorMessage BT_IN_PLAIN] }
        default {
            # Plane Scalar
            if       {$scope eq "FLOW"} {
                set value [_parsePlainScalarInFlow]
            } elseif {$scope eq "BLOCK"} {
                set value [_parsePlainScalarInBlock $pos]
            }
            set tag !!plain
        }
    }
    return [huddle wrap [list $tag $value]]
}

# [time scanning at JST]
# 2001-12-15T02:59:43.1Z       => 1008385183
# 2001-12-14t21:59:43.10-05:00 => 1008385183
# 2001-12-14 21:59:43.10 -5    => 1008385183
# 2001-12-15 2:59:43.10        => 1008352783
# 2002-12-14                   => 1039791600
proc ::yaml::_parseTimestamp {scalar} {
    if {![regexp {^\d\d\d\d-\d\d-\d\d} $scalar]} {return ""}
    set datestr  {\d\d\d\d-\d\d-\d\d}
    set timestr  {\d\d?:\d\d:\d\d}
    set timezone {Z|[-+]\d\d?(?::\d\d)?}

    set canonical [subst -nobackslashes -nocommands {^($datestr)[Tt ]($timestr)\.\d+ ?($timezone)?$}]
    set dttm [subst -nobackslashes -nocommands {^($datestr)(?:[Tt ]($timestr))?$}]
    if {$::tcl_version < 8.5} {
        if {[regexp $canonical $scalar nop dt tm zone]} {
            # Canonical
            if {$zone eq ""} {
                return [list !!timestamp [clock scan "$dt $tm"]]
            } elseif {$zone eq "Z"} {
                return [list !!timestamp [clock scan "$dt $tm" -gmt 1]]
            }
            if {[regexp {^([-+])(\d\d?)$} $zone nop sign d]} {set zone [format "$sign%02d:00" $d]}
            regexp {^([-+]\d\d):(\d\d)} $zone nop h m
            set m [expr {$h > 0 ? $h*60 + $m : $h*60 - $m}]
            return [list !!timestamp [clock scan "[expr {-$m}] minutes" -base [clock scan "$dt $tm" -gmt 1]]]
        } elseif {[regexp $dttm $scalar nop dt tm]} {
            if {$tm ne ""} {
                return [list !!timestamp [clock scan "$dt $tm"]]
            } else {
                return [list !!timestamp [clock scan $dt]]
            }
        }
    } else {
        if {[regexp $canonical $scalar nop dt tm zone]} {
            # Canonical
            if {$zone ne ""} {
                if {[regexp {^([-+])(\d\d?)$} $zone nop sign d]} {set zone [format "$sign%02d:00" $d]}
                return [list !!timestamp [clock scan "$dt $tm $zone" -format {%Y-%m-%d %k:%M:%S %Z}]]
            } else {
                return [list !!timestamp [clock scan "$dt $tm"       -format {%Y-%m-%d %k:%M:%S}]]
            }
        } elseif {[regexp $dttm $scalar nop dt tm]} {
            if {$tm ne ""} {
                return [list !!timestamp [clock scan "$dt $tm" -format {%Y-%m-%d %k:%M:%S}]]
            } else {
                return [list !!timestamp [clock scan $dt       -format {%Y-%m-%d}]]
            }
        }
    }
    return ""
}


proc ::yaml::_parseDirective {} {
    variable data
    variable shorthands

    set directive [_getToken]

    if {[regexp {^%YAML} $directive]} {
        # YAML directive
        _skipSpaces
        set version [_getToken]
        set data(YAMLVersion) $version
        if {![regexp {^\d\.\d$} $version]}   { error [_getErrorMessage ILLEGAL_YAML_DIRECTIVE] }
    } elseif {[regexp {^%TAG} $directive]} {
        # TAG directive
        _skipSpaces
        set handle [_getToken]
        if {![regexp {^!$|^!\w*!$} $handle]} { error [_getErrorMessage ILLEGAL_YAML_DIRECTIVE] }

        _skipSpaces
        set prefix [_getToken]
        if {![regexp {^!$|^!\w*!$} $prefix]} { error [_getErrorMessage ILLEGAL_YAML_DIRECTIVE] }
        set shorthands(handle) $prefix
    }
}

proc ::yaml::_parseTagHandle {} {
    set token [_getToken]

    if {[regexp {^(!|!\w*!)(.*)} $token nop handle named]} {
        # shorthand or non-specific Tags
        switch -- $handle {
            ! { ;       # local or non-specific Tags
            }
            !! { ;      # yaml Tags
            }
            default { ; # shorthand Tags

            }
        }
        if {![info exists prefix($handle)]} { error [_getErrorMessage TAG_NOT_FOUND] }
    } elseif {[regexp {^!<(.+)>} $token nop uri]} {
        # Verbatim Tags
        if {![regexp {^[\w:/]$} $token nop uri]} { error [_getErrorMessage ILLEGAL_TAG_HANDLE] }
    } else {
        error [_getErrorMessage ILLEGAL_TAG_HANDLE]
    }

    return "!<$prefix($handle)$named>"
}


proc ::yaml::_parseDoubleQuoted {} {
    # capture quoted string with backslash sequences
    set reStr {(?:(?:\")(?:[^\\\"]*(?:\\.[^\\\"]*)*)(?:\"))}
    set result [_getFoldedString $reStr]
    if {$result eq ""} { error [_getErrorMessage MALFORM_D_QUOTE] }

    # [116] nb-double-multi-line
    regsub -all {[ \t]*\n[\t ]*} $result "\r" result
    regsub -all {([^\r])\r} $result {\1 } result
    regsub -all { ?\r} $result "\n" result
    # [112] s-s-double-escaped(n)
    # is not impremented.(specification ???)

    # chop off outer ""s and substitute backslashes
    # This does more than the RFC-specified backslash sequences,
    # but it does cover them all
    set chopped [subst -nocommands -novariables \
        [string range $result 1 end-1]]
    return $chopped
}

proc ::yaml::_parseSingleQuoted {} {
    set reStr {(?:(?:')(?:[^']*(?:''[^']*)*)(?:'))}
    set result [_getFoldedString $reStr]
    if {$result eq ""} { error [_getErrorMessage MALFORM_S_QUOTE] }

    # [126] nb-single-multi-line
    regsub -all {[ \t]*\n[\t ]*} $result "\r" result
    regsub -all {([^\r])\r} $result {\1 } result
    regsub -all { ?\r} $result "\n" result

    regsub -all {''} [string range $result 1 end-1] {'} chopped

    return $chopped
}


# [155]     nb-plain-char-in
proc ::yaml::_parsePlainScalarInFlow {} {
    set sep {\t \n,\[\]\{\}}
    set reStr {(?:[^$sep:#]*(?::[^$sep]+)*(?:#[^$sep]+)* *)*[^$sep:#]*}
    set reStr [subst -nobackslashes -nocommands $reStr]
    set result [_getFoldedString $reStr]
    set result [string trim $result]

    if {[_getc 0] eq "#"} {
        _getLine
        set result "$result [_parsePlainScalarInFlow]"
    }
    return $result
}

####################
# Generic parser
####################
proc ::yaml::_getFoldedString {reStr} {
    variable data

    set buff [string range $data(buffer) $data(start) end]
    regexp $reStr $buff token
    if {![info exists token]} {return}

    set len [string length $token]
    if {[string first "\n" $token] >= 0} { ; # multi-line
        set data(current) [expr {$len - [string last "\n" $token]}]
    } else {
        incr data(current) $len
    }
    incr data(start) $len

    return $token
}

# get a space separated token
proc ::yaml::_getToken {} {
    variable data

    set reStr {^[^ \t\n,\]]+}
    set result [_getFoldedString $reStr]
    return $result
}

proc ::yaml::_skipSpaces {{commentSkip 0}} {
    variable data

    while {1} {
        set ch [string index $data(buffer) $data(start)]
        incr data(start)
        switch -- $ch {
            " " {
                incr data(current)
                continue
            }
            "\n" {
                set data(current) 0
                continue
            }
            "\#" {
                if {$commentSkip} {
                    _getLine
                    continue
                }
            }
	    default {
		# Any other character, do nothing
	    }
        }
        break
    }
    incr data(start) -1
}

# get a line of stream(line-end trimed)
# (cannot _ungetc)
proc ::yaml::_getLine {{scrolled 1}} {
    variable data

    set pos [string first "\n" $data(buffer) $data(start)]
    if {$pos == -1} {
        set pos $data(length)
    }
    set line [string range $data(buffer) $data(start) [expr {$pos-1}]]
    if {$line eq "..." && $data(current) == 0} {
        set data(finished) 1
    }
    regexp {^( *)(.*)} $line nop space result
    if {$scrolled} {
        set data(start) [expr {$pos + 1}]
        set data(current) 0
    }
    if {$line == "" && $data(start) == $data(length)} {
        set data(finished) 1
    }
    return [list [string length $space] [string index $result 0] $result]
}

proc ::yaml::_getCurrent {} {
    variable data
    return [expr {$data(current) ? $data(current)-1 : 0}]
}

proc ::yaml::_getLineNum {} {
    variable data
    set prev [string range $data(buffer) 0 $data(start)]
    return [llength [split $prev "\n"]]
}

proc ::yaml::_getc {{scrolled 1}} {
    variable data

    set result [string index $data(buffer) $data(start)]
    if {$scrolled} {
        incr data(start)
        if {$result eq "\n"} {
            set data(current) 0
        } else {
            incr data(current)
        }
    }
    return $result
}

proc ::yaml::_eof {} {
    variable data
    return [expr {$data(finished) || $data(start) == $data(length)}]
}


proc ::yaml::_getpos {} {
    variable data
    return $data(start)
}

proc ::yaml::_setpos {pos} {
    variable data
    set data(start) $pos
}

proc ::yaml::_ungetc {{len 1}} {
    variable data
    incr data(start) [expr {-$len}]
    incr data(current) [expr {-$len}]
    if {$data(current) < 0} {
        set prev [string range $data(buffer) 0 $data(start)]
        if {[string index $prev end] eq "\n"} {set prev [string replace $prev end end a]}
        set data(current) [expr {$data(start) - [string last "\n" $prev] - 1}]
    }
}

proc ::yaml::_next_is_blank {} {
    set c [_getc 0]
    if {$c eq " " || $c eq "\n"} {
        return 1
    } else {
        return 0
    }
}

proc ::yaml::_setAnchor {anchor value} {
    variable data
    set data(anchor:$anchor) $value
}

proc ::yaml::_getAnchor {anchor} {
    variable data
    if {![info exists data(anchor:$anchor)]} {error [_getErrorMessage ANCHOR_NOT_FOUND]}
    return  $data(anchor:$anchor)
}

proc ::yaml::_getErrorMessage {ID {p1 ""}} {
    variable errors
    set num [_getLineNum]
    if {$p1 != ""} {
        return "line($num): [subst -nobackslashes -nocommands $errors($ID)]"
    } else {
        return "line($num): $errors($ID)"
    }
}

# Finds and returns the indentation of a YAML line
proc ::yaml::_getIndent {line} {
    set match [regexp -inline -- {^\s{1,}} " $line"]
    return [expr {[string length $match] - 3}]
}


################
## Dumpers    ##
################

proc ::yaml::_imp_huddle2yaml {data {offset ""}} {
    variable _dumpIndent
    set nextoff "$offset[string repeat { } $_dumpIndent]"
    switch -- [huddle type $data] {
        "string" {
            set data [huddle get_stripped $data]
            return [_dumpScalar $data $offset]
        }
        "list" {
            set inner {}
            set len [huddle llength $data]
            for {set i 0} {$i < $len} {incr i} {
                set sub [huddle get $data $i]
                set sep [expr {[huddle type $sub] eq "string" ? " " : "\n"}]
                lappend inner [join [list $offset - $sep [_imp_huddle2yaml $sub $nextoff]] ""]
            }
            return [join $inner "\n"]
        }
        "dict" {
            set inner {}
            foreach {key} [huddle keys $data] {
                set sub [huddle get $data $key]
                set sep [expr {[huddle type $sub] eq "string" ? " " : "\n"}]
                lappend inner [join [list $offset $key: $sep [_imp_huddle2yaml $sub $nextoff]] ""]
            }
            return [join $inner "\n"]
        }
        default {
            return $data
        }
    }
}

proc ::yaml::_dumpScalar {value offset} {
    if {   [string first "\n" $value] >= 0
        || [string first ": " $value] >= 0
        || [string first "- " $value] >= 0} {
        return [_doLiteralBlock $value $offset]
    } else {
        return [_doFolding $value $offset]
    }
}

# Creates a literal block for dumping
proc ::yaml::_doLiteralBlock {value offset} {
    if {[string index $value end] eq "\n"} {
        set newValue "|"
        set value [string range $value 0 end-1]
    } else {
        set newValue "|-"
    }
    set exploded [split $value "\n"]

    set value [string trimright $value]
    foreach {line} $exploded {
        set newValue "$newValue\n$offset[string trim $line]"
    }
    return $newValue
}

# Folds a string of text, if necessary
proc ::yaml::_doFolding {value offset} {
    variable _dumpWordWrap
    # Don't do anything if wordwrap is set to 0
    if {$_dumpWordWrap == 0} {
        return $value
    }

    if {[string length $value] > $_dumpWordWrap} {
        set wrapped [_simple_justify $value $_dumpWordWrap "\n$offset"]
        set value ">\n$offset$wrapped"
    }
    return $value
}

# http://wiki.tcl.tk/1774
proc ::yaml::_simple_justify {text width {wrap \n} {cut 0}} {
    set brk ""
    for {set result {}} {[string length $text] > $width} {
                set text [string range $text [expr {$brk+1}] end]
            } {
        set brk [string last " " $text $width]
        if { $brk < 0 } {
            if {$cut == 0} {
                append result $text
                return $result
            } else {
                set brk $width
            }
        }
        append result [string range $text 0 $brk] $wrap
    }
    return $result$text
}

########################
##    YAML TYPES      ##
########################

namespace eval ::yaml::types {
    namespace eval mapping {
    variable settings
        set settings {
        superclass dict
        publicMethods {mapping}
        tag !!map
        isContainer yes }

        proc mapping {args} {
            if {[llength $args] % 2} {error {wrong # args: should be "huddle mapping ?key value ...?"}}
            set resultL {}
            foreach {key value} $args {
                lappend resultL $key [argument_to_node $value !!str]
            }
            return [huddle wrap [list !!map $resultL]]
        }

    }

    namespace eval sequence {
	variable settings

        set settings {
	    superclass list
	    publicMethods {sequence}
	    isContainer yes
	    tag !!seq
	}

        proc sequence {args} {
            set resultL {}
            foreach {value} $args {
                lappend resultL [argument_to_node $value !!str]
            }
            return [wrap [list !!seq $resultL]]
        }

    }
}

proc ::yaml::_makeChildType {type tag} {
    set full_path_to_type ::yaml::types::$type
    namespace eval $full_path_to_type [string map [list @TYPE@ $type @TAG@ $tag] {
	variable settings
	set settings {
	    superClass string
	    publicMethods {}
	    isContainer no
	    tag @TAG@
	}
    }]

    return $full_path_to_type
}

huddle addType ::yaml::types::mapping
huddle addType ::yaml::types::sequence

huddle addType [::yaml::_makeChildType str !!str]
huddle addType [::yaml::_makeChildType timestamp !!timestamp]
huddle addType [::yaml::_makeChildType float !!float]
huddle addType [::yaml::_makeChildType int !!int]
huddle addType [::yaml::_makeChildType null !!null]
huddle addType [::yaml::_makeChildType true !!true]
huddle addType [::yaml::_makeChildType false !!false]
huddle addType [::yaml::_makeChildType binary !!binary]
huddle addType [::yaml::_makeChildType plain !!plain]


