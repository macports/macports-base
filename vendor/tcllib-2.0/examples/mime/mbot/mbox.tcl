# mbox.tcl - mailbox package
#
# (c) 1999 Marshall T. Rose
# Hold harmless the author, and any lawful use is allowed.
#

#
# TODO:
#
#     mbox::initialize
#         add -pop server option
#         add -imap server option
#         along with -username, -password, and -passback
#
#     mbox::getmsgproperty
#         add support for deleted messages
#
#     mbox::deletemsg token msgNo
#         marks a message for deletion
#
#     mbox::synchronize token ?-commit boolean?
#         commits or rollllbacks changes


package provide mbox 1.0

package require mime 1.1


#
# state variables:
#
#     msgs: serialized array of messages, containing array of:
#           msgNo, mime
#     count: number of messages
#     first: number of initial message
#     last: number of final message
#     value: either "file", or "directory"
#
#     file: file containing mailbox
#     fd: corresponding file descriptor
#     fileA: serialized array of messages, containing array of:
#            msgNo, offset, size
#
#     directory: directory containing mailbox
#     dirA: serialized array of messages, containing array of:
#           msgNo, size
#     

namespace eval mbox {
    variable mbox
    array set mbox { uid 0 }

    namespace export initialize finalize getproperty \
                     getmsgtoken getmsgproperty
}


proc mbox::initialize {args} {
    global errorCode errorInfo

    variable mbox

    set token [namespace current]::[incr mbox(uid)]

    variable $token
    upvar 0 $token state

    if {[set code [catch { eval [list mbox::initializeaux $token] $args } \
                         result]]} {
        set ecode $errorCode
        set einfo $errorInfo

        catch { mbox::finalize $token -subordinates dynamic }

        return -code $code -errorinfo $einfo -errorcode $ecode $result
    }

    return $token
}


proc mbox::initializeaux {token args} {
    variable $token
    upvar 0 $token state

    set state(msgs) ""
    set state(count) 0
    set state(first) 0
    set state(last) 0

    set argc [llength $args]
    for {set argx 0} {$argx < $argc} {incr argx} {
        set option [lindex $args $argx]
        if {[incr argx] >= $argc} {
            error "missing argument to $option"
        }
        set value [lindex $args $argx]

        switch -- $option {
            -directory {
                set state(directory) $value
            }

            -file {
                set state(file) $value
            }

            default {
                error "unknown option $option"
            }
        }
    }

    set valueN 0
    foreach value [list directory file] {
        if {[info exists state($value)]} {
            set state(value) $value
            incr valueN
        }
    }
    if {$valueN != 1} {
        error "specify exactly one of -directory, or -file"
    }

    return [mbox::initialize_$state(value) $token]
}


proc mbox::initialize_file {token} {
    variable $token
    upvar 0 $token state

    fconfigure [set state(fd) [open $state(file) { RDONLY }]] \
               -translation binary
    
    array set fileA ""
    set msgNo 0

    if {[gets $state(fd) line] < 0} {
        return $token
    }
    switch -regexp -- $line {
        "^From " {
            set format Mailx
            set preB "From "

            set phase ""
        }

        "\01\01\01\01" {
            set format MMDF
            set preB "\01\01\01\01"
            set postB "\01\01\01\01"

            if {([gets $state(fd) line] >= 0) \
                    && ([string first "From MAILER-DAEMON " $line] == 0)} {
                set phase skip
            } else {
                set phase pre
            }
        }

        default {
            error "unrecognized mailbox format"
        }
    }
    seek $state(fd) 0 start

    while {[gets $state(fd) line] >= 0} {
        switch -- $format/$phase {
            Mailx/ {
                if {[string first $preB $line] == 0} {
                    if {$msgNo > 0} {
                        set fileA($msgNo) [list msgNo $msgNo offset $offset \
                                                size $size]
                    }

                    incr msgNo
                    set offset [tell $state(fd)]
                    set size 0
                } else {
                    incr size [expr {[string length $line]+1}]
                }
            }

            MMDF/pre {
                if {![string compare $preB $line]} {
                    incr msgNo
                    set offset [tell $state(fd)]
                    set size 0

                    set phase post
                } else {
                    error "invalid mailbox"
                }
            }

            MMDF/post {
                if {![string compare $postB $line]} {
                    set fileA($msgNo) [list msgNo $msgNo offset $offset \
                                            size $size]

                    set phase pre
                } else {
                    incr size [expr {[string length $line]+1}]
                }
            }

            MMDF/skip {
                if {![string compare $preB $line]} {
                    set phase skip2
                }
            }

            MMDF/skip2 {
                if {![string compare $postB $line]} {
                    set phase pre
                }
            }
        }
    }

    switch -- $format/$phase {
        Mailx/ {
            if {$msgNo > 0} {
                set fileA($msgNo) [list msgNo $msgNo offset $offset \
                                        size $size]
            }
        }

        MMDF/post
            -
        MMDF/skip2 {
            error "incomplete mailbox"
        }
    }

    set state(fileA) [array get fileA]
    if {[set state(last) [set state(count) $msgNo]] > 0} {
        set state(first) 1
    }

    return $token
}


proc mbox::initialize_directory {token} {
    variable $token
    upvar 0 $token state

    array set dirA ""

    set first 0
    set last 0
    foreach file [glob -nocomplain [file join $state(directory) *]] {
        if {(![regexp {^[1-9][0-9]*$} [set msgNo [file tail $file]]]) \
                || ([catch { file size $file } size])} {
            continue
        }

        if {($first == 0) || ($msgNo < $first)} {
            set first $msgNo
        }
        if {$last < $msgNo} {
            set last $msgNo
        }

        set dirA($msgNo) [list msgNo $msgNo size $size]
        incr state(count)
    }

    set state(dirA) [array get dirA]
    if {[set state(last) $last] > 0} {
        set state(first) $first
    }

    return $token
}

proc mbox::finalize {token args} {
    variable $token
    upvar 0 $token state

    array set options [list -subordinates dynamic]
    array set options $args

    switch -- $options(-subordinates) {
        all
            -
        dynamic {
            array set msgs $state(msgs)

            for {set msgNo $state(first)} \
                    {$msgNo <= $state(last)} \
                    {incr msgNo} {
                if {![catch { array set msg $msgs($msgNo) }]} {
                    eval [list mime::finalize $msg(mime)] $args
                }
            }
        }

        none {
        }

        default {
            error "unknown value for -subordinates $options(-subordinates)"
        }
    }

    if {[info exists state(fd)]} {
        catch { close $state(fd) }
    }

    foreach name [array names state] {
        unset state($name)
    }
    unset $token
}


proc mbox::getproperty {token {property ""}} {
    variable $token
    upvar 0 $token state

    switch -- $property {
        "" {
            return [list count    $state(count) \
                         first    $state(first) \
                         last     $state(last)  \
                         messages [mbox::getmessages $token]]
        }

        -names {
            return [list count first last messages]
        }

        count
            -
        first
            -
        last  {
            return $state($property)
        }

        messages {
            return [mbox::getmessages $token]
        }

        default {
            error "unknown property $property"
        }
    }
}


proc mbox::getmessages {token} {
    variable $token
    upvar 0 $token state

    switch -- $state(value) {
        directory {
            array set msgs $state(dirA)
        }

        file {
            array set msgs $state(fileA)
        }
    }

    return [lsort -integer [array names msgs]]
}


proc mbox::getmsgtoken {token msgNo} {
    variable $token
    upvar 0 $token state

    if {($msgNo < $state(first)) || ($msgNo > $state(last))} {
        error "message number out of range: $state(first)..$state(last)"
    }

    array set msgs $state(msgs)
    if {![catch { array set msg $msgs($msgNo) }]} {
        return $msg(mime)
    }

    switch -- $state(value) {
        directory {
            set mime [mime::initialize \
                          -file [file join $state(directory) $msgNo]]
        }

        file {
            array set fileA $state(fileA)
            array set msg $fileA($msgNo)
            set mime [mime::initialize -file $state(file) -root $token \
                          -offset $msg(offset) -count $msg(size)]
        }
    }

    set msgs($msgNo) [list msgNo $msgNo mime $mime]
    set state(msgs) [array get msgs]

    return $mime
}


proc mbox::getmsgproperty {token msgNo {property ""}} {
    variable $token
    upvar 0 $token state

    if {($msgNo < $state(first)) || ($msgNo > $state(last))} {
        error "message number out of range: $state(first)..$state(last)"
    }

    switch -- $state(value) {
        directory {
            array set dirA $state(dirA)
            if {[catch { array set msg $dirA($msgNo) }]} {
                error "message $msgNo doesn't exist"
            }
        }

        file {
            array set fileA $state(fileA)
            array set msg $fileA($msgNo)
        }
    }

    set props [list flags size uidl]

    switch -- $property {
        "" {
            array set properties ""

            foreach prop $props {
                if {[info exists msg($prop)]} {
                    set properties($prop) $msg($prop)
                }
            }

            return [array get properties]
        }

        -names  {
            set names ""
            foreach prop $props {
                if {[info exists msg($prop)]} {
                    lappend names $prop
                }
            }

            return $names
        }

        default {
            if {[lsearch -exact $props $property] < 0} {
                error "unknown property $property"
            }

            return $msg($property)
        }
    }
}
