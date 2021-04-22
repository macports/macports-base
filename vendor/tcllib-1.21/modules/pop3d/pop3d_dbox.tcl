# -*- tcl -*-
# pop3d_dbox.tcl --
#
#	Implementation of a simple mailbox database for the pop3 server
#       Each mailbox is a a directory in a base directory, with each mail
#	a file in that directory. The mail file contains both headers and
#	body of the mail.
#
# Copyright (c) 2002 by Andreas Kupries
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require mime ; # tcllib | mime token is result of "get".
package require log  ; # tcllib | Logging package

namespace eval ::pop3d::dbox {
    # Data storage in the pop3d::dbox module
    # -------------------------------------
    # One array per object containing the db contents. Keyed by user name.
    # And the information about the last file data was read from.

    # counter is used to give a unique name for unnamed databases
    variable counter 0

    # commands is the list of subcommands recognized by the server
    variable commands [list	\
	    "add"	\
	    "base"	\
	    "dele"	\
	    "destroy"   \
	    "exists"	\
	    "get"	\
	    "list"	\
	    "lock"	\
	    "locked"	\
	    "move"	\
	    "remove"	\
	    "size"	\
	    "stat"	\
	    "unlock"	\
	    ]
}


# ::pop3d::dbox::new --
#
#	Create a new mailbox database with a given name;
#	if no name is given, use
#	p3dboxX, where X is a number.
#
# Arguments:
#	name	name of the mailbox database; if null, generate one.
#
# Results:
#	name	name of the mailbox database created

proc ::pop3d::dbox::new {{name ""}} {
    variable counter
    
    if { [llength [info level 0]] == 1 } {
	incr counter
	set name "p3dbox${counter}"
    }

    if { ![string equal [info commands ::$name] ""] } {
	return -code error \
		"command \"$name\" already exists,\
		unable to create mailbox database"
    }

    # Set up the namespace
    namespace eval ::pop3d::dbox::dbox::$name {
	variable dir ""
	variable state    ; array set state  {}
	variable locked   ; array set locked {}
	variable transfer ; array set transfer {}
    }

    # Create the command to manipulate the mailbox database
    interp alias {} ::$name {} ::pop3d::dbox::DboxProc $name

    return $name
}

##########################
# Private functions follow

# ::pop3d::dbox::DboxProc --
#
#	Command that processes all mailbox database object commands.
#
# Arguments:
#	name	name of the mailbox database object to manipulate.
#	args	command name and args for the command
#
# Results:
#	Varies based on command to perform

proc ::pop3d::dbox::DboxProc {name {cmd ""} args} {

    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	return -code error \
		"wrong # args: should be \"$name option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    if { [llength [info commands ::pop3d::dbox::_$cmd]] == 0 } {
	variable commands
	set optlist [join $commands ", "]
	set optlist [linsert $optlist "end-1" "or"]
	return -code error "bad option \"$cmd\": must be $optlist"
    }
    eval [list ::pop3d::dbox::_$cmd $name] $args
}


proc ::pop3d::dbox::_base {name base} {
    # @c Constructor. Does some more checks on the given base directory.

    # sanity checks
    if {$base == {}} {
	return -code error "directory not specified"
    }
    if {! [file exists      $base]} {
	return -code error "base: \"$base\" does not exist"
    }
    if {! [file isdirectory $base]} {
	return -code error "base: \"$base\" not a directory"
    }
    if {! [file readable    $base]} {
	return -code error "base: \"$base\" not readable"
    }
    if {! [file writable    $base]} {
	return -code error "base: \"$base\" not writable"
    }

    upvar ::pop3d::dbox::dbox::${name}::dir dir
    set dir $base
    return
}


# ::pop3d::dbox::_destroy --
#
#	Destroy a mail database, including its associated command and
#	data storage.
#
# Arguments:
#	name	Name of the database to destroy.
#
# Results:
#	None.

proc ::pop3d::dbox::_destroy {name} {
    namespace delete ::pop3d::dbox::dbox::$name
    interp alias {} ::$name {}
    return
}

proc ::pop3d::dbox::_add {name mbox} {
    # @c Create a mailbox with handle <a mbox>. The handle is used as the
    # @c name of the directory to contain the mails too.
    #
    # @a mbox: Reference to the mailbox to be operated on.

    set dir      [CheckDir $name]
    set mboxpath [file join $dir $mbox]

    if {[file exists $mboxpath]} {
	return -code error "cannot add \"$mbox\", mailbox already in existence"
    }

    file mkdir $mboxpath
    return
}


proc ::pop3d::dbox::_remove {name mbox} {
    # @c Remove mailbox with handle <a mbox>. This will destroy all mails
    # @c contained in it too.
    #
    # @a mbox: Reference to the mailbox to be operated on.

    set dir      [CheckDir $name]
    set mboxpath [file join $dir $mbox]

    if {![file exists $mboxpath]} {
	return -code error "cannot remove \"$mbox\", mailbox does not exist"
    }

    if {[_locked $name $mbox]} {
	return -code error "cannot remove \"$mbox\", mailbox is locked"
    }

    file delete -force $mboxpath
    return
}


proc ::pop3d::dbox::_move {name old new} {
    # @c Change the handle of mailbox <a old> to <a new>.
    #
    # @a old: Reference to the mailbox to be operated on.
    # @a new: New reference to the mailbox

    set dir     [CheckDir $name]
    set oldpath [file join $dir $old]
    set newpath [file join $dir $new]

    if {![file exists $oldpath]} {
	return -code error "cannot move \"$old\", mailbox does not exist"
    }
    if {[file exists $newpath]} {
	return -code error \
		"cannot move \"$old\", destination \"$new\" already exists"
    }

    file rename -force $oldpath $newpath
    return
}


proc ::pop3d::dbox::_list {name} {
    # @c Lists known mailboxes in object.
    # @r List of mailbox names.

    set dir  [CheckDir $name]
    set here [pwd]
    cd $dir
    set files [glob -nocomplain *]
    cd $here

    set res [list]
    foreach f $files {
	set mboxpath [file join $dir $f]
	if {! [file isdirectory $mboxpath]} {continue}
	if {! [file readable    $mboxpath]} {continue}
	if {! [file writable    $mboxpath]} {continue}
	lappend res $f
    }
    return $res
}


proc ::pop3d::dbox::_exists {name mbox} {
    # @c Determines existence of mailbox <a mbox>.
    # @a mbox: Reference to the mailbox to check for.
    # @r 1 if the mailbox exists, 0 else.

    set dir  [CheckDir $name]
    set mbox [file join $dir $mbox]
    return   [file exists    $mbox]
}


proc ::pop3d::dbox::_locked {name mbox} {
    # @c Checks wether the specified mailbox is locked or not.
    # @a mbox: Reference to the mailbox to check.
    # @r 1 if the mailbox is locked, 0 else.

    set     dir  [CheckDir $name]
    set     mbox [file join $dir $mbox]

    upvar ::pop3d::dbox::dbox::${name}::locked locked

    return [::info exists locked($mbox)]
}


# -- interface to the pop server (storage callback) --

proc ::pop3d::dbox::_lock {name mbox} {
    # @c Locks the given mailbox, additionally stores a list of the
    # @c available files in the manager state. All files (= messages)
    # @c added to the mailbox after this operation will be ignored
    # @c during the session.
    #
    # @a mbox: Reference to the mailbox to be locked.
    # @r 1 if mailbox was locked sucessfully, 0 else.

    # locked already ?
    if {[_locked $name $mbox]} {
	return 0
    }

    set dir [Check $name $mbox]

    # Compute a list of message files residing in the mailbox directory

    upvar ::pop3d::dbox::dbox::${name}::state  state
    upvar ::pop3d::dbox::dbox::${name}::locked locked

    set  state($dir)  [lsort [glob -nocomplain [file join $dir *]]]
    set locked($dir) 1
    return 1
}


proc ::pop3d::dbox::_unlock {name mbox} {
    # @c A locked mailbox is unlocked, thereby made available
    # @c to other sessions.
    #
    # @a mbox: Reference to the mailbox to be locked.

    # not locked ?
    if {![_locked $name $mbox]} {return}
    set dir [Check $name $mbox]

    upvar ::pop3d::dbox::dbox::${name}::state  state
    upvar ::pop3d::dbox::dbox::${name}::locked locked

    unset   state($dir)
    unset  locked($dir)
    return
}


proc ::pop3d::dbox::_stat {name mbox} {
    # @c Determines the number of messages picked up by <m lock>.
    # @c Will fail if the mailbox was not locked.
    #
    # @a mbox: Reference to the mailbox queried.
    # @r The number of messages in the mailbox

    set dir [Check $name $mbox]

    if {![_locked $name $mbox]} {
	return -code error "mailbox \"$mbox\" is not locked"
    }

    upvar ::pop3d::dbox::dbox::${name}::state  state

    return  [llength $state($dir)]
}


proc ::pop3d::dbox::_size {name mbox {msgId {}}} {
    # @c Determines the size of the specified message, in bytes.
    #
    # @a mbox: Reference to the mailbox to be operated on.
    # @a msgId: Numerical index of the message to look at.
    # @r size of the message in bytes.

    log::log debug "$name size $mbox ($msgId)"

    set dir [Check $name $mbox]

    log::log debug "$name mbox dir = $dir"

    upvar ::pop3d::dbox::dbox::${name}::state  state

    if {$msgId == {}} {
	log::log debug "$name size /full"

	# Full size of the maildrop requested.
	if {![info exists state($dir)]} {
	    # No stat before size, assume that there are no messages
	    # in the maildrop, which implies that the maildrop is
	    # empty, i.e. of size 0.
	    return 0
	}

	set n 0
	set k [llength $state($dir)]
	for {set id 0} {$id < $k} {incr id} {
	    incr n [file size [lindex $state($dir) $id]]
	}
	return $n
    }

    if {
	($msgId < 1) ||
	(![info exists state($dir)]) ||
	([llength $state($dir)] < $msgId)
    } {
	return -code error "id \"$msgId\" out of range"
    }
    incr msgId -1

    ## log::log debug "$name msg mails = $state($dir)"
    log::log debug "$name msg file = [lindex $state($dir) $msgId]"

    return [file size [lindex $state($dir) $msgId]]
}


proc ::pop3d::dbox::_dele {name mbox msgList} {
    # @c Deletes the specified messages from the mailbox. This should
    # @c be followed by a <m unlock> as the state is not updated
    # @c accordingly.
    #
    # @a mbox: Reference to the mailbox to be operated on.
    # @a msgList: List of message ids.

    set dir [Check $name $mbox]
    if {[llength $msgList] == 0} {
	return -code error "nothing to delete"
    }

    # @d The code assumes that the id's in the list were already
    # @d checked against the maximal number of messages.

    upvar ::pop3d::dbox::dbox::${name}::state  state

    foreach msgId $msgList {
	if {
	    ($msgId < 1) ||
	    (![info exists state($dir)]) ||
	    ([llength $state($dir)] < $msgId)
	} {
	    return -code error "id \"$msgId\" out of range"
	}
    }
    foreach msgId $msgList {
	file delete [lindex $state($dir) [incr msgId -1]]
    }

    # the mailbox state is unusable now.
    return
}

proc ::pop3d::dbox::_get {name mbox msgId} {
    set dir [Check $name $mbox]

    upvar ::pop3d::dbox::dbox::${name}::state  state

    if {
	($msgId < 1) ||
	(![info exists state($dir)]) ||
	([llength $state($dir)] < $msgId)
    } {
	return -code error "id \"$msgId\" out of range"
    }
    incr msgId -1

    set mailfile [lindex $state($dir) $msgId]

    set token [::mime::initialize -file $mailfile]
    return $token
}

###########################
###########################
# Internal helper commands.

proc ::pop3d::dbox::Check {name mbox} {
    # @c Internal procedure. Used to map a mailbox handle
    # @c to the directory containing the messages.
    # @a mbox: Reference to the mailbox to be operated on.
    # @r Path of directory holding the message files of the
    # @r specified mailbox.

    set dir      [CheckDir $name]
    set mboxpath [file join $dir $mbox]

    if {! [file exists      $mboxpath]} {
	return -code error "\"$mbox\" does not exist"
    }
    if {! [file isdirectory $mboxpath]} {
	return -code error "\"$mbox\" is not a directory"
    }
    if {! [file readable    $mboxpath]} {
	return -code error "\"$mbox\" is not readable"
    }
    if {! [file writable    $mboxpath]} {
	return -code error "\"$mbox\" is not writable"
    }
    return $mboxpath
}

proc ::pop3d::dbox::CheckDir {name} {
    upvar ::pop3d::dbox::dbox::${name}::dir dir

    if {$dir == {}} {
	return -code error "base directory not specified"
    }
    return $dir
}

##########################
# Module initialization

package provide pop3d::dbox 1.0.2
