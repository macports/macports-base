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
    # preceeds the GitHub username of the maintainer and 'keyword', which
    # contains a special maintainer keyword such as 'openmaintainer' or
    # 'nomaintainer'.
    #
    # @param list A list of obscured maintainers
    # @return A list of associative arrays in serialized list format
    proc unobscure_maintainers {list} {
        set result {}
        foreach sublist $list {
            array set maintainer {}
            foreach token $sublist {
                if {[string index $token 0] eq "@"} {
                    # Strings starting with @ are GitHub usernames
                    set maintainer(github) [string range $token 1 end]
                } elseif {[string first "@" $token] >= 0} {
                    # Other strings that contain @ are plain email addresses
                    set maintainer(email) $token
                    continue
                } elseif {[string first ":" $token] >= 0} {
                    # Strings that contain a colon are obfuscated email
                    # addresses

                    # Split at :, assign the first part to $domain, re-assemble
                    # the rest and assign it to $localpart
                    set localpart [join [lassign [split $token ":"] domain] ":"]
                    set maintainer(email) "${localpart}@${domain}"
                } elseif {$token in {"openmaintainer" "nomaintainer"}} {
                    # Filter openmaintainer and nomaintainer
                    set maintainer(keyword) $token
                } else {
                    # All other entries must be MacPorts handles
                    set maintainer(email) "${token}@macports.org"
                }
            }
            set serialized [array get maintainer]
            array unset maintainer
            if {[llength $serialized]} {
                # Filter empty maintainers
                lappend result $serialized
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
            set var [lreplace $var $idx $idx]
        }
    } else {
        set item $var
        set var {}
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
    set var [lreplace $var [set var 0] 0]
    return $element
}

# lunshift varName ?value ...?
# Prepends list elements onto a variable
# If varName does not exist then it is created
proc lunshift {varName args} {
    upvar 1 $varName var
    if {![info exists var]} {
        set var {}
    }
    # the [set] in the index argument ensures the list is not shared
    set var [lreplace $var [set var -1] -1 {*}$args]
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


################################
# try/catch exception handling #
################################
# modelled after TIP #89 <http://www.tcl.tk/cgi-bin/tct/tip/89>

if {![namespace exists ::_trycatch]} {
    namespace eval ::_trycatch {
        variable catchStack {}
    }
}

# throw ?type? ?message? ?info?
# Works like error, but arguments are reordered to encourage use of types
# If called with no arguments in a catch block, re-throws the caught exception
proc throw {args} {
    if {[llength $args] == 0} {
        # re-throw
        if {[llength $::_trycatch::catchStack] == 0} {
            return -code error "error: throw with no parameters outside of a catch"
        } else {
            set errorNode [lpop ::_trycatch::catchStack]
            set errCode [lindex $errorNode 0]
            set errMsg  [lindex $errorNode 1]
            set errInfo [lindex $errorNode 2]
            return -code error -errorinfo $errInfo -errorcode $errCode $errMsg
        }
    } elseif {[llength $args] > 3} {
        return -code error "wrong # args: should be \"throw ?type? ?message? ?info?\""
    } else {
        set errCode [lindex $args 0]
        if {[llength $args] > 1} {
            set errMsg  [lindex $args 1]
        } else {
            set errMsg "error: $errCode"
        }
        if {[llength $args] > 2} {
            set errInfo [lindex $args 2]
        } else {
            set errInfo $errMsg
        }
        return -code error -errorinfo $errInfo -errorcode $errCode $errMsg
    }
}

# try ?-pass_signal? body ?catch {type_list ?ecvar? ?msgvar? ?infovar?} body ...? ?finally body?
# implementation of try as specified in TIP #89
# option -pass_signal passes SIGINT and SIGTERM signals up the stack
proc try {args} {
    # validate and interpret the arguments
    set catchList {}
    if {[llength $args] == 0} {
        return -code error "wrong # args: \
            should be \"try ?-pass_signal? body ?catch {type-list ?ecvar? ?msgvar? ?infovar?} body ...? ?finally body?\""
    }
    if {[lindex $args 0] eq "-pass_signal"} {
        lpush catchList {{POSIX SIG SIGINT} eCode eMessage} {
            ui_debug [msgcat::mc "Aborted: SIGINT signal received"]
            throw
        }
        lpush catchList {{POSIX SIG SIGTERM} eCode eMessage} {
            ui_debug [msgcat::mc "Aborted: SIGTERM signal received"]
            throw
        }
        lshift args
    }
    set body [lshift args]
    while {[llength $args] > 0} {
        set arg [lshift args]
        switch $arg {
            catch {
                set elem [lshift args]
                if {[llength $args] == 0 || [llength $elem] > 4} {
                    return -code error "invalid syntax in catch clause: \
                        should be \"catch {type-list ?ecvar? ?msgvar? ?infovar?} body\""
                } elseif {[llength [lindex $elem 0 0]] == 0} {
                    return -code error "invalid syntax in catch clause: type-list must contain at least one type"
                }
                lpush catchList $elem [lshift args]
            }
            finally {
                if {[llength $args] == 0} {
                    return -code error "invalid syntax in finally clause: should be \"finally body\""
                } elseif {[llength $args] > 1} {
                    return -code error "trailing args after finally clause"
                }
                set finallyBody [lshift args]
            }
            default {
                return -code error "invalid syntax: \
                    should be \"try body ?catch {type-list ?ecvar? ?msgvar? ?infovar?} body ...? ?finally body?\""
            }
        }
    }

    # at this point, we've processed all args'
    # builtin_catch is the normal Tcl catch command, rather than the wrapper
    # defined in common/catch.tcl and sourced by macports.tcl
    if {[set err [builtin_catch {uplevel 1 $body} result]] == 1} {
        set savedErrorCode $::errorCode
        set savedErrorInfo $::errorInfo
        # rip out the last "invoked from within" - we want to hide our internals
        set savedErrorInfo [regsub -linestop {(\n    \(.*\))?\n    invoked from within\n"uplevel 1 \$body"\Z} \
                            $savedErrorInfo ""]
        # add to the throw stack
        lpush ::_trycatch::catchStack [list $savedErrorCode $result $savedErrorInfo]
        # call the first matching catch block
        foreach {elem catchBody} $catchList {
            set typeList [lshift elem]
            set match? 1
            set typeList [lrange $typeList 0 [expr {[llength $savedErrorCode] - 1}]]
            set codeList [lrange $savedErrorCode 0 [expr {[llength $typeList] - 1}]]
            foreach type $typeList code $codeList {
                if {![string match $type $code]} {
                    set match? 0
                    break
                }
            }
            if {${match?}} {
                # found a block
                if {[set ecvar [lshift elem]] ne ""} {
                    uplevel 1 set [list $ecvar] [list $savedErrorCode]
                }
                if {[set msgvar [lshift elem]] ne ""} {
                    uplevel 1 set [list $msgvar] [list $result]
                }
                if {[set infovar [lshift elem]] ne ""} {
                    uplevel 1 set [list $infovar] [list $savedErrorInfo]
                }
                if {[set err [builtin_catch {uplevel 1 $catchBody} result]] == 1} {
                    # error in the catch block, save it
                    set savedErrorCode $::errorCode
                    set savedErrorInfo $::errorInfo
                    # rip out the last "invoked from within" - we want to hide our internals
                    set savedErrorInfo [regsub -linestop \
                                        {(\n    \(.*\))?\n    invoked from within\n"uplevel 1 \$catchBody"\Z} \
                                        $savedErrorInfo ""]
                    # also rip out an "invoked from within" for throw
                    set savedErrorInfo [regsub -linestop \
                                        {\n    invoked from within\n"throw"\Z} $savedErrorInfo ""]
                }
                break
            }
        }
        # remove from the throw stack
        lpop ::_trycatch::catchStack
    }
    # execute finally block
    if {[info exists finallyBody]} {
        # catch errors here so we can strip our uplevel
        set savedErr $err
        set savedResult $result
        if {[set err [builtin_catch {uplevel 1 $finallyBody} result]] == 1} {
            set savedErrorCode $::errorCode
            set savedErrorInfo $::errorInfo
            # rip out the last "invoked from within" - we want to hide our internals
            set savedErrorInfo [regsub -linestop \
                                {(\n    \(.*\))?\n    invoked from within\n"uplevel 1 \$finallyBody"\Z} \
                                $savedErrorInfo ""]
        } elseif {$err == 0} {
            set err $savedErr
            set result $savedResult
        }
    }
    # aaaand return
    if {$err == 1} {
        return -code $err -errorinfo $savedErrorInfo -errorcode $savedErrorCode $result
    } else {
        return -code $err $result
    }
}
