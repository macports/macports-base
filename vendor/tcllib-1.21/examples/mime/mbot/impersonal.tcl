#!/usr/bin/env tclsh
##
# impersonal.tcl - export impersonal mail via the web
#
# (c) 1999 Marshall T. Rose
# Hold harmless the author, and any lawful use is allowed.
#

package require Tcl 8.3
global options


# begin of routines that may be redefined in configFile

proc tclLog {message} {
    global options

    if {([info exists options(debugP)]) && ($options(debugP) > 0)} {
        puts stderr $message
    }

    if {([string first "DEBUG " $message] == 0) \
            || ([catch { set fd [open $options(logFile) \
                                      { WRONLY CREAT APPEND }] }])} {
        return
    }

    regsub -all "\n" $message " " message

    catch { puts -nonewline $fd \
                 [format "%s %-8.8s %06d %s\n" \
                         [clock format [clock seconds] -format "%m/%d %T"] \
                         personal [expr {[pid]%65535}] $message] }

    catch { close $fd }
}

# end of routines that may be redefined in configFile


proc firstext {mime} {
    array set props [mime::getproperty $mime]

    if {[info exists props(parts)]} {
        foreach part $props(parts) {
            if {[string compare [firstext $part] ""]} {
                return $part
            }
        }
    } else {
        switch -- $props(content) {
            text/plain
                -
            text/html {
                return $mime
            }
        }
    }
}

proc sanitize {text} {
    regsub -all "&" $text {\&amp;} text
    regsub -all "<" $text {\&lt;}  text

    return $text
}

proc cleanup {{message ""} {code 500}} {
    global errorCode errorInfo

    set ecode $errorCode
    set einfo $errorInfo

    if {[string compare $message ""]} {
        tclLog $message

        catch {
            puts stdout "HTTP/1.0 $code Server Error
Content-Type: text/html
Status: 500 Server Error

<html><head><title>Service Problem</title></head>
<body><h1>Service Problem</h1>
<b>Reason:</b> [sanitize $message]"

            if {$code == 505} {
                puts stdout "<br>
<b>Stack:</b>
<pre>[sanitize $einfo]</pre>
<hr></hr>"
            }

            puts stdout "</body></html>"
        }
    }

    flush stdout

    exit 0
}



if {[catch {

    set program impersonal

    package require mbox 1.0
    package require mutl 1.0
    package require smtp 1.1
    package require Tclx 8.0


# move stdin, close stdin/stderr

    dup [set null [open /dev/null { RDWR }]] stderr
    set stdin [dup stdin]
    dup $null stdin
    close $null

    fconfigure $stdin -translation crlf
    fconfigure stdout -translation crlf


# parse arguments and initialize environment

    set program [file tail [file rootname $argv0]]

    set configFile .${program}-config.tcl

    set debugP 0

    set userName ""

    for {set argx 0} {$argx < $argc} {incr argx} {
        set option [lindex $argv $argx]
        if {[incr argx] >= $argc} {
            cleanup "missing argument to $option"
        }
        set value [lindex $argv $argx]

        switch -- $option {
            -config {
                set configFile $value
            }

            -debug {
                set options(debugP) [set debugP [smtp::boolean $value]]
            }

            -user {
                set userName $value
            }

            default {
                cleanup "unknown option $option"
            }
        }
    }

    if {[string compare $userName ""]} {
        if {[catch { id convert user $userName }]} {
            cleanup "userName doesn't exist: $userName"
        }
        if {([catch { file isdirectory ~$userName } result]) \
                || (!$result)} {
            cleanup "userName doesn't have a home directory: $userName"
        }

        umask 0077
        cd ~$userName
    }

    if {![file exists $configFile]} {
        cleanup "configFile file doesn't exist: $configFile"
    }
    source $configFile

    set options(debugP) $debugP

    foreach {k v} [array get options] {
        if {![string compare $v ""]} {
            unset options($k)
        }
    }

    foreach k [list dataDirectory foldersFile foldersDirectory] {
        if {![info exists options($k)]} {
            cleanup "configFile didn't define $k: $configFile"
        }
    }

    if {![file isdirectory $options(dataDirectory)]} {
        file mkdir $options(dataDirectory)
    }


# crack the request

    set request ""
    set eol ""
    while {1} {
        if {[catch { gets $stdin line } result]} {
            cleanup "lost connection"
        }
        if {$result < 0} {
            break
        }

        set gotP 0
        foreach c [split $line ""] {
            if {($c == " ") || ($c == "\t") || [ctype print $c]} {
                if {!$gotP} {
                    append request $eol
                    set gotP 1
                }
                append request $c
            }
        }
        if {!$gotP} {
            break
        }

        set eol "\n"
    }
    set request [string tolower $request]

    set getP 0
    foreach param [split $request "\n"] {
        if {[string first "get " $param] == 0} {
            set getP 1
            if {[catch { lindex [split $param " "] 1 } page]} {
                cleanup "server supports only HTTP/1.0" 501
            }
        }
    }
    if {!$getP} {
        cleanup "server supports only GET" 405
    }

    if {[string first /news? $page] != 0} {
        cleanup "page $page unavailable" 504
    }
    foreach param [split [string range $page 6 end] &] {
        if {[set x [string first = $param]] <= 0} {
            cleanup "page $request unavailable" 504
        }
        set key [string range $param 0 [expr {$x-1}]]
        set arg($key) [string range $param [expr {$x+1}] end]
    }

    set expires [mime::parsedatetime -now proper]


# /news?index=newsgroups OR /news?index=recent

    if {![catch { set arg(index) } index]} {
        switch -- $index {
            newsgroups {
                set lastN 0
            }

            recent {
                set lastN -1
            }

            default {
                cleanup "page $request unavailable" 504
            }
        }
        catch { set lastN $arg(lastn) }

        if {[catch { open $options(foldersFile) { RDONLY } } fd]} {
            cleanup $fd 505
        }

        set folders ""
        set suffix [lindex [set prefix [file split \
                                             $options(foldersDirectory)]] \
                           end]
        set prefix [eval [list file join] [lreplace $prefix end end]]

        for {set lineNo 1} {[gets $fd line] >= 0} {incr lineNo} {
            if {[string first $suffix $line] != 0} {
                continue
            }
            set file [file join $prefix $line]

            if {[catch { file stat $file stat } result]} {
                tclLog $result

                continue
            }
            if {![string compare $stat(type) file]} {
                lappend folders [list [eval [list file join] \
                                            [lrange [file split $line] \
                                                    1 end]] \
                                      $stat(mtime)]
            }
        }

        catch {close $fd }

        switch -- $index {
            recent {
                set folders [lsort -integer    -decreasing -index 1 $folders]
            }

            default {
                set folders [lsort -dictionary -increasing -index 0 $folders]
            }
        }

        puts stdout "HTTP/1.0 200
Content-Type: text/html
Pragma: no-cache
Expires: $expires

<html><head><title>newsgroups</title></head><body>
<table cellborder=0 cellpadding=0 cellspacing=0>"

        foreach entry $folders {
            set folder [lindex $entry 0]
            set t [fmtclock [set mtime [lindex $entry 1]] "%m/%d %H:%M"]

            puts stdout "<tr><td><a href=\"news?folder=$folder&lastN=$lastN&mtime=$mtime\">$t</a></td><td width=5></td><td><b>$folder</b></td></tr>"
        }

        puts stdout "</table>
</body></html>"

        cleanup
    }


# /news?folder="whatever"

    if {[catch { set arg(folder) } folder]} {
        cleanup "page $request unavailable" 504
    }

    foreach p [file split $folder] {
        if {(![string compare $p ""]) || ([string first . $p] >= 0)} {
            cleanup "page $request unavailable" 504
        }
    }

    set file [file join $options(foldersDirectory) $folder]
    if {([catch { file type $file } type]) \
            || ([string compare $type file])} {
        cleanup "page $request unavailable" 504
    }
    if {[catch { mbox::initialize -file $file } mbox]} {
        cleanup $mbox 505
    }


# /news?folder="whatever"&lastN="N"

    if {![catch { set arg(lastn) } lastN]} {
        array set props [mbox::getproperty $mbox]

        if {$lastN < 0} {
            set diff [expr {-($lastN*86400)}]

            set last 0
            for {set msgNo $props(last)} {$msgNo > 0} {incr msgNo -1} {
                if {[catch { mbox::getmsgtoken $mbox $msgNo } mime]} {
                    tclLog $mime

                    continue
                }
                
                if {[catch { lindex [mime::getheader $mime Date] 0 } value]} {
                    set value ""
                }
                if {![catch { mime::parsedatetime $value rclock } rclock]} {
                    if {$rclock < $diff} {
                        if {$last == 0} {
                            set last $msgNo
                        }
                        set first $msgNo
                    }
                    if {$last == 0} {
                        break
                    }
                }
            }
            if {$last > 0} {
                set last $props(last)
            }
        } elseif {[set first \
		[expr {[set last $props(last)]-($lastN+1)}]] <= 0} {
            set first 1
        }

        puts stdout "HTTP/1.0 200
Content-Type: text/html
Pragma: no-cache
Expires: $expires

<html><head><title>$folder</title></head><body>"

        if {$last == 0} {
            puts stdout "<b>Empty.</b>
</body></html>"

            cleanup
        }

        puts stdout "<table cellborder=0 cellpadding=0 cellspacing=0>"
        for {set msgNo $last} {$msgNo >= $first} {incr msgNo -1} {
            if {[catch { mbox::getmsgtoken $mbox $msgNo } mime]} {
                tclLog $mime

                continue
            }

            set date ""
            catch {
                set value [lindex [mime::getheader $mime Date] 0]
                append date [format %02d \
                                    [mime::parsedatetime $value mon]]   /  \
                       [format %02d [mime::parsedatetime $value mday]] " " \
                       [format %02d [mime::parsedatetime $value hour]]  :  \
                       [format %02d [mime::parsedatetime $value min]]
            }
            if {![string compare $date ""]} {
                set date "unknown date"
            }

            set from ""
            catch {
                set from [mutl::firstaddress [mime::getheader $mime From]]

                catch { unset aprops }

                array set aprops [lindex [mime::parseaddress $from] 0]
                set from "<a href='mailto:$aprops(local)@$aprops(domain)'>$aprops(friendly)</a>"
            }

            set subject ""
            catch {
                set subject [lindex [mime::getheader $mime Subject] 0]
            }

            puts stdout "<tr><td><a href=\"news?folder=$folder&msgNo=$msgNo\">$date</a></td><td width=5></td><td><b>$from</b></td><td width=5></td><td>$subject</td></tr>"
        }
        puts stdout "</table>
</body></html>"

        cleanup
    }


# /news?folder="whatever"&msgNo="N"

    if {![catch { set arg(msgno) } msgNo]} {
        if {[catch { mbox::getmsgtoken $mbox $msgNo } mime]} {
            cleanup $mime 505
        }

        if {![string compare [set part [firstext $mime]] ""]} {
            set part $mime
        }
        switch -- [set content [mime::getproperty $part content]] {
            text/plain {
                regsub -all "\n\n" [mime::getbody $part] "<p>" body

                set result "<html><head><title>$folder $msgNo</title></head>
<body>$body</body></html>"

            }

            text/html {
                set result [mime::getbody $part]
            }

            default {
                set result "<html><head><title>$folder $msgNo</title></head>
<body>
Message is $content.
</body></html>"
            }
        }

        puts stdout "HTTP/1.0 200
Content-Type: text/html

$result"

        cleanup
    }


    cleanup "page $request unavailable" 504


} result]} {
    global errorCode errorInfo

    set ecode $errorCode
    set einfo $errorInfo

    if {(![catch { info body tclLog } result2]) \
            && ([string compare [string trim $result2] \
                        {catch {puts stderr $string}}])} {
        catch { tclLog $result }
    }

    if {![string first "POSIX EPIPE" $ecode]} {
        exit 0
    }

    catch {
        smtp::sendmessage \
            [mime::initialize \
                 -canonical text/plain \
                 -param  {charset us-ascii} \
                 -string "$result\n\nerrorCode: $ecode\n\n$einfo"] \
            -originator "" \
            -header [list From    [id user]@[info hostname]]       \
            -header [list To      operator@[info hostname]]        \
            -header [list Subject "[info hostname] fatal $program"]
    }

    cleanup $result
}


exit 75
