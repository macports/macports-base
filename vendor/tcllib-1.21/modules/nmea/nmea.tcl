# nmea.tcl --
#
# NMEA protocol implementation
#
# Copyright (c) 2006-2009 Aaron Faupell
#
# RCS: @(#) $Id: nmea.tcl,v 1.5 2009/01/09 06:49:25 afaupell Exp $

package require Tcl 8.4
package provide nmea 1.0.0

namespace eval ::nmea {
    array set ::nmea::nmea [list checksum 1 log {} rate 0]
    array set ::nmea::dispatch ""
}

proc ::nmea::open_port {port {speed 4800}} {
    variable nmea
    if {[info exists nmea(fh)]} { ::nmea::close }
    set nmea(fh) [open $port]
    fconfigure $nmea(fh) -mode $speed,n,8,1 -handshake xonxoff -buffering line -translation crlf
    fileevent $nmea(fh) readable [list ::nmea::read_port $nmea(fh)]
    return $port
}

proc ::nmea::open_file {file {rate {}}} {
    variable nmea
    if {[info exists nmea(fh)]} { ::nmea::close }
    set nmea(fh) [open $file]
    if {[string is integer -strict $rate]} {
        if {$rate < 0} { set rate 0 }
        set nmea(rate) $rate
    }
    fconfigure $nmea(fh) -buffering line -blocking 0 -translation auto
    if {$nmea(rate) > 0} {
        after $nmea(rate) [list ::nmea::read_file $nmea(fh)]
    }
    return $file
}

proc ::nmea::configure_port {settings} {
    variable nmea
    fconfigure $nmea(fh) -mode $settings
}

proc ::nmea::close {} {
    variable nmea
    catch {::close $nmea(fh)}
    unset -nocomplain nmea(fh)
    foreach x [after info] {
        if {[lindex [after info $x] 0 0] == "::nmea::read_file"} {
            after cancel $x
        }
    }
}

proc ::nmea::read_port {f} {
    if {[catch {gets $f} line] || [eof $f]} {
        if {[info exists ::nmea::dispatch(EOF)]} {
            $::nmea::dispatch(EOF)
        }
        nmea::close
    }
    if {$::nmea::nmea(log) != ""} {
        puts $::nmea::nmea(log) $line
    }
    ::nmea::parse_nmea $line
}

proc ::nmea::read_file {f {auto 1}} {
    variable nmea
    set line [gets $f]
    if {[eof $f]} {
        if {[info exists ::nmea::dispatch(EOF)]} {
            $::nmea::dispatch(EOF)
        }
        nmea::close
        return 0
    }
    if {[string match {$*} $line]} {
        ::nmea::parse_nmea $line
    } else {
        ::nmea::parse_nmea \$$line
    }
    if {$auto} {
        after $nmea(rate) [list ::nmea::read_file $f]
    }
    return 1
}

proc ::nmea::do_line {} {
    variable nmea
    if {![info exists nmea(fh)]} { return -code error "there is no currently open file" }
    return [::nmea::read_file $nmea(fh) 0]
}

proc ::nmea::configure {opt {val {}}} {
    variable nmea
    switch -exact -- $opt {
        rate {
            if {$val == ""} { return $nmea(rate) }
            if {![string is integer $val]} { return -code error "rate must be an integer value" }
            if {$val <= 0} {
                foreach x [after info] {
                    if {[lindex [after info $x] 0 0] == "::nmea::read_file"} {
                        after cancel $x
                    }
                }
                set val 0
            }
            if {$nmea(rate) == 0 && $val > 0} {
                after $val [list ::nmea::read_file $nmea(fh)]
            }
            set nmea(rate) $val
            return $val
        }
        checksum {
            if {$val == ""} { return $nmea(checksum) }
            if {![string is bool $val]} { return -code error "checksum must be a boolean value" }
            set nmea(checksum) $val
            return $val
        }
        default {
            return -code error "unknown option $opt"
        }
    }
}

proc ::nmea::input {sentence} {
    if {![string match "*,*" $sentence]} { set sentence [join $sentence ,] }
    if {[string match {$*} $sentence]} {
        ::nmea::parse_nmea $sentence
    } else {
        ::nmea::parse_nmea \$$sentence
    }
}

proc ::nmea::log {{file _X}} {
    variable nmea
    if {$file == "_X"} { return [expr {$nmea(log) != ""}] }
    if {$file != ""} {
        if {$nmea(log) != ""} { ::nmea::log {} }
        set nmea(log) [open $file a]
    } else {
        catch {::close $nmea(log)}
        set nmea(log) ""
    }
    return $file
}

proc ::nmea::parse_nmea {line} {
    set line [split $line \$*]
    set cksum [lindex $line 2]
    set line [lindex $line 1]
    if {$cksum == "" || !$::nmea::nmea(checksum) || [checksum $line] == $cksum} {
        set line [split $line ,]
        set sentence [lindex $line 0]
        set line [lrange $line 1 end]
        if {[info exists ::nmea::dispatch($sentence)]} {
            $::nmea::dispatch($sentence) $line
        } elseif {[info exists ::nmea::dispatch(DEFAULT)]} {
            $::nmea::dispatch(DEFAULT) $sentence $line
        }
    }
}

proc ::nmea::checksum {line} {
    set sum 0
    binary scan $line c* line
    foreach char $line {
        set sum [expr {$sum ^ ($char % 128)}]
    }
    return [format %02X [expr {$sum % 256}]]
}

proc ::nmea::write {type args} {
    variable nmea
    set data $type,[join $args ,]
    puts $nmea(fh) \$$data*[checksum $data]
}

proc ::nmea::event {sentence {command _X}} {
    variable dispatch
    set sentence [string toupper $sentence]
    if {$command == "_X"} {
        if {[info exists dispatch($sentence)]} {
            return $dispatch($sentence)
        }
        return {}
    }
    if {$command == ""} {
        unset -nocomplain dispatch($sentence)
        return {}
    }
    set dispatch($sentence) $command
    return $command
}
