# -*- tcl -*-
# (c) 2015 Miguel Martínez López

package require Tcl 8.5
package require TclOO       ; # For 8.5. Integrated with 8.6
package require try         ; # For 8.5. Integrated with 8.6. Tcllib.
package require huddle 0.1.7

package provide huddle::json 0.1


namespace eval ::huddle {
    namespace export json2huddle

    proc json2huddle {jsonText} {
        set huddle_object [::huddle::json::json2huddle parse $jsonText]
        return $huddle_object
    }
}

    
namespace eval ::huddle::json {
    
    oo::class create Json2huddle {
        
        variable cursor jsonText EndOfTextException numberRE
        
        constructor {} {

            if {[package vcompare [package present Tcl] 8.6] == 0} {
                proc throw {code msg} {
                    return -code error -errorcode $code $msg
                }
            }
            
            set positiveRE {[1-9][[:digit:]]*}
            set cardinalRE "-?(?:$positiveRE|0)"
            set fractionRE {[.][[:digit:]]+}
            set exponentialRE {[eE][+-]?[[:digit:]]+}
            set numberRE "${cardinalRE}(?:$fractionRE)?(?:$exponentialRE)?"
        
            # Exception code for "End of Text" signal
            set EndOfTextException 5
        }        
            
        method parse {json_to_parse} {
            set cursor -1
            set jsonText $json_to_parse
            
            my parse_next_json_data
        }
            
        method peekChar { {increment 1} } {
            return [string index $jsonText [expr {$cursor+$increment}]]
        }

        method advanceCursor { {increment 1} } {
            incr cursor $increment
        }
        
        method nextChar {} {
            if {$cursor + 1 < [string length $jsonText] } {
                incr cursor
                return [string index $jsonText $cursor]    
            } else {
                return -code $EndOfTextException
            }
        }
    
        method assertNext {ch {target ""}} {
            incr cursor
            
            if {[string index $jsonText $cursor] != $ch} {
                if {$target == ""} {
                    set target $ch
                }
                throw {HUDDLE JSONparser} "Trying to read the string $target at index $cursor."
            }
        }
    
    
        method parse_next_json_data {} {
            
            my eatWhitespace
            
            set ch [my peekChar]
            
            if {$ch eq ""} {
                throw {HUDDLE JSONparser} {Nothing to read}
            }
            
                        
            switch -exact -- $ch {
                "\{" {
                    return [my readObject]
                } 
                "\[" {
                    return [my readArray]
                } 
                "\"" {
                    return [my readString]
                } 

                "t" {
                    return [my readTrue]
                }
                "f" {
                    return [my readFalse]
                }
                "n" {
                    return [my readNull]
                } 
                "/" {
                    my readComment
                    return [my parse_next_json_data]
                }
                "-" -
                "0" -
                "1" -
                "2" -
                "3" -
                "4" -
                "5" -
                "6" -
                "7" -
                "8" -
                "9" {
                    return [my readNumber]
                } 
                default {
                    throw {HUDDLE JSONparser} "Input is not valid JSON: '$jsonText'" 
                }
            }
        }
        
        method eatWhitespace {} {

            while {true} {
                set ch [my peekChar]
                
                if {[string is space -strict $ch]} {
                    my advanceCursor
                } elseif {$ch eq "/"} {
                    my readComment
                } else {
                    break
                }
            }
        }

        
        method readTrue {} {
            my assertNext t true
            my assertNext r true
            my assertNext u true
            my assertNext e true
            return [::huddle true]
        }
    
        
        method readFalse {} {
            my assertNext f false
            my assertNext a false
            my assertNext l false
            my assertNext s false
            my assertNext e false
            return [::huddle false]
        }
    
        
        method readNull {} {
            my assertNext n null
            my assertNext u null
            my assertNext l null
            my assertNext l null
            return [::huddle null]
        }
        
        method readComment {} {

            switch -exact -- [my peekChar 1][my peekChar 2] {
                "//" {
                    my readDoubleSolidusComment
                }
                "/*" {
                    my readCStyleComment
                }
                default {
                    throw {HUDDLE JSONparser} "Not a valid JSON comment: $jsonText"
                }
            }
        }
        
        method readCStyleComment {} {
            my assertNext "/" "/*"
            my assertNext "*" "/*"
            
            try {
                
                while {true} {
                    set ch [my nextChar]
                    
                    switch -exact -- $ch {
                        "*" {
                            if { [my peekChar] eq "/"} {
                                my advanceCursor
                                break
                            }
                        }
                        "/" {
                            if { [my peekChar] eq "*"} {
                                throw {HUDDLE JSONparser} "Not a valid JSON comment: $jsonText, '/*' cannot be embedded in the comment at index $cursor." 
                            }
                        }

                    } 
                }
                
            } on $EndOfTextException {} {
                throw {HUDDLE JSONparser} "not a valid JSON comment: $jsonText, expected */"
            }
        }

        
        method readDoubleSolidusComment {} {
            my assertNext "/" "//"
            my assertNext "/" "//"
            
            try {
                set ch [my nextChar]
                while { $ch ne "\r" && $ch ne "\n"} {
                    set ch [my nextChar]
                }
            } on $EndOfTextException {} {}
        }
                
        method readArray {} {
            my assertNext "\["
            my eatWhitespace

            if { [my peekChar] eq "\]"} {
                my advanceCursor
                return [huddle list]
            }
                
            try {        
                while {true} {
                    
                    lappend result [my parse_next_json_data]
                
                    my eatWhitespace
                        
                    set ch [my nextChar]
            
                    if {$ch eq "\]"} {
                        break
                    } else {
                        if {$ch ne ","} {
                            throw {HUDDLE JSONparser} "Not a valid JSON array: '$jsonText' due to: '$ch' at index $cursor."
                        }
                        
                        my eatWhitespace
                    }
                }
            } on $EndOfTextException {} {
                throw {HUDDLE JSONparser} "Not a valid JSON string: '$jsonText'"
            }
                
            return [huddle list {*}$result]
        }
            
        
        
        method readObject {} {

            my assertNext "\{"
            my eatWhitespace

            if { [my peekChar] eq "\}"} {
                my advanceCursor
                return [huddle create]
            }
            
            try {        
                while {true} {
                    set key [my readStringLiteral]
                
                    my eatWhitespace
                    
                    set ch [my nextChar]
            
                    if { $ch ne ":"} {
                        throw {HUDDLE JSONparser} "Not a valid JSON object: '$jsonText' due to: '$ch' at index $cursor."
                    }
            
                    my eatWhitespace
            
                    lappend result $key [my parse_next_json_data]
            
                    my eatWhitespace
            
                    set ch [my nextChar]
            
                    if {$ch eq "\}"} {
                        break
                    } else {
                        if {$ch ne ","} {
                            throw {HUDDLE JSONparser} "Not a valid JSON array: '$jsonText' due to: '$ch' at index $cursor."
                        }
                        
                        my eatWhitespace
                    }
                }
            } on $EndOfTextException {} {
                throw {HUDDLE JSONparser} "Not a valid JSON string: '$jsonText'"
            }
                    
            return [huddle create {*}$result]
        }
        
        
        method readNumber {} {
            regexp -start $cursor -- $numberRE $jsonText number
            my advanceCursor [string length $number]
            
            return [huddle number $number]
        }    
        
        method readString {} {
            set string [my readStringLiteral]
            return [huddle string $string]
        }
                

        method readStringLiteral {} {
            
            my assertNext "\""
            
            set result ""
            try {
                while {true} {
                    set ch [my nextChar]
                    
                    if {$ch eq "\""} break
                    
                    if {$ch eq "\\"} {
                        set ch [my nextChar]
                        switch -exact -- $ch {
                            "b" {
                                set ch "\b"
                            }
                            "r" {
                                set ch "\r"
                            }
                            "n" {
                                set ch "\n"
                            }
                            "f" {
                                set ch "\f"
                            }
                            "t" {
                                set ch "\t"
                            }
                            "u" {
                                set ch [format "%c" 0x[my nextChar][my nextChar][my nextChar][my nextChar]]
                            }
                            "\"" {}
                            "/"  {}
                            "\\" {}
                            default {
                                throw {HUDDLE JSONparser} "Not a valid escaped JSON character: '$ch' in $jsonText"
                            }
                        }
                    }
                    append result $ch
                }
            } on $EndOfTextException {} {
                throw {HUDDLE JSONparser} "Not a valid JSON string: '$jsonText'"
            }

            return $result
        }
    
    }    
    
    Json2huddle create json2huddle
}
    

