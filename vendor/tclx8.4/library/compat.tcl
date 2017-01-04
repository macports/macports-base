#
# compat --
#
# This file provides commands compatible with older versions of Extended Tcl.
# 
#------------------------------------------------------------------------------
# Copyright 1992-1999 Karl Lehenbauer and Mark Diekhans.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted, provided
# that the above copyright notice appear in all copies.  Karl Lehenbauer and
# Mark Diekhans make no representations about the suitability of this
# software for any purpose.  It is provided "as is" without express or
# implied warranty.
#------------------------------------------------------------------------------
# $Id: compat.tcl,v 1.1 2001/10/24 23:31:48 hobbs Exp $
#------------------------------------------------------------------------------
#

#@package: TclX-GenCompat assign_fields cexpand

proc assign_fields {list args} {
    puts stderr {**** Your program is using an obsolete TclX proc, "assign_fields".}
    puts stderr {**** Please use the command "lassign". Compatibility support will}
    puts stderr {**** be removed in the next release.}

    proc assign_fields {list args} {
        if [lempty $args] {
            return
        }
        return [uplevel lassign [list $list] $args]
    }
    return [uplevel assign_fields [list $list] $args]
}

# Added TclX 7.4a
proc cexpand str {subst -nocommands -novariables $str}

#@package: TclX-ServerCompat server_open server_connect server_send \
                             server_info server_cntl

# Added TclX 7.4a

proc server_open args {
    set cmd server_connect

    set buffered 1
    while {[string match -* [lindex $args 0]]} {
        set opt [lvarpop args]
        if [cequal $opt -buf] {
            set buffered 1
        } elseif  [cequal $opt -nobuf] {
            set buffered 0
        }
        lappend cmd $opt
    }
    set handle [uplevel [concat $cmd $args]]
    if $buffered {
        lappend handle [dup $handle]
    }
    return $handle
}

# Added TclX 7.5a

proc server_connect args {
    set cmd socket

    set buffered 1
    set twoids 0
    while {[string match -* [lindex $args 0]]} {
        switch -- [set opt [lvarpop args]] {
            -buf {
                set buffered 1
            }
            -nobuf {
                set buffered 0
            }
            -myip {
                lappend cmd -myaddr [lvarpop args]
            }
            -myport {
                lappend cmd -myport [lvarpop args]
            }
            -twoids {
                set twoids 1
            }
            default {
                error "unknown option \"$opt\""
            }
        }
    }
    set handle [uplevel [concat $cmd $args]]
    if !$buffered {
        fconfigure $handle -buffering none 
    }
    if $twoids {
        lappend handle [dup $handle]
    }
    return $handle
}

proc server_send args {
    set cmd puts

    while {[string match -* [lindex $args 0]]} {
        switch -- [set opt [lvarpop args]] {
            {-dontroute} {
                error "server_send if obsolete, -dontroute is not supported by the compatibility proc"
            }
            {-outofband} {
                error "server_send if obsolete, -outofband is not supported by the compatibility proc"
            }
        }
        lappend cmd $opt
    }
    uplevel [concat $cmd $args]
    flush [lindex $args 0]
}

proc server_info args {
    eval [concat host_info $args]
}

proc server_cntl args {
    eval [concat fcntl $args]
}

#@package: TclX-ClockCompat fmtclock convertclock getclock

# Added TclX 7.5a

proc fmtclock {clockval {format {}} {zone {}}} {
    lappend cmd clock format $clockval
    if ![lempty $format] {
        lappend cmd -format $format
    }
    if ![lempty $zone] {
        lappend cmd -gmt 1
    }
    return [eval $cmd]
}

# Added TclX 7.5a

proc convertclock {dateString {zone {}} {baseClock {}}} {
    lappend cmd clock scan $dateString
    if ![lempty $zone] {
        lappend cmd -gmt 1
    }
    if ![lempty $baseClock] {
        lappend cmd -base $baseClock
    }
    return [eval $cmd]
}

# Added TclX 7.5a

proc getclock {} {
    return [clock seconds]
}

#@package: TclX-FileCompat mkdir rmdir unlink frename

# Added TclX 7.6.0

proc mkdir args {
    set path 0
    if {[llength $args] > 1} {
        lvarpop args
        set path 1
    }
    foreach dir [lindex $args 0] {
        if {((!$path) && [file isdirectory $dir]) || \
                ([file exists $dir] && ![file isdirectory $dir])} {
            error "creating directory \"$dir\" failed: file already exists" \
                    {} {POSIX EEXIST {file already exists}}
        }
        file mkdir $dir
    }
    return
}

# Added TclX 7.6.0

proc rmdir args {
    set nocomplain 0
    if {[llength $args] > 1} {
        lvarpop args
        set nocomplain 1
        global errorInfo errorCode
        set saveErrorInfo $errorInfo
        set saveErrorCode $errorCode
    }
    foreach dir [lindex $args 0] {
        if $nocomplain {
            catch {file delete $dir}
        } else {
            if ![file exists $dir] {
                error "can't remove \"$dir\": no such file or directory" {} \
                        {POSIX ENOENT {no such file or directory}}
            }
            if ![cequal [file type $dir] directory] {
                error "$dir: not a directory" {} \
                        {POSIX ENOTDIR {not a directory}}
            }
            file delete $dir
        }
    }
    if $nocomplain {
        set errorInfo $saveErrorInfo 
        set errorCode $saveErrorCode
    }
    return
}

# Added TclX 7.6.0

proc unlink args {
    set nocomplain 0
    if {[llength $args] > 1} {
        lvarpop args
        set nocomplain 1
        global errorInfo errorCode
        set saveErrorInfo $errorInfo
        set saveErrorCode $errorCode
    }
    foreach file [lindex $args 0] {
        if {[file exists $file] && [cequal [file type $file] directory]} {
            if !$nocomplain {
                error "$file: not owner" {} {POSIX EPERM {not owner}}
            }
        } elseif $nocomplain {
            catch {file delete $file}
        } else {
            if {!([file exists $file] || \
                    ([catch {file readlink $file}] == 0))} {
                error "can't remove \"$file\": no such file or directory" {} \
                        {POSIX ENOENT {no such file or directory}}
            }
            file delete $file
        }
    }
    if $nocomplain {
        set errorInfo $saveErrorInfo 
        set errorCode $saveErrorCode
    }
    return
}

# Added TclX 7.6.0

proc frename {old new} {
    if {[file isdirectory $new] && ![lempty [readdir $new]]} {
        error "rename \"foo\" to \"baz\" failed: directory not empty" {} \
                POSIX ENOTEMPTY {directory not empty}
    }
    file rename -force $old $new
}


#@package: TclX-CopyFileCompat copyfile

# Added TclX 8.0.0

# copyfile ?-bytes num | \-maxbytes num? ?\-translate? fromFileId toFileId

proc copyfile args {
    global errorInfo errorCode

    set copyMode NORMAL
    set translate 0
    while {[string match -* [lindex $args 0]]} {
        set opt [lvarpop args]
        switch -exact -- $opt {
            -bytes {
                set copyMode BYTES
                if {[llength $args] == 0} {
                    error "argument required for -bytes option"
                }
                set totalBytesToRead [lvarpop args]
            }
            -maxbytes {
                set copyMode MAX_BYTES
                if {[llength $args] == 0} {
                    error "argument required for -maxbytes option"
                }
                set totalBytesToRead [lvarpop args]
            }
            -translate {
                set translate 1
            }
            default {
                error "invalid argument \"$opt\", expected \"-bytes\",\
                        \"-maxbytes\", or \"-translate\""
            }
        }
    }
    if {[llength $args] != 2} {
        error "wrong # args: copyfile ?-bytes num|-maxbytes num? ?-translate?\
                fromFileId toFileId"
    }
    lassign $args fromFileId toFileId

    if !$translate {
        set fromOptions [list \
                [fconfigure $fromFileId -translation] \
                [fconfigure $fromFileId -eofchar]]
        set toOptions [list \
                [fconfigure $toFileId -translation] \
                [fconfigure $toFileId -eofchar]]

        fconfigure $fromFileId -translation binary
        fconfigure $fromFileId -eofchar {}
        fconfigure $toFileId -translation binary
        fconfigure $toFileId -eofchar {}
    }

    set cmd [list fcopy $fromFileId $toFileId]
    if ![cequal $copyMode NORMAL] {
        lappend cmd -size $totalBytesToRead
    }
    
    set stat [catch {eval $cmd} totalBytesRead]
    if $stat {
        set saveErrorResult $totalBytesRead
        set saveErrorInfo $errorInfo
        set saveErrorCode $errorCode
    }

    if !$translate {
        # Try to restore state, even if we have an error.
        if [catch {
            fconfigure $fromFileId -translation [lindex $fromOptions 0]
            fconfigure $fromFileId -eofchar [lindex $fromOptions 1]
            fconfigure $toFileId -translation [lindex $toOptions 0]
            fconfigure $toFileId -eofchar [lindex $toOptions 1]
        } errorResult] {
            # If fcopy did not get an error, we process this one
            if !$stat {
                set stat 1
                set saveErrorResult $errorResult
                set saveErrorInfo $errorInfo
                set saveErrorCode $errorCode
            }
        }
    }

    if $stat {
        error $saveErrorResult $saveErrorInfo $saveErrorCode
    }

    if {[cequal $copyMode BYTES] && ($totalBytesToRead > 0) && \
            ($totalBytesRead != $totalBytesToRead)} {
        error "premature EOF, $totalBytesToRead bytes expected,\
                $totalBytesRead bytes actually read"
    }
    return $totalBytesRead
}
