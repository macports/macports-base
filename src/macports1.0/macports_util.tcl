# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# macports_util.tcl
#
# Copyright (c) 2007 Kevin Ballard <eridius@macports.org>
# Copyright (c) 2016 The MacPorts Project
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of The MacPorts Project nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

package provide macports_util 1.0

# Provide some global utilities

namespace eval macports_util {
    ###################
    # Private methods #
    ###################

    ##
    # Given a list of maintainers as recorded in a Portfile, return a list of
    # lists in [key value ...] format describing all maintainers. Valid keys
    # are 'email' which denotes a maintainer's email address, 'github', which
    # precedes the GitHub username of the maintainer and 'keyword', which
    # contains a special maintainer keyword such as 'openmaintainer' or
    # 'nomaintainer'.
    #
    # @param list A list of obscured maintainers
    # @return A list of associative arrays in serialized list format
    proc unobscure_maintainers {list} {
        set result [list]
        foreach sublist $list {
            set maintainer [dict create]
            foreach token $sublist {
                if {[string index $token 0] eq "@"} {
                    # Strings starting with @ are GitHub usernames
                    dict set maintainer github [string range $token 1 end]
                } elseif {[string first "@" $token] >= 0} {
                    # Other strings that contain @ are plain email addresses
                    dict set maintainer email $token
                    continue
                } elseif {[string first ":" $token] >= 0} {
                    # Strings that contain a colon are obfuscated email
                    # addresses

                    # Split at :, assign the first part to $domain, re-assemble
                    # the rest and assign it to $localpart
                    set localpart [join [lassign [split $token ":"] domain] ":"]
                    dict set maintainer email "${localpart}@${domain}"
                } elseif {$token in {"openmaintainer" "nomaintainer"}} {
                    # Filter openmaintainer and nomaintainer
                    dict set maintainer keyword $token
                } else {
                    # All other entries must be MacPorts handles
                    dict set maintainer email "${token}@macports.org"
                }
            }
            if {[dict size $maintainer] > 0} {
                # Filter empty maintainers
                lappend result $maintainer
            }
        }

        return $result
    }
}

###################
# List management #
###################
# It would be nice to have these written in C
# That way we could avoid duplicating lists if they're not shared
# but oh well

# ldindex varName ?index...?
# Removes the index'th list element from varName and returns it
# If multiple indexes are provided, each one is a subindex into the
# list element specified by the previous index
# If no indexes are provided, deletes the entire list and returns it
# If varName does not exists an exception is raised
proc ldindex {varName args} {
    upvar 1 $varName var
    if {[llength $args] > 0} {
        set idx [lindex $args 0]
        set size [llength $var]
        set badrange? 0
        if {[string is wideinteger -strict $idx]} {
            if {$idx < 0 || $idx >= $size} {
                set badrange? 1
            }
        } elseif {$idx eq "end"} {
            if {$size == 0} {
                set badrange? 1
            }
        } elseif {[string match "end-*" $idx] && [string is wideinteger -strict [string range $idx 4 end]]} {
            set i [expr {$size - 1 - [string range $idx 4 end]}]
            if {$i < 0 || $i >= $size} {
                set badrange? 1
            }
        } else {
            error "bad index \"$idx\": must be integer or end?-integer?"
        }
        if {${badrange?}} {
            error "list index out of range"
        }
    
        if {[llength $args] > 1} {
            set list [lindex $var $idx]
            set item [ldindex list {*}[lrange $args 1 end]]
            lset var $idx $list
        } else {
            set item [lindex $var $idx]
            set var [lreplace ${var}[set var {}] $idx $idx]
        }
    } else {
        set item $var
        set var [list]
    }
    return $item
}

# lpop varName
# Removes the last list element from a variable
# If varName is an empty list an empty string is returned
proc lpop {varName} {
    upvar 1 $varName var
    set element [lindex $var end]
    set var [lrange $var 0 end-1]
    return $element
}

# lpush varName ?value ...?
# Appends list elements onto a variable
# If varName does not exist then it is created
# really just an alias for lappend
proc lpush {varName args} {
    upvar 1 $varName var
    lappend var {*}$args
}

# lshift varName
# Removes the first list element from a variable
# If varName is an empty list an empty string is returned
proc lshift {varName} {
    upvar 1 $varName var
    set element [lindex $var 0]
    # the [set] in the index argument ensures the list is not shared
    set var [lreplace ${var}[set var {}] 0 0]
    return $element
}

# lunshift varName ?value ...?
# Prepends list elements onto a variable
# If varName does not exist then it is created
proc lunshift {varName args} {
    upvar 1 $varName var
    if {![info exists var]} {
        set var [list]
    }
    # the [set] in the index argument ensures the list is not shared
    set var [lreplace ${var}[set var {}] -1 -1 {*}$args]
}


# dictequal dictA dictB
# Returns 0 if the two given dicts have exactly the same keys and map
# them to exactly the same values. Returns 1 otherwise.
proc dictequal {a b} {
    if {[dict size $a] != [dict size $b]} {
        return 1
    }
    dict for {key val} $a {
        if {![dict exists $b $key] || $val ne [dict get $b $key]} {
            return 1
        }
    }
    return 0
}

# bytesize filesize ?unit? ?format?
# Format an integer representing bytes using given units
proc bytesize {siz {unit {}} {format {%.2f}}} {
    if {$unit eq {}} {
        if {$siz > 0x40000000} {
            set unit "GiB"
        } elseif {$siz > 0x100000} {
            set unit "MiB"
        } elseif {$siz > 0x400} {
            set unit "KiB"
        } else {
            set unit "B"
        }
    }
    switch -- $unit {
        KiB {
            set siz [expr {$siz / 1024.0}]
        }
        kB {
            set siz [expr {$siz / 1000.0}]
        }
        MiB {
            set siz [expr {$siz / 1048576.0}]
        }
        MB {
            set siz [expr {$siz / 1000000.0}]
        }
        GiB {
            set siz [expr {$siz / 1073741824.0}]
        }
        GB {
            set siz [expr {$siz / 1000000000.0}]
        }
        B { }
        default {
            ui_warn "Unknown file size unit '$unit' specified"
            set unit "B"
        }
    }
    if {[expr {round($siz)}] != $siz} {
        set siz [format $format $siz]
    }
    return "$siz $unit"
}

# filesize file ?unit?
# Return size of file in human-readable format
# In case of any errors, returns -1
proc filesize {fil {unit {}}} {
    set siz -1
    catch {
        set siz [bytesize [file size $fil] $unit]
    }
    return $siz
}


################################################################
# try/on/trap exception handling with signal pass-thru support #
################################################################

##
# macports_try ?-pass_signal? body ?handler...? body ?finally script?
#
# Extension of the tcllib try module (which provides a Tcl 8.6-compatible try
# implementation) with a flag that will in no cases catch signals but rather
# always bubble them up the call stack.
#
# Use this whenever you're not aborting execution anyway if an error occurs
# within a try block, so that the user is quickly able to abort execution of
# macports tasks. Do not use this is you actually need to manually react to
# signals.
#
# You should prefer using the builtin try, since that's implemented in C, and
# this is a Tcl re-implementation.
#
# Note that this re-implementation uses ::builtin_catch, since mpcommon1.0
# replaces the original ::catch with a modified version, but we really need the
# original behavior.
#
# This code is originally:
# (C) 2008-2011 Donal K. Fellows, Andreas Kupries, BSD licensed.
namespace eval macports_util::tcl::control {
    # These are not local, since this allows us to [uplevel] a [catch] rather
    # than [catch] the [uplevel]ing of something, resulting in a cleaner
    # -errorinfo:
    variable em {}
    variable opts {}

    variable magicCodes { ok 0 error 1 return 2 break 3 continue 4 }

    namespace export macports_try

    # macports_util::tcl::control::macports_try --
    #
    #   Advanced error handling construct.
    #
    # Arguments:
    #   See try(n) for details
    proc macports_try {args} {
        variable magicCodes

        # ----- Parse arguments -----

        set pass_signal no
        if {[lindex $args 0] eq "-pass_signal"} {
            set pass_signal yes
            set args [lreplace ${args}[set args {}] 0 0]
        }
        set trybody [lindex $args 0]
        set finallybody {}
        set handlers [list]
        set i 1

        while {$i < [llength $args]} {
            switch -- [lindex $args $i] {
                "on" {
                    incr i
                    set code [lindex $args $i]
                    if {[dict exists $magicCodes $code]} {
                        set code [dict get $magicCodes $code]
                    } elseif {![string is integer -strict $code]} {
                        set msgPart [join [dict keys $magicCodes] {", "}]
                            error "bad code '[lindex $args $i]': must be\
                                integer or \"$msgPart\""
                    }
                    lappend handlers [lrange $args $i $i] \
                        [format %d $code] {} {*}[lrange $args $i+1 $i+2]
                    incr i 3
                }
                "trap" {
                    incr i
                    if {![string is list [lindex $args $i]]} {
                        error "bad prefix '[lindex $args $i]':\
                            must be a list"
                    }
                    lappend handlers [lrange $args $i $i] 1 \
                        {*}[lrange $args $i $i+2]
                    incr i 3
                }
                "finally" {
                    incr i
                    set finallybody [lindex $args $i]
                    incr i
                    break
                }
                default {
                    error "bad handler '[lindex $args $i]': must be\
                        \"on code varlist body\", or\
                        \"trap prefix varlist body\""
                }
            }
        }

        if {($i != [llength $args]) || ([lindex $handlers end] eq "-")} {
            error "wrong # args: should be\
                \"try body ?handler ...? ?finally body?\""
        }

        # ----- Execute 'try' body -----

        variable em
        variable opts
        set EMVAR  [namespace which -variable em]
        set OPTVAR [namespace which -variable opts]
        set code [uplevel 1 [list ::builtin_catch $trybody $EMVAR $OPTVAR]]

        if {$code == 1} {
            set line [dict get $opts -errorline]
            dict append opts -errorinfo \
                "\n    (\"[lindex [info level 0] 0]\" body line $line)"
        }

        # Keep track of the original error message & options
        set _em $em
        set _opts $opts

        # ----- Find and execute handler -----

        set errorcode {}
        if {[dict exists $opts -errorcode]} {
            set errorcode [dict get $opts -errorcode]
        }
        set found false
        foreach {descrip oncode pattern varlist body} $handlers {
            if {$pass_signal && $code == 1 && {POSIX SIG} eq [lrange $errorcode 0 1]} {
                # Treat the signal as if there was no handler for it, i.e. stop
                # searching for handlers.
                break
            }
            if {!$found} {
                if {
                    ($code != $oncode) || ([lrange $pattern 0 end] ne
                    [lrange $errorcode 0 [llength $pattern]-1] )
                } then {
                    continue
                }
            }
            set found true
            if {$body eq "-"} {
                continue
            }

            # Handler found ...

            # Assign trybody results into variables
            lassign $varlist resultsVarName optionsVarName
            if {[llength $varlist] >= 1} {
                upvar 1 $resultsVarName resultsvar
                set resultsvar $em
            }
            if {[llength $varlist] >= 2} {
                upvar 1 $optionsVarName optsvar
                set optsvar $opts
            }

            # Execute the handler
            set code [uplevel 1 [list ::builtin_catch $body $EMVAR $OPTVAR]]

            if {$code == 1} {
                set line [dict get $opts -errorline]
                dict append opts -errorinfo \
                    "\n    (\"[lindex [info level 0] 0] ... $descrip\"\
                    body line $line)"
                # On error chain to original outcome
                dict set opts -during $_opts
            }

            # Handler result replaces the original result (whether success or
            # failure); capture context of original exception for reference.
            set _em $em
            set _opts $opts

            # Handler has been executed - stop looking for more
            break
        }

        # No catch handler found -- error falls through to caller
        # OR catch handler executed -- result falls through to caller

        # ----- If we have a finally block then execute it -----

        if {$finallybody ne {}} {
            set code [uplevel 1 [list ::builtin_catch $finallybody $EMVAR $OPTVAR]]

            # Finally result takes precedence except on success

            if {$code == 1} {
                set line [dict get $opts -errorline]
                dict append opts -errorinfo \
                    "\n    (\"[lindex [info level 0] 0] ... finally\"\
                    body line $line)"
                # On error chain to original outcome
                dict set opts -during $_opts
            }
            if {$code != 0} {
                set _em $em
                set _opts $opts
            }

            # Otherwise our result is not affected
        }

        # Propagate the error or the result of the executed catch body to the
        # caller.
        dict incr _opts -level
        return -options $_opts $_em
    }
}

namespace import macports_util::tcl::control::macports_try
