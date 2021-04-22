#!/usr/bin/env tclsh
## -*- tcl -*-
# webviewer.tcl - Copyright (C) 2004 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# This is a sample application to demonstrate the use of the htmlparse package.
#
# Given the URL of a web page, this application will display just the text of
# the page - that is the contents of header, paragraph and pre tags.
#
# As an aside, this also illustrates the use of the autoproxy package to 
# cope with http proxy servers (if present) and handles HTTP redirections and
# so on.
#
# Usage: webviewer.tcl http://tip.tcl.tk/2
#
# $Id: webviewer.tcl,v 1.2 2009/01/30 04:18:14 andreas_kupries Exp $

package require htmlparse;              # tcllib
package require http;                   # tcl
package require autoproxy;              # tcllib
autoproxy::init

# -------------------------------------------------------------------------
# The driver.
# - Fetch the page
# - parse it to extract the text
# - sort out the html escaped chars
# - eliminate excessive newlines
#
proc webview {url} {
    set html [fetchurl $url]
    if {[string length $html] > 0} {
        variable parsed ""
        htmlparse::parse -cmd [list parser [namespace current]::parsed] $html
        set parsed [htmlparse::mapEscapes $parsed]
        set parsed [regsub -all -line "\n{2,}" $parsed "\n\n"]
        Display $parsed
    } else {
        Error "error: no data available from \"$url\""
    }
}

# -------------------------------------------------------------------------
# This implements our text extracting parser. This will pretty much turn 
# an HTML page into an outline-mode text file.
#
proc parser {outvar tag end attr text} {
    upvar \#0 $outvar out
    set tag [string tolower $tag]
    set end [string length $end]
    if {$end == 0} {
        if {[string equal "hmstart" $tag]} {
            set out ""
        } elseif {[regexp {h(\d+)} $tag -> level]} {
            append out "\n\n" [string repeat * $level] " " $text
        } elseif {[lsearch -exact {p pre td} $tag] != -1} {
            append out "\n" $text
        } elseif {[lsearch -exact {a span i b} $tag] != -1} { 
            append out $text
        }
    }
}

# -------------------------------------------------------------------------
# Fetch the target page and cope with HTTP problems. This
# deals with server errors and proxy authentication failure
# and handles HTTP redirection.
#
proc fetchurl {url} {
    set html ""
    set err ""
    set tok [http::geturl $url -timeout 30000]
    if {[string equal [http::status $tok] "ok"]} {
        if {[http::ncode $tok] >= 500} {
            set err "server error: [http::code $tok]"
        } elseif {[http::ncode $tok] >= 400} {
            set err "authentication error: [http::code $tok]"
        } elseif {[http::ncode $tok] >= 300} {
            upvar \#0 $tok state
            array set meta $state(meta)
            if {[info exists meta(Location)]} {
                return [fetchurl $meta(Location)]
            } else {
                set err [http::code $tok]
            }
        } else {
            set html [http::data $tok]
        }
    } else {
        set err [http::error $tok]
    }
    http::cleanup $tok

    if {[string length $err] > 0} {
        Error $err
    }
    return $html
}

# -------------------------------------------------------------------------
# Abstract out the display functions so we can run this using either wish or
# tclsh. This makes life easier on windows where the default is to use wish
# for tcl files.
#
proc Display {msg} {
    if {[string length [package provide Tk]] > 0} {
        toplevel .dlg -class Dialog
        wm title .dlg "webview output."
        text .dlg.txt -yscrollcommand {.dlg.sb set}
        scrollbar .dlg.sb -command {.dlg.txt yview}
        button .dlg.b -command {destroy .dlg} -text Exit -underline 1
        .dlg.txt insert 0.0 $msg
        bind .dlg <Control-F2> {console show}
        bind .dlg <Escape> {.dlg.b invoke}
        grid .dlg.txt .dlg.sb -sticky news
        grid .dlg.b  - -sticky e -pady {3 0} -ipadx 4
        grid rowconfigure .dlg 0 -weight 1
        grid columnconfigure .dlg 0 -weight 1
        tkwait window .dlg
    } else {
        puts $msg
    }
}

proc Error {msg} {
    if {[string length [package provide Tk]] > 0} {
        tk_messageBox -title "webviewer error" -icon error -message $msg
    } else {
        puts stderr $msg
    }
    exit 1
}

# -------------------------------------------------------------------------

if {!$tcl_interactive} {
    if {[string length [package provide Tk]] > 0} {
        wm withdraw .
        if {$argc < 1} {
            toplevel .dlg -class Dialog
            wm title .dlg "Enter URL"
            label .dlg.l -text "Enter a URL"
            entry .dlg.e -textvariable argv -width 40
            button .dlg.ok -text OK -default active -command {destroy .dlg}
            button .dlg.ca -text Cancel -command {set ::argv ""; destroy .dlg}
            bind .dlg <Return> {.dlg.ok invoke}
            bind .dlg <Escape> {.dlg.ca invoke}
            bind .dlg <Control-F2> {console show}
            grid .dlg.l - -sticky nws
            grid .dlg.e - -sticky news
            grid .dlg.ok .dlg.ca -sticky news
            tkwait window .dlg
            if {[llength $argv] < 1} {
                exit 1
            }
        }
    } else {
    
        if {$argc != 1} {
            Error "usage: webviewer URL"
        }

    }
    eval [linsert $argv 0 webview]
}

