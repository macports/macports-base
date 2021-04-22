# nntp.tcl --
#
#       nntp implementation for Tcl.
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
# All rights reserved.
# 
# RCS: @(#) $Id: nntp.tcl,v 1.13 2004/05/03 22:56:25 andreas_kupries Exp $

package require Tcl 8.2
package provide nntp 0.2.1

namespace eval ::nntp {
    # The socks variable holds the handle to the server connections
    variable socks

    # The counter is used to help create unique connection names
    variable counter 0

    # commands is the list of subcommands recognized by nntp
    variable commands [list \
            "article"     \
            "authinfo"    \
            "body"        \
            "date"        \
            "group"       \
            "head"        \
            "help"        \
            "last"        \
            "list"        \
            "listgroup"   \
            "mode_reader" \
            "newgroups"   \
            "newnews"     \
            "next"        \
            "post"        \
            "stat"        \
            "quit"        \
            "xgtitle"     \
            "xhdr"        \
            "xover"       \
            "xpat"        \
            ]

    set ::nntp::eol "\n"

    # only export one command, the one used to instantiate a new
    # nntp connection 
    namespace export nntp

}

# ::nntp::nntp --
#
#       Create a new nntp connection.
#
# Arguments:
#        server -   The name of the nntp server to connect to (optional).
#        port -     The port number to connect to (optional).
#        name -     The name of the nntp connection to create (optional).
#
# Results:
#    Creates a connection to the a nntp server.  By default the
#    connection is established with the machine 'news' at port '119'
#    These defaults can be overridden with the environment variables
#    NNTPPORT and NNTPHOST, or can be passed as optional arguments

proc ::nntp::nntp {{server ""} {port ""} {name ""}} {
    global env
    variable connections
    variable counter
    variable socks

    # If a name wasn't specified for the connection, create a new 'unique'
    # name for the connection 

    if { [llength [info level 0]] < 4 } {
        set counter 0
        set name "nntp${counter}"
        while {[lsearch -exact [info commands] $name] >= 0} {
            incr counter
            set name "nntp${counter}"
        }
    }

    if { ![string equal [info commands ::$name] ""] } {
        error "command \"$name\" already exists, unable to create nntp connection"
    }

    upvar 0 ::nntp::${name}data data

    set socks($name) [list ]

    # Initialize instance specific variables

    set data(debug) 0
    set data(eol) "\n"

    # Logic to determine whether to use the specified nntp server, or to use
    # the default

    if {$server == ""} {
        if {[info exists env(NNTPSERVER)]} {
            set data(host) "$env(NNTPSERVER)"
        } else {
            set data(host) "news"
        }
    } else {
        set data(host) $server
    }

    # Logic to determine whether to use the specified nntp port, or to use the
    # default.

    if {$port == ""} {
        if {[info exists env(NNTPPORT)]} {
            set data(port) $env(NNTPPORT)
        } else {    
            set data(port) 119
        }
    } else {
        set data(port) $port
    }
 
    set data(code) 0
    set data(mesg) ""
    set data(addr) ""
    set data(binary) 0

    set sock [socket $data(host) $data(port)]

    set data(sock) $sock

    # Create the command to manipulate the nntp connection

    interp alias {} ::$name {} ::nntp::NntpProc $name
    
    ::nntp::response $name

    return $name
}

# ::nntp::NntpProc --
#
#       Command that processes all nntp object commands.
#
# Arguments:
#       name    name of the nntp object to manipulate.
#       args    command name and args for the command.
#
# Results:
#       Calls the appropriate nntp procedure for the command specified in
#       'args' and passes 'args' to the command/procedure.

proc ::nntp::NntpProc {name {cmd ""} args} {

    # Do minimal args checks here

    if { [llength [info level 0]] < 3 } {
        error "wrong # args: should be \"$name option ?arg arg ...?\""
    }

    # Split the args into command and args components

    if { [llength [info commands ::nntp::_$cmd]] == 0 } {
        variable commands
        set optlist [join $commands ", "]
        set optlist [linsert $optlist "end-1" "or"]
        error "bad option \"$cmd\": must be $optlist"
    }

    # Call the appropriate command with its arguments

    return [eval [linsert $args 0 ::nntp::_$cmd $name]]
}

# ::nntp::okprint --
#
#       Used to test the return code stored in data(code) to
#       make sure that it is alright to right to the socket.
#
# Arguments:
#       name    name of the nntp object.
#
# Results:
#       Either throws an error describing the failure, or
#       'args' and passes 'args' to the command/procedure or
#       returns 1 for 'OK' and 0 for error states.   

proc ::nntp::okprint {name} {
    upvar 0 ::nntp::${name}data data

    if {$data(code) >=400} {
        set val [expr {(0 < $data(code)) && ($data(code) < 400)}]
        error "NNTPERROR: $data(code) $data(mesg)"
    }

    # Codes less than 400 are good

    return [expr {(0 < $data(code)) && ($data(code) < 400)}]
}

# ::nntp::message --
#
#       Used to format data(mesg) for printing to the socket
#       by appending the appropriate end of line character which
#       is stored in data(eol).
#
# Arguments:
#       name    name of the nntp object.
#
# Results:
#       Returns a string containing the message from data(mesg) followed
#       by the eol character(s) stored in data(eol)

proc ::nntp::message {name} {
    upvar 0 ::nntp::${name}data data

    return "$data(mesg)$data(eol)"
}

#################################################
#
# NNTP Methods
#

proc ::nntp::_cget {name option} {
    upvar 0 ::nntp::${name}data data

    if {[string equal $option -binary]} {
	return $data(binary)
    } else {
	return -code error \
		"Illegal option \"$option\", expected \"-binary\""
    }
}

proc ::nntp::_configure {name args} {
    upvar 0 ::nntp::${name}data data

    if {[llength $args] == 0} {
	return [list -binary $data(binary)]
    }
    if {[llength $args] == 1} {
	return [_cget $name [lindex $args 0]]
    }
    if {([llength $args] % 2) == 1} {
	return -code error \
		"wrong#args: expected even number of elements"
    }
    foreach {o v} $args {
	if {[string equal $o -binary]} {
	    if {![string is boolean -strict $v]} {
		return -code error \
			"Expected boolean, got \"$v\""
	    }
	    set data(binary) $v
	} else {
	    return -code error \
		    "Illegal option \"$o\", expected \"-binary\""
	}
    }
    return {}
}


# ::nntp::_article --
#
#       Internal article proc.  Called by the 'nntpName article' command.
#       Retrieves the article specified by msgid, in the group specified by
#       the 'nntpName group' command.  If no msgid is specified the current 
#       (or first) article in the group is retrieved
#
# Arguments:
#       name    name of the nntp object.
#       msgid   The article number to retrieve
#
# Results:
#       Returns the message (if there is one) from the specified group as
#       a valid tcl list where each element is a line of the message.
#       If no article is found, the "" string is returned.
#
# According to RFC 977 the responses are:
#
#   220 n  article retrieved - head and body follow
#           (n = article number,  = message-id)
#   221 n  article retrieved - head follows
#   222 n  article retrieved - body follows
#   223 n  article retrieved - request text separately
#   412 no newsgroup has been selected
#   420 no current article has been selected
#   423 no such article number in this group
#   430 no such article found
#
 
proc ::nntp::_article {name {msgid ""}} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "fetch"
    return [::nntp::command $name "ARTICLE $msgid"]
}

# ::nntp::_authinfo --
#
#       Internal authinfo proc.  Called by the 'nntpName authinfo' command.
#       Passes the username and password for a nntp server to the nntp server. 
#
# Arguments:
#       name    Name of the nntp object.
#       user    The username for the nntp server.
#       pass    The password for 'username' on the nntp server.
#
# Results:
#       Returns the result of the attempts to set the username and password
#       on the nntp server ( 1 if successful, 0 if failed).

proc ::nntp::_authinfo {name {user "guest"} {pass "foobar"}} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) ""
    set res [::nntp::command $name "AUTHINFO USER $user"]
    if {$res} {
        set res [expr {$res && [::nntp::command $name "AUTHINFO PASS $pass"]}]
    }
    return $res
}

# ::nntp::_body --
#
#       Internal body proc.  Called by the 'nntpName body' command.
#       Retrieves the body of the article specified by msgid from the group
#       specified by the 'nntpName group' command. If no msgid is specified
#       the current (or first) message body is returned  
#
# Arguments:
#       name    Name of the nntp object.
#       msgid   The number of the body of the article to retrieve
#
# Results:
#       Returns the body of article 'msgid' from the group specified through
#       'nntpName group'. If msgid is not specified or is "" then the body of
#       the current (or the first) article in the newsgroup will be returned 
#       as a valid tcl list.  The "" string will be returned if there is no
#       article 'msgid' or if no group has been specified.

proc ::nntp::_body {name {msgid ""}} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "fetch"
    return [::nntp::command $name "BODY $msgid"]
}

# ::nntp::_group --
#
#       Internal group proc.  Called by the 'nntpName group' command.
#       Sets the current group on the nntp server to the group passed in.
#
# Arguments:
#       name    Name of the nntp object.
#       group   The name of the group to set as the default group.
#
# Results:
#    Sets the default group to the group specified. If no group is specified
#    or if an invalid group is specified an error is thrown.
#
# According to RFC 977 the responses are:
#
#  211 n f l s group selected
#           (n = estimated number of articles in group,
#           f = first article number in the group,
#           l = last article number in the group,
#           s = name of the group.)
#  411 no such news group

proc ::nntp::_group {name {group ""}} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "groupinfo"
    if {$group == ""} {
        set group $data(group)
    }
    return [::nntp::command $name "GROUP $group"]
}

# ::nntp::_head --
#
#       Internal head proc.  Called by the 'nntpName head' command.
#       Retrieves the header of the article specified by msgid from the group
#       specified by the 'nntpName group' command. If no msgid is specified
#       the current (or first) message header is returned  
#
# Arguments:
#       name    Name of the nntp object.
#       msgid   The number of the header of the article to retrieve
#
# Results:
#       Returns the header of article 'msgid' from the group specified through
#       'nntpName group'. If msgid is not specified or is "" then the header of
#       the current (or the first) article in the newsgroup will be returned 
#       as a valid tcl list.  The "" string will be returned if there is no
#       article 'msgid' or if no group has been specified.

proc ::nntp::_head {name {msgid ""}} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "fetch"
    return [::nntp::command $name "HEAD $msgid"]
}

# ::nntp::_help --
#
#       Internal help proc.  Called by the 'nntpName help' command.
#       Retrieves a list of the valid nntp commands accepted by the server.
#
# Arguments:
#       name    Name of the nntp object.
#
# Results:
#       Returns the NNTP commands expected by the NNTP server.

proc ::nntp::_help {name} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "fetch"
    return [::nntp::command $name "HELP"]
}

proc ::nntp::_ihave {name {msgid ""} args} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "fetch"
    if {![::nntp::command $name "IHAVE $msgid"]} {
        return ""
    }
    return [::nntp::squirt $name "$args"]    
}

# ::nntp::_last --
#
#       Internal last proc.  Called by the 'nntpName last' command.
#       Sets the current message to the message before the current message.
#
# Arguments:
#       name    Name of the nntp object.
#
# Results:
#       None.

proc ::nntp::_last {name} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "msgid"
    return [::nntp::command $name "LAST"]
}

# ::nntp::_list --
#
#       Internal list proc.  Called by the 'nntpName list' command.
#       Lists all groups or (optionally) all groups of a specified type.
#
# Arguments:
#       name    Name of the nntp object.
#       Type    The type of groups to return (active active.times newsgroups
#               distributions distrib.pats moderators overview.fmt
#               subscriptions) - optional.
#
# Results:
#       Returns a tcl list of all groups or the groups that match 'type' if
#       a type is specified.

proc ::nntp::_list {name {type ""}} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "fetch"
    return [::nntp::command $name "LIST $type"]
}

# ::nntp::_newgroups --
#
#       Internal newgroups proc.  Called by the 'nntpName newgroups' command.
#       Lists all new groups since a specified time.
#
# Arguments:
#       name    Name of the nntp object.
#       since   The time to find new groups since.  The time can be in any
#               format that is accepted by 'clock scan' in tcl.
#
# Results:
#       Returns a tcl list of all new groups added since the time specified. 

proc ::nntp::_newgroups {name since args} {
    upvar 0 ::nntp::${name}data data

    set since [clock format [clock scan "$since"] -format "%y%m%d %H%M%S"]
    set dist ""
    set data(cmnd) "fetch"
    return [::nntp::command $name "NEWGROUPS $since $dist"]
}

# ::nntp::_newnews --
#
#       Internal newnews proc.  Called by the 'nntpName newnews' command.
#       Lists all new news in the specified group since a specified time.
#
# Arguments:
#       name    Name of the nntp object.
#       group   Name of the newsgroup to query.
#       since   The time to find new groups since.  The time can be in any
#               format that is accepted by 'clock scan' in tcl. Defaults to
#               "1 day ago"
#
# Results:
#       Returns a tcl list of all new messages since the time specified. 

proc ::nntp::_newnews {name {group ""} {since ""}} {
    upvar 0 ::nntp::${name}data data

    if {$group != ""} {
        if {[regexp -- {^[\w\.\-]+$} $group] == 0} {
            set since $group
            set group ""
        }
    }
    if {![info exists group] || ($group == "")} {
        if {[info exists data(group)] && ($data(group) != "")} {
            set group $data(group)
        } else {
            set group "*"
        }
    }
    if {"$since" == ""} {
        set since [clock format [clock scan "now - 1 day"]]
    }
    set since [clock format [clock scan $since] -format "%y%m%d %H%M%S"]
    set dist "" 
    set data(cmnd) "fetch"
    return [::nntp::command $name "NEWNEWS $group $since $dist"]
}

# ::nntp::_next --
#
#       Internal next proc.  Called by the 'nntpName next' command.
#       Sets the current message to the next message after the current message.
#
# Arguments:
#       name    Name of the nntp object.
#
# Results:
#       None.

proc ::nntp::_next {name} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "msgid"
    return [::nntp::command $name "NEXT"]
}

# ::nntp::_post --
#
#       Internal post proc.  Called by the 'nntpName post' command.
#       Posts a message to a newsgroup.
#
# Responses (according to RFC 977) to a post request:
#  240 article posted ok
#  340 send article to be posted. End with .
#  440 posting not allowed
#  441 posting failed
#
# Arguments:
#       name    Name of the nntp object.
#       article A message of the form specified in RFC 850
#
# Results:
#       None.

proc ::nntp::_post {name article} {
    
    if {![::nntp::command $name "POST"]} {
        return ""
    }
    return [::nntp::squirt $name "$article"]
}

# ::nntp::_slave --
#
#       Internal slave proc.  Called by the 'nntpName slave' command.
#       Identifies a connection as being made from a slave nntp server.
#       This might be used to indicate that the connection is serving
#       multiple people and should be given priority.  Actual use is 
#       entirely implementation dependant and may vary from server to
#       server.
#
# Arguments:
#       name    Name of the nntp object.
#
# Results:
#       None.
#
# According to RFC 977 the only response is:
#
#    202 slave status noted

proc ::nntp::_slave {name} {
    return [::nntp::command $name "SLAVE"]
}

# ::nntp::_stat --
#
#       Internal stat proc.  Called by the 'nntpName stat' command.
#       The stat command is similar to the article command except that no
#       text is returned.  When selecting by message number within a group,
#       the stat command serves to set the current article pointer without
#       sending text. The returned acknowledgement response will contain the
#       message-id, which may be of some value.  Using the stat command to
#       select by message-id is valid but of questionable value, since a
#       selection by message-id does NOT alter the "current article pointer"
#
# Arguments:
#       name    Name of the nntp object.
#       msgid   The number of the message to stat (optional) default is to
#               stat the current article
#
# Results:
#       Returns the statistics for the article.

proc ::nntp::_stat {name {msgid ""}} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "status"
    return [::nntp::command $name "STAT $msgid"]
}

# ::nntp::_quit --
#
#       Internal quit proc.  Called by the 'nntpName quit' command.
#       Quits the nntp session and closes the socket.  Deletes the command
#       that was created for the connection.
#
# Arguments:
#       name    Name of the nntp object.
#
# Results:
#       Returns the return value from the quit command.

proc ::nntp::_quit {name} {
    upvar 0 ::nntp::${name}data data

    set ret [::nntp::command $name "QUIT"]
    close $data(sock)
    rename ${name} {}
    return $ret
}

#############################################################
#
# Extended methods (not available on all NNTP servers
#

proc ::nntp::_date {name} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "msg"
    return [::nntp::command $name "DATE"]
}

proc ::nntp::_listgroup {name {group ""}} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "fetch"
    return [::nntp::command $name "LISTGROUP $group"]
}

proc ::nntp::_mode_reader {name} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "msg"
    return [::nntp::command $name "MODE READER"]
}

proc ::nntp::_xgtitle {name {group_pattern ""}} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "fetch"
    return [::nntp::command $name "XGTITLE $group_pattern"]
}

proc ::nntp::_xhdr {name {header "message-id"} {list ""} {last ""}} {
    upvar 0 ::nntp::${name}data data

    if {![regexp -- {\d+-\d+} $list]} {
        if {"$last" != ""} {
            set list "$list-$last"
        } else {
            set list ""
	}
    }
    set data(cmnd) "fetch"
    return [::nntp::command $name "XHDR $header $list"]    
}

proc ::nntp::_xindex {name {group ""}} {
    upvar 0 ::nntp::${name}data data

    if {("$group" == "") && [info exists data(group)]} {
        set group $data(group)
    }
    set data(cmnd) "fetch"
    return [::nntp::command $name "XINDEX $group"]    
}

proc ::nntp::_xmotd {name {since ""}} {
    upvar 0 ::nntp::${name}data data

    if {"$since" != ""} {
        set since [clock seconds]
    }
    set since [clock format [clock scan $since] -format "%y%m%d %H%M%S"]
    set data(cmnd) "fetch"
    return [::nntp::command $name "XMOTD $since"]    
}

proc ::nntp::_xover {name {list ""} {last ""}} {
    upvar 0 ::nntp::${name}data data
    if {![regexp -- {\d+-\d+} $list]} {
        if {"$last" != ""} {
            set list "$list-$last"
        } else {
            set list ""
	}
    }
    set data(cmnd) "fetch"
    return [::nntp::command $name "XOVER $list"]
}

proc ::nntp::_xpat {name {header "subject"} {list 1} {last ""} args} {
    upvar 0 ::nntp::${name}data data

    set patterns ""

    if {![regexp -- {\d+-\d+} $list]} {
        if {("$last" != "") && ([string is digit $last])} {
            set list "$list-$last"
        }
    } elseif {"$last" != ""} {
        set patterns "$last"
    }
    
    if {[llength $args] > 0} {
        set patterns "$patterns $args"
    }

    if {"$patterns" == ""} {
        set patterns "*"
    }
    
    set data(cmnd) "fetch"
    return [::nntp::command $name "XPAT $header $list $patterns"]
}

proc ::nntp::_xpath {name {msgid ""}} {
    upvar 0 ::nntp::${name}data data

    set data(cmnd) "msg"
    return [::nntp::command $name "XPATH $msgid"]
}

proc ::nntp::_xsearch {name args} {
    set res [::nntp::command $name "XSEARCH"]
    if {!$res} {
        return ""
    }
    return [::nntp::squirt $name "$args"]    
}

proc ::nntp::_xthread {name args} {
    upvar 0 ::nntp::${name}data data

    if {[llength $args] > 0} {
        set filename "dbinit"
    } else {
        set filename "thread"
    }
    set data(cmnd) "fetchbinary"
    return [::nntp::command $name "XTHREAD $filename"]
}

######################################################
#
# Helper methods
#

proc ::nntp::cmd {name cmd} {
    upvar 0 ::nntp::${name}data data

    set eol "\015\012"
    set sock $data(sock)
    if {$data(debug)} {
        puts stderr "$sock command $cmd"
    }
    puts $sock "$cmd"
    flush $sock
    return
}

proc ::nntp::command {name args} {
    set res [eval [linsert $args 0 ::nntp::cmd $name]]
    
    return [::nntp::response $name]
}

proc ::nntp::msg {name} {
    upvar 0 ::nntp::${name}data data

    set res [::nntp::okprint $name]
    if {!$res} {
        return ""
    }
    return $data(mesg)
}

proc ::nntp::groupinfo {name} {
    upvar 0 ::nntp::${name}data data

    set data(group) ""

    if {[::nntp::okprint $name] && [regexp -- {(\d+)\s+(\d+)\s+(\d+)\s+([\w\.]+)} \
            $data(mesg) match count first last data(group)]} {
        return [list $count $first $last $data(group)]
    }
    return ""
}

proc ::nntp::msgid {name} {
    upvar 0 ::nntp::${name}data data

    set result ""
    if {[::nntp::okprint $name] && \
            [regsub -- {\s+<[^>]+>} $data(mesg) {} result]} {
        return $result
    } else {
        return ""
    }
}

proc ::nntp::status {name} {
    upvar 0 ::nntp::${name}data data

    set result ""
    if {[::nntp::okprint $name] && \
            [regexp -- {\d+\s+<[^>]+>} $data(mesg) result]} {
        return $result
    } else {
        return ""
    }
}

proc ::nntp::fetch {name} {
    upvar 0 ::nntp::${name}data data

    set eol "\012"

    if {![::nntp::okprint $name]} {
        return ""
    }
    set sock $data(sock)

    if {$data(binary)} {
	set oldenc [fconfigure $sock -encoding]
	fconfigure $sock -encoding binary
    }

    set result [list ]
    while {![eof $sock]} {
        gets $sock line
        regsub -- {\015?\012$} $line $data(eol) line

        if {[string match "." $line]} {
            break
        }
	if { [string match "..*" $line] } {
	    lappend result [string range $line 1 end]
	} else {
	    lappend result $line
	}
    }

    if {$data(binary)} {
	fconfigure $sock -encoding $oldenc
    }

    return $result
}

proc ::nntp::response {name} {
    upvar 0 ::nntp::${name}data data

    set eol "\012"

    set sock $data(sock)

    gets $sock line
    set data(code) 0
    set data(mesg) ""

    if {$line == ""} {
        error "nntp: unexpected EOF on $sock\n"
    }

    regsub -- {\015?\012$} $line "" line

    set result [regexp -- {^((\d\d)(\d))\s*(.*)} $line match \
            data(code) val1 val2 data(mesg)]
    
    if {$result == 0} {
        puts stderr "nntp garbled response: $line\n";
        return ""
    }

    if {$val1 == 20} {
        set data(post) [expr {!$val2}]
    }

    if {$data(debug)} {
        puts stderr "val1 $val1 val2 $val2"
        puts stderr "code '$data(code)'"
        puts stderr "mesg '$data(mesg)'"
        if {[info exists data(post)]} {
            puts stderr "post '$data(post)'"
        }
    } 

    return [::nntp::returnval $name]
}

proc ::nntp::returnval {name} {
    upvar 0 ::nntp::${name}data data

    if {([info exists data(cmnd)]) \
            && ($data(cmnd) != "")} {
        set command $data(cmnd)
    } else {
        set command okprint
    }
    
    if {$data(debug)} {
        puts stderr "returnval command '$command'"
    }

    set data(cmnd) ""
    return [::nntp::$command $name]
}

proc ::nntp::squirt {name {body ""}} {
    upvar 0 ::nntp::${name}data data

    set body [split $body \n]

    if {$data(debug)} {
        puts stderr "$data(sock) sending [llength $body] lines\n";
    }

    foreach line $body {
        # Print each line, possibly prepending a dot for lines
        # starting with a dot and trimming any trailing \n.
	if { [string match ".*" $line] } {
	    set line ".$line"
	}
        puts $data(sock) $line
    }
    puts $data(sock) "."
    flush $data(sock)

    if {$data(debug)} {
        puts stderr "$data(sock) is finished sending"
    }
    return [::nntp::response $name]
}
#eof

