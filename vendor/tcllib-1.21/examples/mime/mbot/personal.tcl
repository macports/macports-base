#!/usr/bin/env tclsh
## -*- tcl -*-
# personal.tcl - process personal mail
#
# (c) 1999 Marshall T. Rose
# Hold harmless the author, and any lawful use is allowed.
#
# The original version was written in 1994!
#

package require Tcl 8.3

global options


# begin of routines that may be redefined in configFile

proc impersonalMail {originator} {}

proc adminP {local domain} {
    set local [string tolower $local]

    foreach lhs [list administrator       \
                      archive-server      \
                      daemon              \
                      failrepter          \
                      faxmaster           \
                      gateway             \
                      listmaster          \
                      listproc            \
                      lotus_mail_exchange \
                      m400                \
                      *mailer*            \
                      *maiser*            \
                      mmdf                \
                      mrgate              \
                      mx-mailer-daemon    \
                      numbers-info-forw   \
                      postman*            \
                      *postmast*          \
                      pp                  \
                      smtp                \
                      sysadmin            \
                      ucx_smtp            \
                      uucp] {
        if {[string match $lhs $local]} {
            return 1
        }
    }

    return 0
}

proc friendP {local domain} {
    global options

    if {![info exists options(friendlyDomains)]} {
        return 0
    }

    set domain [string tolower $domain]

    foreach rhs $options(friendlyDomains) {
        if {(![string compare $rhs $domain]) \
                || ([string match *.$rhs $domain])} {
            return 1
        }
    }

    return 0
}

proc ownerP {local domain} {
    global options

    foreach mailbox {myMailbox pdaMailboxes remoteMailboxes} {
        if {![info exists options($mailbox)]} {
            continue
        }

        foreach addr [mime::parseaddress $options($mailbox)] {
            catch { unset aprops }

            array set aprops $addr
            if {![string compare [string tolower $local@$domain] \
                         [string tolower $aprops(local)@$aprops(domain)]]} {
                return 1
            }
        }
    }

    return 0
}

# the algorithm below is for systems that use the MMDF/MH convention

proc saveMessage {inF {outF ""}} {
    global errorCode errorInfo
    global options

    set inC [open $inF { RDONLY }]

    if {![string compare $outF ""]} {
        set outF $options(defaultMaildrop)
    }
    mutl::exclfile [set lockF $outF.lock]

    set code [catch { set outC [open $outF { WRONLY CREAT APPEND }] } result]
    set ecode $errorCode
    set einfo $errorInfo

    if {!$code} {
        set code [catch {
            puts $outC [set boundary "\001\001\001\001"]
            puts $outC "Delivery-Date: [mime::parsedatetime -now proper]"

            while {[gets $inC line] >= 0} {
                if {[string compare $boundary $line]} {
                    puts $outC $line
                } else {
                    puts $outC "\002\001\001\001"
                }
            }

            puts $outC $boundary
        } result]
        set ecode $errorCode
        set einfo $errorInfo

        if {[catch { close $outC } result2]} {
            tclLog $result2
        }
    }

    file delete -- $lockF

    if {[catch { close $inC } result2]} {
        tclLog $result2
    }

    return -code $code -errorinfo $einfo -errorcode $ecode $result
}

proc findPhrase {subject} {
    global options

    set subject [string toupper $subject]

    foreach file [glob -nocomplain [file join $options(dataDirectory) \
                                         phrases *]] {
        if {[catch { otp_words -mode encode \
                              [base64 -mode decode -- \
                                      [join [split [file tail $file] _] /]] } \
                    phrase]} {
            tclLog "$file: $phrase"
        } elseif {[string first $phrase $subject] >= 0} {
            if {[catch { file delete -- $file } result]} {
                tclLog $result
            }

            return 1
        }
    }

    return 0
}

proc makePhrase {} {
    global options

    if {![file isdirectory \
               [set phraseD [file join $options(dataDirectory) phrases]]]} {
        file mkdir $phraseD
    } else {
        pruneDir $phraseD phrase
    }

    set key [mime::uniqueID]
    set seqno 8
    while {[incr seqno -1] >= 0} {
        set key [otp_md5 -- $key]
    }

    set phraseF [file join $phraseD \
                      [join [split [string trim \
                                           [base64 -mode encode -- $key]] /] _]]
    if {[catch { close [open $phraseF { WRONLY CREAT TRUNC }] } result]} {
        tclLog $result
    }

    return [otp_words -mode encode -- $key]
}

proc pruneDir {dir type} {
    switch -- $type {
        addr {
            set days 14
        }

        msgid {
            set days 28
        }

        phrase {
            set days 7
        }
    }

    set then [expr {[clock seconds]-($days*86400)}]

    foreach file [glob -nocomplain [file join $dir *]] {
        if {(![catch { file mtime $file } result]) \
                && ($result < $then) \
                && ([catch { file delete -- $file } result])} {
            tclLog $result
        }
    }
}

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


global deleteFiles

set deleteFiles {}

proc cleanup {{message ""} {status 75}} {
    global deleteFiles

    foreach file $deleteFiles {
        if {[catch { file delete -- $file } result]} {
            tclLog $result
        }
    }

    if {[string compare $message ""]} {
        tclLog $message
        exit $status
    }

    exit 0
}

proc dofolder {folder inF} {
    global options

    catch { unset aprops }

    array set aprops [lindex [mime::parseaddress $folder] 0]
    set folder [join [split $aprops(local) /] _]

    if {[set folderN [llength [set folderL [split $folder .]]]] <= 1} {
        cleanup "invalid folder: $folder"
    }

    foreach f $folderL {
        if {![string compare $f ""]} {
            cleanup "invalid folder: $folder" 67
        }
    }

    if {![file isdirectory \
               [set articleD [eval [list file join \
                                         $options(foldersDirectory)] \
                                   [lrange $folderL 0 \
				   [expr {$folderN-2}]]]]]} {
        file mkdir $articleD
    }
    if {![file exists [set articleF [file join $articleD \
                                          [lindex $folderL \
					  [expr {$folderN-1}]]]]]} {
        set newP 1
    } else {
        set newP 0
    }

    set fd [open $options(foldersFile) { RDWR CREAT }]
    set fl "\n[read $fd]"

    set dir [lindex [file split $options(foldersDirectory)] end]
    if {[string first "\n$dir\n" $fl] < 0} {
        puts $fd $dir
    }
    foreach f $folderL {
        set dir [file join $dir $f]
        if {[string first "\n$dir\n" $fl] < 0} {
            puts $fd $dir
        }
    }

    close $fd

    if {[catch { saveMessage $inF $articleF } result]} {
        cleanup "unable to save message in $articleF: $result"
    }

    if {($newP) && ([info exists options(announceMailboxes)])} {
        if {[catch { smtp::sendmessage \
                         [mime::initialize \
                              -canonical text/plain \
                              -param {charset us-ascii} \
                              -string ""] \
                         -atleastone true \
                         -originator "" \
                         -header [list From    $options(myMailbox)] \
                         -header [list To      $options(announceMailboxes)] \
                         -header [list Subject "new folder $folder"] } \
                   result]} {
            tclLog $result
        }
    }
}

proc alladdrs {mime keys} {
    set result {}

    foreach key $keys {
        foreach value [mutl::getheader $mime $key] {
            foreach addr [mime::parseaddress $value] {
		lappend result $addr
	    }
	}
    }

    return $result
}

proc anyfriend {outD addrs} {
    global options

    if {!$options(friendlyFire)} {
	return ""
    }

    foreach addr $addrs {
        catch { unset aprops }

        array set aprops $addr
	if {[catch { string tolower $aprops(local)@$aprops(domain) } \
		   recipient]} {
	    continue
	}

	if {[ownerP $aprops(local) $aprops(domain)]} {
	    tclLog "DEBUG: skipping $recipient"
	    continue
	}

	set outF [file join $outD [join [split $recipient /] _]]
	if {[file exists $outF]} {
	    return $recipient
	}

	tclLog "DEBUG: unknown recipient $recipient"
    }

    return ""
}


if {[catch {

    set program personal

    package require mutl 1.0
    package require smtp 1.1
    package require Tclx 8.0


# parse arguments and initialize environment

    set program [file tail [file rootname $argv0]]

    set configFile .${program}-config.tcl

    set debugP 0

    set messageFile -

    set originatorAddress ""

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

            -file {
                set messageFile $value
            }

            -originator {
                set originatorAddress $value
            }

            -user {
                set userName $value
            }

            default {
                cleanup "unknown option $option"
            }
        }
    }

    if {![string compare $messageFile -]} {
        array set tmp [mutl::tmpfile personal]

        lappend deleteFiles [set messageFile $tmp(file)]

        catch { file attributes $messageFile -permissions 0600 }

        if {[gets stdin line] <= 0} {
            cleanup "empty message"
        }
        if {[string first "From " $line] == 0} {
            if {![string compare $originatorAddress ""]} {
                set line [string range $line 5 end]
                if {[set x [string first " " $line]] > 0} {
                    set originatorAddress [string range $line 0 [expr {$x-1}]]
                }
            }
        } else {
            puts $tmp(fd) $line
        }
        fcopy stdin $tmp(fd)
        close $tmp(fd)
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

    foreach k [list dataDirectory defaultMaildrop] {
        if {![info exists options($k)]} {
            cleanup "configFile didn't define $k: $configFile"
        }
    }

    if {![file isdirectory $options(dataDirectory)]} {
        file mkdir $options(dataDirectory)
    }

    if {![info exists options(myMailbox)]} {
        set options(myMailbox) [id user]
    }

    if {![info exists options(friendlyFire)]} {
        set options(friendlyFire) 0
    }


# crack the message

    if {[catch { set mime [mime::initialize -file $messageFile] } result]} {
#        global errorCode errorInfo
#
#        set ecode $errorCode
#        set einfo $errorInfo
#
#        if {![catch {
#            smtp::sendmessage \
#                [mime::initialize \
#                     -canonical multipart/mixed \
#                     -parts [list [mime::initialize \
#                                        -canonical text/plain \
#                                        -param  {charset us-ascii} \
#                                        -string "$result\n\nerrorCode: $ecode\n\n$einfo"] \
#                                  [mime::initialize \
#                                        -canonical application/octet-stream \
#                                        -file $messageFile]]] \
#                -originator "" \
#                -header [list From    $options(myMailbox)] \
#                -header [list To      $options(myMailbox)] \
#                -header [list Subject "[info hostname] alert $program"]
#        }]} {
#            set result ""
#        }

	if {[info exists options(auditInFile)]} {
	    saveMessage $messageFile $options(auditInFile)
	    tclLog "invalid, but saved: $result"
	    cleanup
	}

        cleanup "re-queued: $result"
    }

    set origProper ""
    foreach key {From Sender Return-Path} {
        if {[string compare \
                    [set origProper [mutl::firstaddress \
                                         [mutl::getheader $mime $key]]] \
                    ""]} {
            break
        }
    }
    if {![string compare $origProper ""]} {
        set origProper [mutl::firstaddress [list $originatorAddress]]
    }

    catch { unset aprops }

    array set aprops [list local "" domain ""]
    array set aprops [lindex [mime::parseaddress $origProper] 0]
    set origLocal $aprops(local)
    set origDomain $aprops(domain)

    regsub -all "  *" \
           [set subject [string trim \
                                [lindex [mutl::getheader $mime Subject] 0]]] \
           " " subject


    if {[catch { set folderTarget [impersonalMail $origLocal@$origDomain] }]} {
        set folderTarget ""
    }
    if {[set impersonalP [string compare $folderTarget ""]]} {
        if {![info exists options(foldersDirectory)]} {
            cleanup "configFile didn't define folderTarget: $configFile"
        }
    } elseif {[info exists options(auditInFile)]} {
# keep an audit copy of personal mail

        saveMessage $messageFile $options(auditInFile)
    }


# perform duplicate supression

    set messageID [lindex [concat [mutl::getheader $mime Resent-Message-ID] \
                                  [mutl::getheader $mime Message-ID]] 0]
    if {[string compare $messageID ""]} {
        if {![file isdirectory \
                   [set idD [file join $options(dataDirectory) msgids]]]} {
            file mkdir $idD
        } else {
            pruneDir $idD msgid
        }

        if {[set len [string length $messageID]] > 2} {
            set messageID [string range $messageID 1 [expr {$len-2}]]
        }
        if {$impersonalP} {
            set prefix X-

            catch { unset aprops }

            array set aprops [lindex [mime::parseaddress $folderTarget] 0]
            set prefix \
                X-[lindex [split [join [split $aprops(local) /] _] .] 0]-
        } else {
            set prefix ""
        }

        set idF [file join $idD $prefix[join [split $messageID /] _]]
        if {[file exists $idF]} {
            tclLog "duplicate ID: $origProper $messageID ($subject)"

            cleanup
        }

        if {[catch { close [open $idF { WRONLY CREAT TRUNC }] } result]} {
            tclLog $result
        }
    }


# record information about the originator

    if {![string compare \
                 [set origAddress \
                      [string tolower $origLocal@$origDomain]] \
                 @]} {
        tclLog "no originator"

        if {!$impersonalP} {
            saveMessage $messageFile
        }

        cleanup
    }

    tclLog "DEBUG processing: $origProper <$messageID> ($subject)"

    if {![file isdirectory \
                   [set inD [file join $options(dataDirectory) inaddrs]]]} {
        file mkdir $inD
    }

    set inF [file join $inD [join [split $origAddress /] _]]
    if {[catch { set fd [open $inF { WRONLY CREAT TRUNC }] } result]} {
        tclLog $result
    } else {
        catch { puts $fd $origProper }
        if {[catch { close $fd } result]} {
            tclLog $result
        }
    }


# store impersonal mail in private folder area

    if {$impersonalP} {
        if {![string compare $messageID ""]} {
            cleanup "no Message-ID"
        }

        if {![file isdirectory $options(foldersDirectory)]} {
            file mkdir $foldersDirectory
        }

        array set mapping {}

        if {![catch { set fd [open $options(mappingFile) { RDONLY }] }]} {
            while {[gets $fd line] >= 0} {
                if {([llength [set map [split $line :]]] == 2) \
                        && ([string length \
                                    [set k [string trim [lindex $map 0]]]] \
                                > 0) \
                        && ([string length \
                                    [set v [string trim [lindex $map 1]]]] \
                                > 0)} {
                    set mapping($k) $v
                }
            }

            if {[catch { close $fd } result]} {
                tclLog $result
            }
        }

        if {![info exists mapping($folderTarget)]} {
            set mapping($folderTarget) store
        }
        if {![string compare $mapping($folderTarget) process]} {
            catch { set mapping($folderTarget) \
                        [processFolder $folderTarget $mime] }
        }
        switch -- $mapping($folderTarget) {
            store {
                dofolder $folderTarget $messageFile
            }

            ignore {
                tclLog "ignoring message for $folderTarget"
            }

            bounce {
                cleanup "rejecting message for $folderTarget" 67
            }

            default {
                if {[catch { smtp::sendmessage $mime \
                                 -atleastone true \
                                 -originator "" \
                                 -recipients $mapping($folderTarget) } \
                            result]} {
                    tclLog $result
                }
            }
        }

        cleanup
    }


# perform originator supression and guest list maintenance

    if {[string compare \
                [set resentProper \
                     [mutl::firstaddress \
                          [mutl::getheader $mime Resent-From]]] \
                ""]} {
        catch { unset aprops }

        array set aprops [lindex [mime::parseaddress $resentProper] 0]
        set resentLocal $aprops(local)
        set resentDomain $aprops(domain)

        if {[string compare \
                    [set resentAddress \
                         [string tolower $resentLocal@$resentDomain]] \
                    @]} {
            foreach p {Proper Local Domain Address} {
                set orig$p [set resent$p]
            }
        }
    }

    foreach p {out tmp bad} {
        if {![file isdirectory [set ${p}D [file join $options(dataDirectory) \
                                                ${p}addrs]]]} {
            file mkdir [set ${p}D]
        }

        set ${p}F [file join [set ${p}D] [join [split $origAddress /] _]]
    }

    pruneDir $tmpD addr


# deal with Klez-inspired nonsense
    if {([info exists options(dropNames)]) && ([catch { 
        foreach part [mime::getproperty $mime parts] {
            catch { unset params }
            array set params [mime::getproperty $part params]
            if {[info exists params(name)]} {
		foreach name $options(dropNames) {
		    if {[string match $name $params(name)]} {
                        tclLog "rejecting: $origProper <$messageID> ($subject) $params(name)"
                        cleanup
		    }
		}
            }
        }
    } result])} {
	tclLog "Klez-check: $result"
    }

    set friend ""
    if {[adminP $origLocal $origDomain]} {
        tclLog "DEBUG admin check: $origProper <$messageID> ($subject)"

# if DSNs were the rule, it would make sense to parse it... no such luck

        set fd [open $messageFile { RDONLY }]
        set text [read $fd]
        if {[catch { close $fd } result]} {
            tclLog $result
        }

        foreach file [glob -nocomplain [file join $badD *]] {
            set addr [file tail $file]
            if {([string match *$addr* $text]) \
                    || (([set x [string first @ $addr]] > 0) \
                            && ([string match \
			    *[string range $addr 0 [expr {$x-1}]]* \
                                        $text]))} {
                tclLog "failure notice: $origProper ($addr)"

                cleanup
            }
        }

        tclLog "DEBUG admin continue: $origProper <$messageID> ($subject)"
    } elseif {(![ownerP $origLocal $origDomain]) \
                    && (![friendP $origLocal $origDomain]) \
                    && (![file exists $outF]) \
                    && (![file exists $tmpF]) \
                    && (![string compare ""\
		              [set friend [anyfriend $outD \
			                      [alladdrs $mime {To cc}]]]]) \
                    && (![findPhrase $subject]) \
                    && ([info exists options(noticeFile)])} {
        if {[file exists $badF]} {
            catch { file delete -- $badF }
        } elseif {[catch {
            set fd [open $options(noticeFile) { RDONLY }]
            set text [read $fd]
            if {[catch { close $fd } result]} {
                tclLog $result
            }

            regsub -all %passPhrase% $text [makePhrase] text
            for {set rsubject $subject} \
                    {[regexp -nocase ^re: $rsubject]} \
                    {set rsubject [string trimleft \
                                           [string range $rsubject 3 end]]} {
            }
            regsub -all %subject% $text $rsubject text

            smtp::sendmessage \
                [mime::initialize \
                     -canonical multipart/mixed \
                     -parts [list [mime::initialize \
                                       -canonical text/plain \
                                       -param {charset us-ascii} \
                                       -string $text] \
                                  [mime::initialize \
                                        -canonical message/rfc822 \
                                        -parts [list $mime]]]] \
                -originator "" \
                -header [list From    $options(myMailbox)] \
                -header [list To      $origProper] \
                -header [list Subject "Re: $rsubject"]

             set fd [open $badF { WRONLY CREAT TRUNC }]
        } result]} {
            tclLog $result
        } else {
            catch { puts $fd $origProper }
            if {[catch { close $fd } result]} {
                tclLog $result
            }
        }
        tclLog "rejecting: $origProper <$messageID> ($subject)"

        cleanup
    } elseif {[string compare $friend ""]} {
        tclLog "accepting: $origProper because of $friend"
    } else {
        if {[ownerP $origLocal $origDomain]} {
            set addrD $outD
        } else {
            set addrD $tmpD
        }

	foreach addr [alladdrs $mime \
		               {From To cc Resent-From Resent-To Resent-cc}] {
            catch { unset aprops }

            array set aprops $addr
            set addrLocal $aprops(local)
            set addrDomain $aprops(domain)

            if {[string compare \
                        [set addrAddress \
                             [string tolower $addrLocal@$addrDomain]] @]} {
                set addrF [file join $addrD [join [split $addrAddress /] _]]

                if {[file exists $addrF]} {
                    continue
                }

                if {[catch { set fd [open $addrF { WRONLY CREAT TRUNC }] } \
                           result]} {
                    tclLog $result
                } else {
                    catch { puts $fd $aprops(proper) }
                    if {[catch { close $fd } result]} {
                        tclLog $result
                    }
                }
	    }
        }
    }


# perform final actions, if we're the originator

    if {[ownerP $origLocal $origDomain]} {
        if {[info exists options(auditOutFile)]} {
            saveMessage $messageFile $options(auditOutFile)
        }

        cleanup
    }


# send a copy to the pda

    if {([info exists options(pdaMailboxes)]) \
            && ([string compare [set text [mutl::gathertext $mime]] ""])} {
        if {[info exists options(pdaMailsize)]} {
            set text [string range $text 0 [expr {$options(pdaMailsize)-1}]]
        }
        set pda [mime::initialize \
                     -canonical text/plain \
                     -param {charset us-ascii} \
                     -string $text]

        foreach key {From To cc Subject Date Reply-To} {
            foreach value [mutl::getheader $mime $key] {
                mime::setheader $pda $key $value -mode append
            }
        }

        if {[catch { smtp::sendmessage $pda \
                         -atleastone true \
                         -originator "" \
                         -recipients $options(pdaMailboxes) } result]} {
            tclLog $result
        }
    }


# send a copy to the remote mailbox

    if {[info exists options(remoteMailboxes)]} {
        if {[catch { smtp::sendmessage $mime \
                         -atleastone true \
                         -originator "" \
                         -recipients $options(remoteMailboxes) } result]} {
            tclLog $result
        } else {
            cleanup
        }
    }

    saveMessage $messageFile


    cleanup


} result]} {
    global errorCode errorInfo

    set ecode $errorCode
    set einfo $errorInfo

    if {(![catch { info body tclLog } result2]) \
            && ([string compare [string trim $result2] \
                        {catch {puts stderr $string}}])} {
        catch { tclLog $result }
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
