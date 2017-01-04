#-----------------------------------------------------------------------
# TITLE:
#    validate.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Snit validation types.
#
#-----------------------------------------------------------------------

namespace eval ::snit:: { 
    namespace export \
        boolean \
        double \
        enum \
        fpixels \
        integer \
        listtype \
        pixels \
        stringtype \
        window
}

#-----------------------------------------------------------------------
# snit::boolean

snit::type ::snit::boolean {
    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
        if {![string is boolean -strict $value]} {
            return -code error -errorcode INVALID \
   "invalid boolean \"$value\", should be one of: 1, 0, true, false, yes, no, on, off"

        }

        return $value
    }

    #-------------------------------------------------------------------
    # Constructor

    # None needed; no options

    #-------------------------------------------------------------------
    # Public Methods

    method validate {value} {
        $type validate $value
    }
}

#-----------------------------------------------------------------------
# snit::double

snit::type ::snit::double {
    #-------------------------------------------------------------------
    # Options

    # -min value
    #
    # Minimum value

    option -min -default "" -readonly 1

    # -max value
    #
    # Maximum value

    option -max -default "" -readonly 1

    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
        if {![string is double -strict $value]} {
            return -code error -errorcode INVALID \
                "invalid value \"$value\", expected double"
        }

        return $value
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, get the options
        $self configurelist $args

        if {"" != $options(-min) && 
            ![string is double -strict $options(-min)]} {
            return -code error \
                "invalid -min: \"$options(-min)\""
        }

        if {"" != $options(-max) && 
            ![string is double -strict $options(-max)]} {
            return -code error \
                "invalid -max: \"$options(-max)\""
        }

        if {"" != $options(-min) &&
            "" != $options(-max) && 
            $options(-max) < $options(-min)} {
            return -code error "-max < -min"
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    # Fixed method for the snit::double type.
    # WHD, 6/7/2010.
    method validate {value} {
        $type validate $value

        if {("" != $options(-min) && $value < $options(-min))       ||
            ("" != $options(-max) && $value > $options(-max))} {

            set msg "invalid value \"$value\", expected double"

            if {"" != $options(-min) && "" != $options(-max)} {
                append msg " in range $options(-min), $options(-max)"
            } elseif {"" != $options(-min)} {
                append msg " no less than $options(-min)"
            } elseif {"" != $options(-max)} {
                append msg " no greater than $options(-max)"
            }
        
            return -code error -errorcode INVALID $msg
        }

        return $value
    }
}

#-----------------------------------------------------------------------
# snit::enum

snit::type ::snit::enum {
    #-------------------------------------------------------------------
    # Options

    # -values list
    #
    # Valid values for this type

    option -values -default {} -readonly 1

    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
        # No -values specified; it's always valid
        return $value
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        $self configurelist $args

        if {[llength $options(-values)] == 0} {
            return -code error \
                "invalid -values: \"\""
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    method validate {value} {
        if {[lsearch -exact $options(-values) $value] == -1} {
            return -code error -errorcode INVALID \
    "invalid value \"$value\", should be one of: [join $options(-values) {, }]"
        }
        
        return $value
    }
}

#-----------------------------------------------------------------------
# snit::fpixels

snit::type ::snit::fpixels {
    #-------------------------------------------------------------------
    # Options

    # -min value
    #
    # Minimum value

    option -min -default "" -readonly 1

    # -max value
    #
    # Maximum value

    option -max -default "" -readonly 1

    #-------------------------------------------------------------------
    # Instance variables

    variable min ""  ;# -min, no suffix
    variable max ""  ;# -max, no suffix

    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
        if {[catch {winfo fpixels . $value} dummy]} {
            return -code error -errorcode INVALID \
                "invalid value \"$value\", expected fpixels"
        }

        return $value
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, get the options
        $self configurelist $args

        if {"" != $options(-min) && 
            [catch {winfo fpixels . $options(-min)} min]} {
            return -code error \
                "invalid -min: \"$options(-min)\""
        }

        if {"" != $options(-max) && 
            [catch {winfo fpixels . $options(-max)} max]} {
            return -code error \
                "invalid -max: \"$options(-max)\""
        }

        if {"" != $min &&
            "" != $max && 
            $max < $min} {
            return -code error "-max < -min"
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    method validate {value} {
        $type validate $value
        
        set val [winfo fpixels . $value]

        if {("" != $min && $val < $min) ||
            ("" != $max && $val > $max)} {

            set msg "invalid value \"$value\", expected fpixels"

            if {"" != $min && "" != $max} {
                append msg " in range $options(-min), $options(-max)"
            } elseif {"" != $min} {
                append msg " no less than $options(-min)"
            }
        
            return -code error -errorcode INVALID $msg
        }

        return $value
    }
}

#-----------------------------------------------------------------------
# snit::integer

snit::type ::snit::integer {
    #-------------------------------------------------------------------
    # Options

    # -min value
    #
    # Minimum value

    option -min -default "" -readonly 1

    # -max value
    #
    # Maximum value

    option -max -default "" -readonly 1

    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
        if {![string is integer -strict $value]} {
            return -code error -errorcode INVALID \
                "invalid value \"$value\", expected integer"
        }

        return $value
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, get the options
        $self configurelist $args

        if {"" != $options(-min) && 
            ![string is integer -strict $options(-min)]} {
            return -code error \
                "invalid -min: \"$options(-min)\""
        }

        if {"" != $options(-max) && 
            ![string is integer -strict $options(-max)]} {
            return -code error \
                "invalid -max: \"$options(-max)\""
        }

        if {"" != $options(-min) &&
            "" != $options(-max) && 
            $options(-max) < $options(-min)} {
            return -code error "-max < -min"
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    method validate {value} {
        $type validate $value

        if {("" != $options(-min) && $value < $options(-min))       ||
            ("" != $options(-max) && $value > $options(-max))} {

            set msg "invalid value \"$value\", expected integer"

            if {"" != $options(-min) && "" != $options(-max)} {
                append msg " in range $options(-min), $options(-max)"
            } elseif {"" != $options(-min)} {
                append msg " no less than $options(-min)"
            }
        
            return -code error -errorcode INVALID $msg
        }

        return $value
    }
}

#-----------------------------------------------------------------------
# snit::list

snit::type ::snit::listtype {
    #-------------------------------------------------------------------
    # Options

    # -type type
    #
    # Specifies a value type

    option -type -readonly 1

    # -minlen len
    #
    # Minimum list length

    option -minlen -readonly 1 -default 0

    # -maxlen len
    #
    # Maximum list length

    option -maxlen -readonly 1

    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
        if {[catch {llength $value} result]} {
            return -code error -errorcode INVALID \
                "invalid value \"$value\", expected list"
        }

        return $value
    }

    #-------------------------------------------------------------------
    # Constructor
    
    constructor {args} {
        # FIRST, get the options
        $self configurelist $args

        if {"" != $options(-minlen) && 
            (![string is integer -strict $options(-minlen)] ||
             $options(-minlen) < 0)} {
            return -code error \
                "invalid -minlen: \"$options(-minlen)\""
        }

        if {"" == $options(-minlen)} {
            set options(-minlen) 0
        }

        if {"" != $options(-maxlen) && 
            ![string is integer -strict $options(-maxlen)]} {
            return -code error \
                "invalid -maxlen: \"$options(-maxlen)\""
        }

        if {"" != $options(-maxlen) && 
            $options(-maxlen) < $options(-minlen)} {
            return -code error "-maxlen < -minlen"
        }
    }


    #-------------------------------------------------------------------
    # Methods

    method validate {value} {
        $type validate $value

        set len [llength $value]

        if {$len < $options(-minlen)} {
            return -code error -errorcode INVALID \
              "value has too few elements; at least $options(-minlen) expected"
        } elseif {"" != $options(-maxlen)} {
            if {$len > $options(-maxlen)} {
                return -code error -errorcode INVALID \
         "value has too many elements; no more than $options(-maxlen) expected"
            }
        }

        # NEXT, check each value
        if {"" != $options(-type)} {
            foreach item $value {
                set cmd $options(-type)
                lappend cmd validate $item
                uplevel \#0 $cmd
            }
        }
        
        return $value
    }
}

#-----------------------------------------------------------------------
# snit::pixels

snit::type ::snit::pixels {
    #-------------------------------------------------------------------
    # Options

    # -min value
    #
    # Minimum value

    option -min -default "" -readonly 1

    # -max value
    #
    # Maximum value

    option -max -default "" -readonly 1

    #-------------------------------------------------------------------
    # Instance variables

    variable min ""  ;# -min, no suffix
    variable max ""  ;# -max, no suffix

    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
        if {[catch {winfo pixels . $value} dummy]} {
            return -code error -errorcode INVALID \
                "invalid value \"$value\", expected pixels"
        }

        return $value
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, get the options
        $self configurelist $args

        if {"" != $options(-min) && 
            [catch {winfo pixels . $options(-min)} min]} {
            return -code error \
                "invalid -min: \"$options(-min)\""
        }

        if {"" != $options(-max) && 
            [catch {winfo pixels . $options(-max)} max]} {
            return -code error \
                "invalid -max: \"$options(-max)\""
        }

        if {"" != $min &&
            "" != $max && 
            $max < $min} {
            return -code error "-max < -min"
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    method validate {value} {
        $type validate $value
        
        set val [winfo pixels . $value]

        if {("" != $min && $val < $min) ||
            ("" != $max && $val > $max)} {

            set msg "invalid value \"$value\", expected pixels"

            if {"" != $min && "" != $max} {
                append msg " in range $options(-min), $options(-max)"
            } elseif {"" != $min} {
                append msg " no less than $options(-min)"
            }
        
            return -code error -errorcode INVALID $msg
        }

        return $value
    }
}

#-----------------------------------------------------------------------
# snit::stringtype

snit::type ::snit::stringtype {
    #-------------------------------------------------------------------
    # Options

    # -minlen len
    #
    # Minimum list length

    option -minlen -readonly 1 -default 0

    # -maxlen len
    #
    # Maximum list length

    option -maxlen -readonly 1

    # -nocase 0|1
    #
    # globs and regexps are case-insensitive if -nocase 1.

    option -nocase -readonly 1 -default 0

    # -glob pattern
    #
    # Glob-match pattern, or ""

    option -glob -readonly 1

    # -regexp regexp
    #
    # Regular expression to match
    
    option -regexp -readonly 1
    
    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
        # By default, any string (hence, any Tcl value) is valid.
        return $value
    }

    #-------------------------------------------------------------------
    # Constructor
    
    constructor {args} {
        # FIRST, get the options
        $self configurelist $args

        # NEXT, validate -minlen and -maxlen
        if {"" != $options(-minlen) && 
            (![string is integer -strict $options(-minlen)] ||
             $options(-minlen) < 0)} {
            return -code error \
                "invalid -minlen: \"$options(-minlen)\""
        }

        if {"" == $options(-minlen)} {
            set options(-minlen) 0
        }

        if {"" != $options(-maxlen) && 
            ![string is integer -strict $options(-maxlen)]} {
            return -code error \
                "invalid -maxlen: \"$options(-maxlen)\""
        }

        if {"" != $options(-maxlen) && 
            $options(-maxlen) < $options(-minlen)} {
            return -code error "-maxlen < -minlen"
        }

        # NEXT, validate -nocase
        if {[catch {snit::boolean validate $options(-nocase)} result]} {
            return -code error "invalid -nocase: $result"
        }

        # Validate the glob
        if {"" != $options(-glob) && 
            [catch {string match $options(-glob) ""} dummy]} {
            return -code error \
                "invalid -glob: \"$options(-glob)\""
        }

        # Validate the regexp
        if {"" != $options(-regexp) && 
            [catch {regexp $options(-regexp) ""} dummy]} {
            return -code error \
                "invalid -regexp: \"$options(-regexp)\""
        }
    }


    #-------------------------------------------------------------------
    # Methods

    method validate {value} {
        # Usually we'd call [$type validate $value] here, but
        # as it's a no-op, don't bother.

        # FIRST, validate the length.
        set len [string length $value]

        if {$len < $options(-minlen)} {
            return -code error -errorcode INVALID \
              "too short: at least $options(-minlen) characters expected"
        } elseif {"" != $options(-maxlen)} {
            if {$len > $options(-maxlen)} {
                return -code error -errorcode INVALID \
         "too long: no more than $options(-maxlen) characters expected"
            }
        }

        # NEXT, check the glob match, with or without case.
        if {"" != $options(-glob)} {
            if {$options(-nocase)} {
                set result [string match -nocase $options(-glob) $value]
            } else {
                set result [string match $options(-glob) $value]
            }
            
            if {!$result} {
                return -code error -errorcode INVALID \
                    "invalid value \"$value\""
            }
        }
        
        # NEXT, check regexp match with or without case
        if {"" != $options(-regexp)} {
            if {$options(-nocase)} {
                set result [regexp -nocase -- $options(-regexp) $value]
            } else {
                set result [regexp -- $options(-regexp) $value]
            }
            
            if {!$result} {
                return -code error -errorcode INVALID \
                    "invalid value \"$value\""
            }
        }
        
        return $value
    }
}

#-----------------------------------------------------------------------
# snit::window

snit::type ::snit::window {
    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
        if {![winfo exists $value]} {
            return -code error -errorcode INVALID \
                "invalid value \"$value\", value is not a window"
        }

        return $value
    }

    #-------------------------------------------------------------------
    # Constructor

    # None needed; no options

    #-------------------------------------------------------------------
    # Public Methods

    method validate {value} {
        $type validate $value
    }
}
