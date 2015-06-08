# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# $Id$

# Create Portfile
#
# Workflow:
# 1. Gather metadata
# 2. Feed template
# 3. Print result

# Get tarball filename from tarball URL
proc get_tarball_filename {url} {
    set length [string length $url]
    set last [string last "/" $url]
    incr last;                  # Discard prefix "/"
    return [string range $url $last $length]
}

# Get name from tarball filename
proc get_name {tarball} {
    set last_dash [string last "-" $tarball]
    incr last_dash -1;          # Discard suffix "-"
    return [string range $tarball 0 $last_dash]
}

# Get version from tarball filename
proc get_version {tarball} {
    set rtv [regexp {(\d+\.)?(\d+\.)?(\*|\d+)} $tarball match]
    if {$rtv == 1} {
        return $match
    } else {
        return 0
    }
}

proc read_template {file} {
    set fp [open $file r]
    set template [read $fp]
    close $fp
    return $template
}

proc feed_template {template metadata} {
    return $template
}

if {[string equal $argv0 port-create.tcl]} {
    set name ""
    set version ""

    package require cmdline
    set options {
        {url.arg      ""  "set the tarball URL of port"}
        {name.arg     ""  "set the name of port"}
        {version.arg  ""  "set the version of port"}
    }
    set usage ": $argv0 \[-url <url>] \[-name <name>] \[-version <version>]\noptions:"
    if {[catch {array set params [cmdline::getoptions ::argv $options $usage]}]} {
        puts [cmdline::usage $options $usage]
        exit 2
    }

    if {[expr {[string length $params(url)] > 0}]} {
        set tarball [get_tarball_filename $params(url)]
        set name [get_name $tarball]
        set version [get_version $tarball]
    }

    if {[expr {[string length $params(name)] > 0}]} {
        set name $params(name)
    }

    if {[expr {[string length $params(version)] > 0}]} {
        set version $params(version)
    }

    set template [read_template "./Portfile.template"]

    if {$name ne""} {
        set template [string map "__PortName__ $name" $template]
    }
    if {$version ne ""} {
        set template [string map "__PortVersion__ $version" $template]
    }

    puts $template
}
