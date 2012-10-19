# macports.tcl
# $Id$
#
# Copyright (c) 2007 Kevin Ballard <eridius@macports.org>
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
    proc method_wrap {name} {
        variable argdefault
    
        set name [list $name]
        # reconstruct the args list
        set args [uplevel 1 [subst -nocommands {info args $name}]]
        set arglist {}
        foreach arg $args {
            set argname [list $arg]
            if {[uplevel 1 [subst -nocommands {info default $name $argname argdefault}]]} {
                lappend arglist [list $arg $argdefault]
            } else {
                lappend arglist $arg
            }
        }
        # modify the proc
        set arglist [list $arglist]
        set body [uplevel 1 [subst -nocommands {info body $name}]]
        uplevel 1 [subst -nocommands {
            proc $name $arglist {
                if {[set err [catch {$body} result]] && [set err] != 2} {
                    if {[set err] == 1} {
                        return -code [set err] -errorcode [set ::errorCode] [set result]
                    } else {
                        return -code [set err] [set result]
                    }
                } else {
                    return [set result]
                }
            }
        }]
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
    set varName [list $varName]
    if {[llength $args] > 0} {
        set idx [lindex $args 0]
        set size [uplevel 1 [subst -nocommands {llength [set $varName]}]]
        set badrange? 0
        if {[string is integer -strict $idx]} {
            if {$idx < 0 || $idx >= $size} {
                set badrange? 1
            }
        } elseif {$idx eq "end"} {
            if {$size == 0} {
                set badrange? 1
            }
        } elseif {[string match end-* $idx] && [string is integer -strict [string range $idx 4 end]]} {
            set i [expr $size - 1 - [string range $idx 4 end]]
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
            set list [uplevel 1 [subst -nocommands {lindex [set $varName] $idx}]]
            set item [eval ldindex list [lrange $args 1 end]]
            uplevel 1 [subst {lset $varName $idx [list $list]}]
        } else {
            set item [uplevel 1 [subst -nocommands {lindex [set $varName] $idx}]]
            uplevel 1 [subst -nocommands {set $varName [lreplace [set $varName] $idx $idx]}]
        }
    } else {
        set item [uplevel 1 [subst {set $varName}]]
        uplevel 1 [subst {set $varName {}}]
    }
    return $item
}
macports_util::method_wrap ldindex

# lpop varName
# Removes the last list element from a variable
# If varName is an empty list an empty string is returned
proc lpop {varName} {
    set varName [list $varName]
    set size [uplevel 1 [subst -nocommands {llength [set $varName]}]]
    if {$size != 0} {
        uplevel 1 [subst -nocommands {ldindex $varName end}]
    }
}
macports_util::method_wrap lpop

# lpush varName ?value ...?
# Appends list elements onto a variable
# If varName does not exist then it is created
# really just an alias for lappend
proc lpush {varName args} {
    set varName [list $varName]
    uplevel 1 [subst -nocommands {lappend $varName $args}]
}
macports_util::method_wrap lpush

# lshift varName
# Removes the first list element from a variable
# If varName is an empty list an empty string is returned
proc lshift {varName} {
    set varName [list $varName]
    set size [uplevel 1 [subst -nocommands {llength [set $varName]}]]
    if {$size != 0} {
        uplevel 1 [subst -nocommands {ldindex $varName 0}]
    }
}
macports_util::method_wrap lshift

# lunshift varName ?value ...?
# Prepends list elements onto a variable
# If varName does not exist then it is created
proc lunshift {varName args} {
    set varName [list $varName]
    uplevel 1 [subst -nocommands {
        if {![info exists $varName]} {
            set $varName {}
        }
    }]
    set value [concat $args [uplevel 1 set $varName]]
    uplevel 1 set $varName [list $value]
}
macports_util::method_wrap lunshift

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

# try body ?catch {type_list ?ecvar? ?msgvar? ?infovar?} body ...? ?finally body?
# implementation of try as specified in TIP #89
proc try {args} {
    # validate and interpret the arguments
    set catchList {}
    if {[llength $args] == 0} {
        return -code error "wrong # args: \
            should be \"try body ?catch {type-list ?ecvar? ?msgvar? ?infovar?} body ...? ?finally body?\""
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

    # at this point, we've processed all args
    if {[set err [catch {uplevel 1 $body} result]] == 1} {
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
            set typeList [lrange $typeList 0 [expr [llength $savedErrorCode] - 1]]
            set codeList [lrange $savedErrorCode 0 [expr [llength $typeList] - 1]]
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
                if {[set err [catch {uplevel 1 $catchBody} result]] == 1} {
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
        if {[set err [catch {uplevel 1 $finallyBody} result]] == 1} {
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
