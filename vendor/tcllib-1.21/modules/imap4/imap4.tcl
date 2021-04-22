# IMAP4 protocol pure Tcl implementation.
#
# COPYRIGHT AND PERMISSION NOTICE
#
# Copyright (C) 2004 Salvatore Sanfilippo <antirez@invece.org>.
# Copyright (C) 2013 Nicola Hall <nicci.hall@gmail.com>
# Copyright (C) 2013 Magnatune <magnatune@users.sourceforge.net>
#
# All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, and/or sell copies of the Software, and to permit persons
# to whom the Software is furnished to do so, provided that the above
# copyright notice(s) and this permission notice appear in all copies of
# the Software and that both the above copyright notice(s) and this
# permission notice appear in supporting documentation.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
# OF THIRD PARTY RIGHTS. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# HOLDERS INCLUDED IN THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL
# INDIRECT OR CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING
# FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
# NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION
# WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
# Except as contained in this notice, the name of a copyright holder
# shall not be used in advertising or otherwise to promote the sale, use
# or other dealings in this Software without prior written authorization
# of the copyright holder.

# TODO
# - Idle mode
# - Async mode
# - Authentications
# - Literals on file mode
# - fix OR in search, and implement time-related searches
# All the rest... see the RFC

# History
#   20100623: G. Reithofer, creating tcl package 0.1, adding some todos
#             option -inline for ::imap4::fetch, in order to return data as a Tcl list
#             isableto without arguments returns the capability list
#             implementation of LIST command
#   20100709: Adding suppport for SSL connections, namespace variable
#             use_ssl must be set to 1 and package TLS must be loaded
#   20100716: Bug in parsing special leading FLAGS characters in FETCH
#             command repaired, documentation cleanup.
#   20121221: Added basic scope, expunge and logout function
#   20130212: Added basic copy function
#   20130212: Missing chan parameter added to all imaptotcl* procs -ger

package require Tcl 8.5
package provide imap4 0.5.3

namespace eval imap4 {
    variable debugmode 0     ;# inside debug mode? usually not.
    variable folderinfo
    variable mboxinfo
    variable msginfo
    variable info

    # if set to 1 tls::socket must be loaded
    variable use_ssl 0
    
    # Debug mode? Don't use it for production! It will print debugging
    # information to standard output and run a special IMAP debug mode shell
    # on protocol error.
    variable debug 0

    # Version
    variable version "2013-02-12"

    # This is where we take state of all the IMAP connections.
    # The following arrays are indexed with the connection channel
    # to access the per-channel information.
    array set folderinfo {}  ;# list of folders.
    array set mboxinfo {}    ;# selected mailbox info.
    array set msginfo {}     ;# messages info.
    array set info {}        ;# general connection state info.

    # Return the next tag to use in IMAP requests.
    proc tag {chan} {
        variable info
        incr info($chan,curtag)
    }

    # Assert that the channel is one of the specified states
    # by the 'states' list.
    # otherwise raise an error.
    proc requirestate {chan states} {
        variable info
        if {[lsearch $states $info($chan,state)] == -1} {
            error "IMAP channel not in one of the following states: '$states' (current state is '$info($chan,state)')"
        }
    }

    # Open a new IMAP connection and initalize the handler.
    proc open {hostname {port 0}} {
        variable info
        variable debug
        variable use_ssl 
        if {$debug} {
            puts "I: open $hostname $port (SSL=$use_ssl)"
        }
        
        if {$use_ssl} {
            if {[info procs ::tls::socket] eq ""} {
                error "Package TLS must be loaded for secure connections."
            }
            if {!$port} {
                set port 993
            }
            set chan [::tls::socket $hostname $port]
        } else {
            if {!$port} {
                set port 143
            }
            set chan [socket $hostname $port]
        }
        fconfigure $chan -encoding binary -translation binary
        # Intialize the connection state array
        initinfo $chan
        # Get the banner
        processline $chan
        # Save the banner
        set info($chan,banner) [lastline $chan]
        return $chan
    }

    # Initialize the info array for a new connection.
    proc initinfo {chan} {
        variable info
        set info($chan,curtag) 0
        set info($chan,state) NOAUTH
        set info($chan,folders) {}
        set info($chan,capability) {}
        set info($chan,raise_on_NO) 1
        set info($chan,raise_on_BAD) 1
        set info($chan,idle) {}
        set info($chan,lastcode) {}
        set info($chan,lastline) {}
        set info($chan,lastrequest) {}
    }

    # Destroy an IMAP connection and free the used space.
    proc cleanup {chan} {
        variable info
        variable folderinfo
        variable mboxinfo
        variable msginfo

        ::close $chan

        array unset folderinfo $chan,*
        array unset mboxinfo $chan,*
        array unset msginfo $chan,*
        array unset info $chan,*

        return $chan
    }

    # STARTTLS
    # This is a new procc added to runs the STARTTLS command.  Use
    # this when tasked with connecting to an unsecure port which must
    # be changed to a secure port prior to user login.  This feature
    # is known as STARTTLS.

    proc starttls {chan} {                                  
	#puts "Starting TLS"                          
	request $chan "STARTTLS"
	if {[getresponse $chan]} {
	    #puts "error sending STARTTLS"
	    return 1
	}
                               
	#puts "TLS import"
	set chan [::tls::import $chan -tls1 1]
	#puts "TLS handshake"
	set chan [::tls::handshake $chan]            
        return 0
    }

    # Returns the last error code received.
    proc lastcode {chan} {
        variable info
        return $info($chan,lastcode)
    }

    # Returns the last line received from the server.
    proc lastline {chan} {
        variable info
        return $info($chan,lastline)
    }

    # Process an IMAP response line.
    # This function trades semplicity in IMAP commands
    # implementation with monolitic handling of responses.
    # However note that the IMAP server can reply to a command
    # with many different untagged info, so to have the reply
    # processing centralized makes this simple to handle.
    #
    # Returns the line's tag.
    proc processline {chan} {
        variable info
        variable debug
        variable mboxinfo
        variable folderinfo

        set literals {}
        while {1} {
            # Read a line
            if {[gets $chan buf] == -1} {
                error "IMAP unexpected EOF from server."
            }

            append line $buf
            # Remove the trailing CR at the end of the line, if any.
            if {[string index $line end] eq "\r"} {
                set line [string range $line 0 end-1]
            }

            # Check if there is a literal to read, and read it if any.
            if {[regexp {{([0-9]+)}\s+$} $buf => length]} {
                # puts "Reading $length bytes of literal..."
                lappend literals [read $chan $length]
            } else {
                break
            }
        }
        set info($chan,lastline) $line

        if {$debug} {
            puts "S: $line"
        }

        # Extract the tag.
        set idx [string first { } $line]
        if {$idx <= 0} {
            protoerror $chan "IMAP: malformed response '$line'"
        }

        set tag [string range $line 0 [expr {$idx-1}]]
        set line [string range $line [expr {$idx+1}] end]
        # If it's just a command continuation response, return.
        if {$tag eq {+}} {return +}

        # Extract the error code, if it's a tagged line
        if {$tag ne "*"} {
            set idx [string first { } $line]
            if {$idx <= 0} {
                protoerror $chan "IMAP: malformed response '$line'"
            }
            set code [string range $line 0 [expr {$idx-1}]]
            set line [string trim [string range $line [expr {$idx+1}] end]]
            set info($chan,lastcode) $code
        }

        # Extract information from the line
        set dirty 0
        switch -glob -- $line {
            {*\[READ-ONLY\]*} {set mboxinfo($chan,perm) READ-ONLY; incr dirty}
            {*\[READ-WRITE\]*} {set mboxinfo($chan,perm) READ-WRITE; incr dirty}
            {*\[TRYCREATE\]*} {set mboxinfo($chan,perm) TRYCREATE; incr dirty}
            {LIST *(*)*} {
                # regexp not secure enough ... delimiters must be PLAIN SPACES (see RFC)
                # set res [regexp {LIST (\(.*\))(!?\s)[ ](.*)$} $line => flags delim fname]
                #    p1|       p2|  p3|
                # LIST (\Noselect) "/" ~/Mail/foo
                set p1 [string first "(" $line]
                set p2 [string first ")" $line [expr {$p1+1}]]
                set p3 [string first " " $line [expr {$p2+2}]]
                if {$p1<0||$p2<0||$p3<0} {
                    protoerror $chan "IMAP: Not a valid RFC822 LIST format in '$line'"
                }
                set flags [string range $line [expr {$p1+1}] [expr {$p2-1}]]
                set delim [string range $line [expr {$p2+2}] [expr {$p3-1}]]
                set fname [string range $line [expr {$p3+1}] end]
                if {$fname eq ""} {
                    set folderinfo($chan,delim) [string trim $delim "\""]
                } else {
                    set fflag {}
                    foreach f [split $flags] {
                        lappend fflag $f
                    }
                    lappend folderinfo($chan,names) $fname
                    lappend folderinfo($chan,flags) [list $fname $fflag]
                    if {$delim ne "NIL"} {
                        set folderinfo($chan,delim) [string trim $delim "\""]
                    }
                }
                incr dirty
            }
            {FLAGS *(*)*} {
                regexp {.*\((.*)\).*} $line => flags
                set mboxinfo($chan,flags) $flags
                incr dirty
            }
            {*\[PERMANENTFLAGS *(*)*\]*} {
                regexp {.*\[PERMANENTFLAGS \((.*)\).*\].*} $line => flags
                set mboxinfo($chan,permflags) $flags
                incr dirty
            }
        }

        if {!$dirty && $tag eq {*}} {
            switch -regexp  -nocase -- $line {
                {^[0-9]+\s+EXISTS} {
                    regexp {^([0-9]+)\s+EXISTS} $line => mboxinfo($chan,exists)
                    incr dirty
                }
                {^[0-9]+\s+RECENT} {
                    regexp {^([0-9]+)\s+RECENT} $line => mboxinfo($chan,recent)
                    incr dirty
                }
                {.*?\[UIDVALIDITY\s+[0-9]+?\]} {
                    regexp {.*?\[UIDVALIDITY\s+([0-9]+?)\]} $line => \
                        mboxinfo($chan,uidval)
                    incr dirty
                }
                {.*?\[UNSEEN\s+[0-9]+?\]} {
                    regexp {.*?\[UNSEEN\s+([0-9]+?)\]} $line => \
                        mboxinfo($chan,unseen)
                    incr dirty
                }
                {.*?\[UIDNEXT\s+[0-9]+?\]} {
                    regexp {.*?\[UIDNEXT\s+([0-9]+?)\]} $line => \
                        mboxinfo($chan,uidnext)
                    incr dirty
                }
                {^[0-9]+\s+FETCH} {
                    processfetchline $chan $line $literals
                    incr dirty
                }
                {^CAPABILITY\s+.*} {
                    regexp {^CAPABILITY\s+(.*)\s*$} $line => capstring
                    set info($chan,capability) [split [string toupper $capstring]]
                    incr dirty
                }
                {^LIST\s*$} {
                    regexp {^([0-9]+)\s+EXISTS} $line => mboxinfo($chan,exists)
                    incr dirty
                }
                {^SEARCH\s*$} {
                    # Search tag without list of messages. Nothing found
                    # so we set an empty list.
                    set mboxinfo($chan,found) {}
                }
                {^SEARCH\s+.*} {
                    regexp {^SEARCH\s+(.*)\s*$} $line => foundlist
                    set mboxinfo($chan,found) $foundlist
                    incr dirty
                }
                default {
                    if {$debug} {
                        puts "*** WARNING: unprocessed server reply '$line'"
                    }
                }
            }
        }

        if {[string length [set info($chan,idle)]] && $dirty} {
            # ... Notify.
        }

        # if debug and no dirty and untagged line... warning: unprocessed IMAP line
        return $tag
    }

    # Process untagged FETCH lines.
    proc processfetchline {chan line literals} {
        variable msginfo
        regexp -nocase {([0-9]+)\s+FETCH\s+(\(.*\))} $line => msgnum items
        foreach {name val} [imaptotcl $chan items literals] {
            set attribname [switch -glob -- [string toupper $name] {
                INTERNALDATE {format internaldate}
                BODYSTRUCTURE {format bodystructure}
                {BODY\[HEADER.FIELDS*\]} {format fields}
                {BODY.PEEK\[HEADER.FIELDS*\]} {format fields}
                {BODY\[*\]} {format body}
                {BODY.PEEK\[*\]} {format body}
                HEADER {format header}
                RFC822.HEADER {format header}
                RFC822.SIZE {format size}
                RFC822.TEXT {format text}
                ENVELOPE {format envelope}
                FLAGS {format flags}
                UID {format uid}
                default {
                    protoerror $chan "IMAP: Unknown FETCH item '$name'. Upgrade the software"
                }
            }]

            switch -- $attribname {
                fields {
                    set last_fieldname __garbage__
                    foreach f [split $val "\n\r"] {
                        # Handle multi-line headers. Append to the last header
                        # if this line starts with a tab character.
                        if {[string is space [string index $f 0]]} {
                            append msginfo($chan,$msgnum,$last_fieldname) " [string range $f 1 end]"
                            continue
                        }
                        # Process the line searching for a new field.
                        if {![string length $f]} continue
                        if {[set fnameidx [string first ":" $f]] == -1} {
                            protoerror $chan "IMAP: Not a valid RFC822 field '$f'"
                        }
                        set fieldname [string tolower [string range $f 0 $fnameidx]]
                        set last_fieldname $fieldname
                        set fieldval [string trim \
                            [string range $f [expr {$fnameidx+1}] end]]
                        set msginfo($chan,$msgnum,$fieldname) $fieldval
                    }
                }
                default {
                    set msginfo($chan,$msgnum,$attribname) $val
                }
            }
            #puts "$attribname -> [string range $val 0 20]"
        }
        # parray msginfo
    }

    # Convert IMAP data into Tcl data. Consumes the part of the
    # string converted.
    # 'literals' is a list with all the literals extracted
    # from the original line, in the same order they appeared.
    proc imaptotcl {chan datavar literalsvar} {
        upvar 1 $datavar data $literalsvar literals
        set data [string trim $data]
        switch -- [string index $data 0] {
            \{ {imaptotcl_literal $chan data literals}
            "(" {imaptotcl_list $chan data literals}
            "\"" {imaptotcl_quoted $chan data}
            0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 - 8 - 9 {imaptotcl_number $chan data}
            \) {imaptotcl_endlist $chan data;# that's a trick to parse lists}
            default {imaptotcl_symbol $chan data}
        }
    }

    # Extract a literal
    proc imaptotcl_literal {chan datavar literalsvar} {
        upvar 1 $datavar data $literalsvar literals
        if {![regexp {{.*?}} $data match]} {
            protoerror $chan "IMAP data format error: '$data'"
        }
        set data [string range $data [string length $match] end]
        set retval [lindex $literals 0]
        set literals [lrange $literals 1 end]
        return $retval
    }

    # Extract a quoted string
    proc imaptotcl_quoted {chan datavar} {
        upvar 1 $datavar data
        if {![regexp "\\s*?(\".*?\[^\\\\\]\"|\"\")\\s*?" $data => match]} {
            protoerror $chan "IMAP data format error: '$data'"
        }
        set data [string range $data [string length $match] end]
        return [string range $match 1 end-1]
    }

    # Extract a number
    proc imaptotcl_number {chan datavar} {
        upvar 1 $datavar data
        if {![regexp {^[0-9]+} $data match]} {
            protoerror $chan "IMAP data format error: '$data'"
        }
        set data [string range $data [string length $match] end]
        return $match
    }

    # Extract a "symbol". Not really exists in IMAP, but there
    # are named items, and this names have a strange unquoted
    # syntax like BODY[HEAEDER.FIELD (From To)] and other stuff
    # like that.
    proc imaptotcl_symbol {chan datavar} {
        upvar 1 $datavar data
        # matching patterns: "BODY[HEAEDER.FIELD",
        # "HEAEDER.FIELD", "\Answered", "$Forwarded"
        set pattern {([\w\.]+\[[^\[]+\]|[\w\.]+|[\\\$]\w+)}
        if {![regexp $pattern $data => match]} {
            protoerror $chan "IMAP data format error: '$data'"
        }
        set data [string range $data [string length $match] end]
        return $match
    }

    # Extract an IMAP list.
    proc imaptotcl_list {chan datavar literalsvar} {
        upvar 1 $datavar data $literalsvar literals
        set list {}
        # Remove the first '(' char
        set data [string range $data 1 end]
        # Get all the elements of the list. May indirectly recurse called
        # by [imaptotcl].
        while {[string length $data]} {
            set ele [imaptotcl $chan data literals]
            if {$ele eq {)}} {
                break
            }
            lappend list $ele
        }
        return $list
    }

    # Just extracts the ")" character alone.
    # This is actually part of the list extraction work.
    proc imaptotcl_endlist {chan datavar} {
        upvar 1 $datavar data
        set data [string range $data 1 end]
        return ")"
    }

    # Process IMAP responses. If the IMAP channel is not
    # configured to raise errors on IMAP errors, returns 0
    # on OK response, otherwise 1 is returned.
    proc getresponse {chan} {
        variable info

        # Process lines until the tagged one.
        while {[set tag [processline $chan]] eq {*} || $tag eq {+}} {}
        switch -- [lastcode $chan] {
            OK {return 0}
            NO {
                if {$info($chan,raise_on_NO)} {
                    error "IMAP error: [lastline $chan]"
                }
                return 1
            }
            BAD {
                if {$info($chan,raise_on_BAD)} {
                    protoerror $chan "IMAP error: [lastline $chan]"
                }
                return 1
            }
            default {
                protoerror $chan "IMAP protocol error. Unknown response code '[lastcode $chan]'"
            }
        }
    }

    # Write a request.
    proc request {chan request} {
        variable debug
        variable info

        set t "[tag $chan] [string trim $request]"
        if {$debug} {
            puts "C: $t"
        }
        set info($chan,lastrequest) $t
        puts -nonewline $chan "$t\r\n"
        flush $chan
    }

    # Write a multiline request. The 'request' list must contain
    # parts of command and literals interleaved. Literals are ad odd
    # list positions (1, 3, ...).
    proc multiline_request {chan request} {
        variable debug
        variable info

        lset request 0 "[tag $chan][lindex $request 0]"
        set items [llength $request]
        foreach {line literal} $request {
            # Send the line
            if {$debug} {
                puts "C: $line"
            }
            puts -nonewline $chan "$line\r\n"
            flush $chan
            incr items -1
            if {!$items} break

            # Wait for the command continuation response
            if {[processline $chan] ne {+}} {
                protoerror $chan "Expected a command continuation response but got '[lastline $chan]'"
            }

            # Send the literal
            if {$debug} {
                puts "C> $literal"
            }
            puts -nonewline $chan $literal
            flush $chan
            incr items -1
        }
        set info($chan,lastrequest) $request
    }

    # Login using the IMAP LOGIN command.
    proc login {chan user pass} {
        variable info

        requirestate $chan NOAUTH
        request $chan "LOGIN $user $pass"
        if {[getresponse $chan]} {
            return 1
        }
        set info($chan,state) AUTH
        return 0
    }

    # Mailbox selection.
    proc select {chan {mailbox INBOX}} {
        selectmbox $chan SELECT $mailbox
    }

    # Read-only equivalent of SELECT.
    proc examine {chan {mailbox INBOX}} {
        selectmbox $chan EXAMINE $mailbox
    }

    # General function for selection.
    proc selectmbox {chan cmd mailbox} {
        variable info
        variable mboxinfo

        requirestate $chan AUTH
        # Clean info about the previous mailbox if any,
        # but save a copy to restore this info on error.
        set savedmboxinfo [array get mboxinfo $chan,*]
        array unset mboxinfo $chan,*
        request $chan "$cmd $mailbox"
        if {[getresponse $chan]} {
            array set mboxinfo $savedmboxinfo
            return 1
        }

        set info($chan,state) SELECT
        # Set the new name as mbox->current.
        set mboxinfo($chan,current) $mailbox
        return 0
    }

    # Parse an IMAP range, store 'start' and 'end' in the
    # named vars. If the first number of the range is omitted,
    # 1 is assumed. If the second number of the range is omitted,
    # the value of "exists" of the current mailbox is assumed.
    #
    # So : means all the messages.
    proc parserange {chan range startvar endvar} {

        upvar $startvar start $endvar end
        set rangelist [split $range :]
        switch -- [llength $rangelist] {
            1 {
                if {![string is integer $range]} {
                    error "Invalid range"
                }
                set start $range
                set end $range
            }
            2 {
                foreach {start end} $rangelist break
                if {![string length $start]} {
                    set start 1
                }
                if {![string length $end]} {
                    set end [mboxinfo $chan exists]
                }
                if {![string is integer $start] || ![string is integer $end]} {
                    error "Invalid range"
                }
            }
            default {
                error "Invalid range"
            }
        }
    }

    # Fetch a number of attributes from messages
    proc fetch {chan range opt args} {
        if {$opt eq "-inline"} {
            set inline 1
        } else {
            set inline 0
            set args [linsert $args 0 $opt]
        }
        requirestate $chan SELECT
        parserange $chan $range start end

        set items {}
        set hdrfields {}
        foreach w $args {
            switch -glob -- [string toupper $w] {
                ALL {lappend items ALL}
                BODYSTRUCTURE {lappend items BODYSTRUCTURE}
                ENVELOPE {lappend items ENVELOPE}
                FLAGS {lappend items FLAGS}
                SIZE {lappend items RFC822.SIZE}
                TEXT {lappend items RFC822.TEXT}
                HEADER {lappend items RFC822.HEADER}
                UID {lappend items UID}
                *: {lappend hdrfields $w}
                default {
                    # Fixme: better to raise an error here?
                    lappend hdrfields $w:
                }
            }
        }

        if {[llength $hdrfields]} {
            set item {BODY[HEADER.FIELDS (}
            foreach field $hdrfields {
                append item [string toupper [string range $field 0 end-1]] { }
            }
            set item [string range $item 0 end-1]
            append item {)]}
            lappend items $item
        }

        # Send the request
        request $chan "FETCH $start:$end ([join $items])"
        if {[getresponse $chan]} {
            if {$inline} {
                # Should we throw an error here?
                return ""
            }
            return 1
        }

        if {!$inline} {
            return 0
        }

        # -inline procesing begins here
        set mailinfo {}
        for {set i $start} {$i <= $end} {incr i} {
            set mailrec {}
            foreach {h} $args {
                lappend mailrec [msginfo $chan $i $h ""]
            }
            lappend mailinfo $mailrec
        }
        return $mailinfo
    }

    # Get information (previously collected using fetch) from a given message.
    # If the 'info' argument is omitted or a null string, the full list
    # of information available for the given message is returned.
    #
    # If the required information name is suffixed with a ? character,
    # the command requires true if the information is available, or
    # false if it is not.
    proc msginfo {chan msgid args} {
        variable msginfo

        switch -- [llength $args] {
            0 {
                set info {}
            }
            1 {
                set info [lindex $args 0]
                set use_defval 0
            }
            2 {
                set info [lindex $args 0]
                set defval [lindex $args 1]
                set use_defval 1
            }
            default {
                error "msginfo called with bad number of arguments! Try msginfo channel messageid ?info? ?defaultvalue?"
            }
        }
        set info [string tolower $info]
        # Handle the missing info case
        if {![string length $info]} {
            set list [array names msginfo $chan,$msgid,*]
            set availinfo {}
            foreach l $list {
                lappend availinfo [string range $l \
                    [string length $chan,$msgid,] end]
            }
            return $availinfo
        }

        if {[string index $info end] eq {?}} {
            set info [string range $info 0 end-1]
            return [info exists msginfo($chan,$msgid,$info)]
        } else {
            if {![info exists msginfo($chan,$msgid,$info)]} {
                if {$use_defval} {
                    return $defval
                } else {
                    error "No such information '$info' available for message id '$msgid'"
                }
            }
            return $msginfo($chan,$msgid,$info)
        }
    }

    # Get information on the currently selected mailbox.
    # If the 'info' argument is omitted or a null string, the full list
    # of information available for the mailbox is returned.
    #
    # If the required information name is suffixed with a ? character,
    # the command requires true if the information is available, or
    # false if it is not.
    proc mboxinfo {chan {info {}}} {
        variable mboxinfo

        # Handle the missing info case
        if {![string length $info]} {
            set list [array names mboxinfo $chan,*]
            set availinfo {}
            foreach l $list {
                lappend availinfo [string range $l \
                    [string length $chan,] end]
            }
            return $availinfo
        }

        set info [string tolower $info]
        if {[string index $info end] eq {?}} {
            set info [string range $info 0 end-1]
            return [info exists mboxinfo($chan,$info)]
        } else {
            if {![info exists mboxinfo($chan,$info)]} {
                error "No such information '$info' available for the current mailbox"
            }
            return $mboxinfo($chan,$info)
        }
    }

    # Get information on the last folders list.
    # If the 'info' argument is omitted or a null string, the full list
    # of information available for the folders is returned.
    #
    # If the required information name is suffixed with a ? character,
    # the command requires true if the information is available, or
    # false if it is not.
    proc folderinfo {chan {info {}}} {
        variable folderinfo

        # Handle the missing info case
        if {![string length $info]} {
            set list [array names folderinfo $chan,*]
            set availinfo {}
            foreach l $list {
                lappend availinfo [string range $l \
                        [string length $chan,] end]
            }
            return $availinfo
        }

        set info [string tolower $info]
        if {[string index $info end] eq {?}} {
            set info [string range $info 0 end-1]
            return [info exists folderinfo($chan,$info)]
        } else {
            if {![info exists folderinfo($chan,$info)]} {
                error "No such information '$info' available for the current folders"
            }
            return $folderinfo($chan,$info)
        }
    }


    # Get capabilties
    proc capability {chan} {
        request $chan "CAPABILITY"
        if {[getresponse $chan]} {
            return 1
        }
        return 0
    }

    # Get the current state
    proc state {chan} {
        variable info
        return $info($chan,state)
    }

    # Test for capability. Use the capability command
    # to ask the server if not already done by the user.
    proc isableto {chan {capa ""}} {
        variable info

	set result 0
        if {![llength $info($chan,capability)]} {
            set result [capability $chan]
        }

        if {$capa eq ""} {
            if {$result} {
               # We return empty string on error
               return ""
            }
            return $info($chan,capability)
        }

        set capa [string toupper $capa]
        expr {[lsearch -exact $info($chan,capability) $capa] != -1}
    }

    # NOOP command. May get information as untagged data.
    proc noop {chan} {
        simplecmd $chan NOOP {NOAUTH AUTH SELECT} {}
    }

    # CHECK. Flush to disk.
    proc check {chan} {
        simplecmd $chan CHECK SELECT {}
    }

    # Close the mailbox. Permanently removes \Deleted messages and return to
    # the AUTH state.
    proc close {chan} {
        variable info

        if {[simplecmd $chan CLOSE SELECT {}]} {
            return 1
        }

        set info($chan,state) AUTH
        return 0
    }

    # Create a new mailbox.
    proc create {chan mailbox} {
        simplecmd $chan CREATE {AUTH SELECT} $mailbox
    }

    # Delete a mailbox
    proc delete {chan mailbox} {
        simplecmd $chan DELETE {AUTH SELECT} $mailbox
    }

    # Rename a mailbox
    proc rename {chan oldname newname} {
        simplecmd $chan RENAME {AUTH SELECT} $oldname $newname
    }

    # Subscribe to a mailbox
    proc subscribe {chan mailbox} {
        simplecmd $chan SUBSCRIBE {AUTH SELECT} $mailbox
    }

    # Unsubscribe to a mailbox
    proc unsubscribe {chan mailbox} {
        simplecmd $chan UNSUBSCRIBE {AUTH SELECT} $mailbox
    }

    # List of folders
    proc folders {chan {opt ""} {ref ""} {mbox "*"}} {
        variable folderinfo
        array unset folderinfo $chan,*

        if {$opt eq "-inline"} {
            set inline 1
        } else {
            set ref $opt
            set mbox $ref
            set inline 0
        }

        set folderinfo($chan,match) [list $ref $mbox]
        # parray folderinfo
        set rv [simplecmd $chan LIST {SELECT AUTH} \"$ref\" \"$mbox\"]
        if {$inline} {
            set rv {}
            foreach f [folderinfo $chan flags] {
                set lflags {}
                foreach fl [lindex $f 1] {
                    if {[string is alnum [string index $fl 0]]} {
                        lappend lflags [string tolower $fl]
                    } else {
                        lappend lflags [string tolower [string range $fl 1 end]]
                    }
                }
                lappend rv [list [lindex $f 0] $lflags]
            }
        }
        # parray folderinfo
        return $rv
    }

    # This a general implementation for a simple implementation
    # of an IMAP command that just requires to call ::imap4::request
    # and ::imap4::getresponse.
    proc simplecmd {chan command validstates args} {
        requirestate $chan $validstates

        set req "$command"
        foreach arg $args {
            append req " $arg"
        }

        request $chan $req
        if {[getresponse $chan]} {
            return 1
        }

        return 0
    }

    # Search command.
    proc search {chan args} {
        if {![llength $args]} {
            error "missing arguments. Usage: search chan arg ?arg ...?"
        }

        requirestate $chan SELECT
        set imapexpr [convert_search_expr $args]
        multiline_prefix_command imapexpr "SEARCH"
        multiline_request $chan $imapexpr
        if {[getresponse $chan]} {
            return 1
        }

        return 0
    }

    # Creates an IMAP octect-count.
    # Used to send literals.
    proc literalcount {string} {
        return "{[string length $string]}"
    }

    # Append a command part to a multiline request
    proc multiline_append_command {reqvar cmd} {
        upvar 1 $reqvar req

        if {[llength $req] == 0} {
            lappend req {}
        }

        lset req end "[lindex $req end] $cmd"
    }

    # Append a literal to a multiline request. Uses a quoted
    # string in simple cases.
    proc multiline_append_literal {reqvar lit} {
        upvar 1 $reqvar req

        if {![string is alnum $lit]} {
            lset req end "[lindex $req end] [literalcount $lit]"
            lappend req $lit {}
        } else {
            multiline_append_command req "\"$lit\""
        }
    }

    # Prefix a multiline request with a command.
    proc multiline_prefix_command {reqvar cmd} {
        upvar 1 $reqvar req

        if {![llength $req]} {
            lappend req {}
        }

        lset req 0 " $cmd[lindex $req 0]"
    }

    # Concat an already created search expression to a multiline request.
    proc multiline_concat_expr {reqvar expr} {
        upvar 1 $reqvar req
        lset req end "[lindex $req end] ([string range [lindex $expr 0] 1 end]"
        set req [concat $req [lrange $expr 1 end]]
        lset req end "[lindex $req end])"
    }

    # Helper for the search command. Convert a programmer friendly expression
    # (actually a tcl list) to the IMAP syntax. Returns a list composed of
    # request, literal, request, literal, ... (to be sent with
    # ::imap4::multiline_request).
    proc convert_search_expr {expr} {
        set result {}

        while {[llength $expr]} {
            switch -glob -- [string toupper [set token [lpop expr]]] {
                *: {
                    set wanted [lpop expr]
                    multiline_append_command result "HEADER [string range $token 0 end-1]"
                    multiline_append_literal result $wanted
                }

                ANSWERED - DELETED - DRAFT - FLAGGED - RECENT -
                SEEN - NEW - OLD - UNANSWERED - UNDELETED -
                UNDRAFT - UNFLAGGED - UNSEEN -
                ALL {multiline_append_command result [string toupper $token]}

                BODY - CC - FROM - SUBJECT - TEXT - KEYWORD -
                BCC {
                    set wanted [lpop expr]
                    multiline_append_command result "$token"
                    multiline_append_literal result $wanted
                }

                OR {
                    set first [convert_search_expr [lpop expr]]
                    set second [convert_search_expr [lpop expr]]
                    multiline_append_command result "OR"
                    multiline_concat_expr result $first
                    multiline_concat_expr result $second
                }

                NOT {
                    set e [convert_search_expr [lpop expr]]
                    multiline_append_command result "NOT"
                    multiline_concat_expr result $e
                }

                SMALLER -
                LARGER {
                    set len [lpop expr]
                    if {![string is integer $len]} {
                        error "Invalid integer follows '$token' in IMAP search"
                    }
                    multiline_append_command result "$token $len"
                }

                ON - SENTBEFORE - SENTON - SENTSINCE - SINCE -
                BEFORE {error "TODO"}

                UID {error "TODO"}
                default {
                    error "Syntax error in search expression: '... $token $expr'"
                }
            }
        }
        return $result
    }

    # Pop an element from the list inside the named variable and return it.
    # If a list is empty, raise an error. The error is specific for the
    # search command since it's the only one calling this function.
    proc lpop {listvar} {
        upvar 1 $listvar l

        if {![llength $l]} {
            error "Bad syntax for search expression (missing argument)"
        }

        set res [lindex $l 0]
        set l [lrange $l 1 end]
        return $res
    }

    # Debug mode.
    # This is a developers mode only that pass the control to the
    # programmer. Every line entered is sent verbatim to the
    # server (after the addition of the request identifier).
    # The ::imap4::debug variable is automatically set to '1' on enter.
    #
    # It's possible to execute Tcl commands starting the line
    # with a slash.

    proc debugmode {chan {errormsg {None}}} {
        variable debugmode 1
        variable debugchan $chan
        variable version
        variable folderinfo
        variable mboxinfo
        variable msginfo
        variable info

        set welcometext [list \
                "------------------------ IMAP DEBUG MODE --------------------" \
                "IMAP Debug mode usage: Every line typed will be sent" \
                "verbatim to the IMAP server prefixed with a unique IMAP tag." \
                "To execute Tcl commands prefix the line with a / character." \
                "The current debugged channel is returned by the \[me\] command." \
                "Type ! to exit" \
                "Type 'info' to see information about the connection" \
                "Type 'help' to display this information" \
                "" \
                "Last error: '$errormsg'" \
                "IMAP library version: '$version'" \
                "" \
        ]
        foreach l $welcometext {
            puts $l
        }

        debugmode_info $chan
        while 1 {
            puts -nonewline "imap debug> "
            flush stdout
            gets stdin line
            if {![string length $line]} continue
            if {$line eq {!}} exit
            if {$line eq {info}} {
                debugmode_info $chan
                continue
            }
            if {$line eq {help}} {
                foreach l $welcometext {
                    if {$l eq ""} break
                    puts $l
                }
                continue
            }
            if {[string index $line 0] eq {/}} {
                catch {eval [string range $line 1 end]} result
                puts $result
                continue
            }
            # Let's send the request to imap server
            request $chan $line
            if {[catch {getresponse $chan} error]} {
                puts "--- ERROR ---\n$error\n-------------\n"
            }
         }
    }

    # Little helper for debugmode command.
    proc debugmode_info {chan} {
        variable info
        puts "Last sent request: '$info($chan,lastrequest)'"
        puts "Last received line: '$info($chan,lastline)'"
        puts ""
    }

    # Protocol error! Enter the debug mode if ::imap4::debug is true.
    # Otherwise just raise the error.
    proc protoerror {chan msg} {
        variable debug
        variable debugmode

        if {$debug && !$debugmode} {
            debugmode $chan $msg
        } else {
            error $msg
        }
    }

    proc me {} {
        variable debugchan
        set debugchan
    }

    # Other stuff to do in random order...
    #
    # proc ::imap4::idle notify-command
    # proc ::imap4::auth plain ...
    # proc ::imap4::securestauth user pass
    # proc ::imap4::store
    # proc ::imap4::logout (need to clean both msg and mailbox info arrays)

    # Amend the flags of a message to be updated once CLOSE/EXPUNGE is initiated
    proc store {chan range key values} {
	set valid_keys {
	    FLAGS
	    FLAGS.SILENT
	    +FLAGS
	    +FLAGS.SILENT
	    -FLAGS
	    -FLAGS.SILENT
	}
	if {$key ni $valid_keys} {
	    error "Invalid data item: $key. Must be one of [join $valid_keys ,]"
	}
        parserange $chan $range start end
	set newflags {}
	foreach val $values {
	    if {[regexp {^\\+(.*?)$} $val]} {
		lappend newflags $values
	    } else {
		lappend newflags "\\$val"
	    }
	}
        request $chan "STORE $start:$end $key ([join $newflags])"
	if {[getresponse $chan]} {
	    return 1
	}
	return 0
    }

    # Logout
    proc logout {chan} {
	if {[simplecmd $chan LOGOUT SELECT {}]} {
	    # clean out info arrays
	    variable info
	    variable folderinfo
	    variable mboxinfo
	    variable msginfo

	    array unset folderinfo $chan,*
	    array unset mboxinfo $chan,*
	    array unset msginfo $chan,*
	    array unset info $chan,*

	    return 1
	}
        return 0
    }

    # Expunge : force removal of any messages with the 
    # flag \Deleted
    proc expunge {chan} {
        if {[simplecmd $chan EXPUNGE SELECT {}]} {
            return 1
        }
        return 0
    }

    # copy : copy a message to a destination mailbox
    proc copy {chan msgid mailbox} {
	if {[simplecmd $chan COPY SELECT [list $msgid $mailbox]]} {
	    return 1
	}
	return 0
    }

}

################################################################################
# Example and test
################################################################################
if {[info script] eq $argv0} {
    # set imap4::debug 0
    set FOLDER INBOX
    set port 0
    if {[llength $argv] < 3} {
        puts "Usage: imap4.tcl <server> <user> <pass> ?folder? ?-secure? ?-debug?"
        exit
    }

    lassign $argv server user pass
    if {$argc > 3} {
        for {set i 3} {$i<$argc} {incr i} {
            set opt [lindex $argv $i]
            switch -- $opt {
                "-debug" {
                    set imap4::debug 1
                }
                "-secure" {
                    set imap4::use_ssl 1
                    puts "Package TLS [package require tls] loaded"
                }
                default {
                    set FOLDER $opt
                }
            }
        }
    }

    # open and login ...
    set imap [imap4::open $server]
    imap4::login $imap $user $pass

    imap4::select $imap $FOLDER
    # Output all the information about that mailbox
    foreach info [imap4::mboxinfo $imap] {
        puts "$info -> [imap4::mboxinfo $imap $info]"
    }
    set num_mails [imap4::mboxinfo $imap exists]
    if {!$num_mails} {
        puts "No mail in folder '$FOLDER'"
    } else {      
        set fields {from: to: subject: size}
        # fetch 3 records (at most)) inline
        set max [expr {$num_mails<=3?$num_mails:3}]
        foreach rec [imap4::fetch $imap :$max -inline {*}$fields] {
            puts -nonewline "#[incr idx])"
            for {set j 0} {$j<[llength $fields]} {incr j} {
                puts "\t[lindex $fields $j] [lindex $rec $j]"
            }
        }
    
        # Show all the information available about the message ID 1
        puts "Available info about message 1 => [imap4::msginfo $imap 1]"
    }
    
    # Use the capability stuff
    puts "Capabilities: [imap4::isableto $imap]"
    puts "Is able to imap4rev1? [imap4::isableto $imap imap4rev1]"
    if {$imap4::debug} {
        imap4::debugmode $imap
    }

    # Cleanup
    imap4::cleanup $imap
}
