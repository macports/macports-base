# mutl.tcl - messaging utilities
#
# (c) 1999 Marshall T. Rose
# Hold harmless the author, and any lawful use is allowed.
#


package provide mutl 1.0


namespace eval mutl {
    namespace export exclfile tmpfile \
                     firstaddress gathertext getheader
}


proc mutl::exclfile {fileN {stayP 0}} {
    global errorCode errorInfo

    for {set i 0} {$i < 10} {incr i} {
        if {![catch { set xd [open $fileN { RDWR CREAT EXCL }] } result]} {
            if {(![set code [catch { puts $xd [expr {[pid]%65535}]
                                     flush $xd } result]]) \
                    && (!$stayP)} {
                if {![set code [catch { close $xd } result]]} {
                    set xd ""
                }
            }

            if {$code} {
                set ecode $errorCode
                set einfo $errorInfo

                catch { close $xd }

                file delete -- $fileN

                return -code $code -errorinfo $einfo -errorcode $ecode $result
            }

            return $xd
        }
        set ecode $errorCode
        set einfo $errorInfo

        if {(([llength $ecode] != 3) \
                || ([string compare [lindex $ecode 0] POSIX]) \
                || ([string compare [lindex $ecode 1] EEXIST]))} {
            return -code 1 -errorinfo $einfo -errorcode $ecode $result
        }

        after 1000
    }

    error "unable to exclusively open $fileN"
}

proc mutl::tmpfile {prefix {tmpD ""}} {
    global env
    global errorCode errorInfo

    if {(![string compare $tmpD ""]) && ([catch { set tmpD $env(TMP) }])} {
        set tmpD /tmp
    }
    set file [file join $tmpD $prefix]

    append file [expr {[pid]%65535}]

    for {set i 0} {$i < 10} {incr i} {
        if {![set code [catch { set fd [open $file$i \
                                             { WRONLY CREAT EXCL }] } \
                              result]]} {
            return [list file $file$i fd $fd]
        }
        set ecode $errorCode
        set einfo $errorInfo

        if {(([llength $ecode] != 3) \
                || ([string compare [lindex $ecode 0] POSIX]) \
                || ([string compare [lindex $ecode 1] EEXIST]))} {
            return -code $code -errorinfo $einfo -errorcode $ecode $result
        }
    }

    error "unable to create temporary file"
}

proc mutl::firstaddress {values} {
    foreach value $values {
        foreach addr [mime::parseaddress $value] {
            catch { unset aprops }
            array set aprops $addr

            if {[string compare $aprops(proper) ""]} {
                return $aprops(proper)
            }
        }
    }
}

proc mutl::gathertext {token} {
    array set props [mime::getproperty $token]

    set text ""

    if {[info exists props(parts)]} {
        foreach part $props(parts) {
            append text [mutl::gathertext $part]
        }
    } elseif {![string compare $props(content) text/plain]} {
        set text [mime::getbody $token]
    }

    return $text
}

proc mutl::getheader {token key} {
    if {[catch { mime::getheader $token $key } result]} {
        set result ""
    }

    return $result    
}
