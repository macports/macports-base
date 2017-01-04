# -*- tcl -*-
# pop3d_udb.tcl --
#
#	Implementation of a simple user database for the pop3 server
#
# Copyright (c) 2002 by Andreas Kupries
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::pop3d::udb {
    # Data storage in the pop3d::udb module
    # -------------------------------------
    # One array per object containing the db contents. Keyed by user name.
    # And the information about the last file data was read from.

    # counter is used to give a unique name for unnamed databases
    variable counter 0

    # commands is the list of subcommands recognized by the server
    variable commands [list	\
	    "add"		\
	    "destroy"           \
	    "exists"		\
	    "lookup"		\
	    "read"		\
	    "remove"		\
	    "rename"		\
	    "save"		\
	    "who"		\
	    ]
}


# ::pop3d::udb::new --
#
#	Create a new user database with a given name; if no name is given, use
#	p3udbX, where X is a number.
#
# Arguments:
#	name	name of the user database; if null, generate one.
#
# Results:
#	name	name of the user database created

proc ::pop3d::udb::new {{name ""}} {
    variable counter
    
    if { [llength [info level 0]] == 1 } {
	incr counter
	set name "p3udb${counter}"
    }

    if { ![string equal [info commands ::$name] ""] } {
	return -code error \
		"command \"$name\" already exists,\
		unable to create user database"
    }

    # Set up the namespace
    namespace eval ::pop3d::udb::udb::$name {
	variable user     ;  array set user {}
	variable lastfile ""
    }

    # Create the command to manipulate the user database
    interp alias {} ::$name {} ::pop3d::udb::UdbProc $name

    return $name
}

##########################
# Private functions follow

# ::pop3d::udb::UdbProc --
#
#	Command that processes all user database object commands.
#
# Arguments:
#	name	name of the user database object to manipulate.
#	args	command name and args for the command
#
# Results:
#	Varies based on command to perform

proc ::pop3d::udb::UdbProc {name {cmd ""} args} {

    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	return -code error \
		"wrong # args: should be \"$name option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    if { [llength [info commands ::pop3d::udb::_$cmd]] == 0 } {
	variable commands
	set optlist [join $commands ", "]
	set optlist [linsert $optlist "end-1" "or"]
	return -code error "bad option \"$cmd\": must be $optlist"
    }
    eval [list ::pop3d::udb::_$cmd $name] $args
}


# ::pop3d::udb::_destroy --
#
#	Destroy a user database, including its associated command and
#	data storage.
#
# Arguments:
#	name	Name of the database to destroy.
#
# Results:
#	None.

proc ::pop3d::udb::_destroy {name} {
    namespace delete ::pop3d::udb::udb::$name
    interp alias {} ::$name {}
    return
}


proc ::pop3d::udb::_add {name usrName password storage} {
    # @c Add the user <a usrName> to the database, together with its
    # @c password and a storage reference. The latter is stored and passed
    # @c through this system without interpretation of the given value.

    # @a usrName:  The name of the user defined here.
    # @a password: Password given to the user.
    # @a storage:  symbolic reference to the maildrop of user <a usrName>.
    # @a storage:  Usable for a storage system only.

    if {$usrName  == {}} {return -code error "user specification missing"}
    if {$password == {}} {return -code error "password not specified"}
    if {$storage  == {}} {return -code error "storage location not defined"}

    upvar ::pop3d::udb::udb::${name}::user user

    set      user($usrName) [list $password $storage]
    return
}


proc ::pop3d::udb::_remove {name usrName} {
    # @c Remove the user <a usrName> from the database.
    #
    # @a usrName: The name of the user to remove.

    if {$usrName == {}} {return -code error "user specification missing"}

    upvar ::pop3d::udb::udb::${name}::user user

    if {![::info exists user($usrName)]} {
	return -code error "user \"$usrName\" not known"
    }

    unset user($usrName)
    return
}


proc ::pop3d::udb::_rename {name usrName newName} {
    # @c Renames user <a usrName> to <a newName>.
    # @a usrName: The name of the user to rename.
    # @a newName: The new name to give to the user

    if {$usrName == {}} {return -code error "user specification missing"}
    if {$newName == {}} {return -code error "user specification missing"}

    upvar ::pop3d::udb::udb::${name}::user user

    if {![::info exists user($usrName)]} {
	return -code error "user \"$usrName\" not known"
    }
    if {[::info exists user($newName)]} {
	return -code error "user \"$newName\" is known"
    }

    set data $user($usrName)
    unset     user($usrName)

    set user($newName) $data
    return
}


proc ::pop3d::udb::_lookup {name usrName} {
    # @c Query database for information about user <a usrName>.
    # @c Overrides <m userdbBase:lookup>.
    # @a usrName: Name of the user to query for.
    # @r a 2-element list containing password and storage 
    # @r reference for user <a usrName>, in this order.

    upvar ::pop3d::udb::udb::${name}::user user

    if {![::info exists user($usrName)]} {
	return -code error "user \"$usrName\" not known"
    }
    return $user($usrName)
}


proc ::pop3d::udb::_exists {name usrName} {
    # @c Determines wether user <a usrName> is registered or not.
    # @a usrName:     The name of the user to check for.

    upvar ::pop3d::udb::udb::${name}::user user

    return [::info exists user($usrName)]
}


proc ::pop3d::udb::_who {name} {
    # @c Determines the names of all registered users.
    # @r A list containing the names of all registered users.

    upvar ::pop3d::udb::udb::${name}::user user

    return [array names user]
}


proc ::pop3d::udb::_save {name {file {}}} {
    # @c Stores the current contents of the in-memory user database
    # @c into the specified file.

    # @a file: The name of the file to write to. If it is not specified, or
    # @a file: as empty, the value of the member variable <v externalFile>
    # @a file: is used instead.

    # save operation: do a backup of the file, write new contents,
    # restore backup in case of problems.

    upvar ::pop3d::udb::udb::${name}::user user
    upvar ::pop3d::udb::udb::${name}::lastfile lastfile

    if {$file == {}} {
	set file $lastfile
    }
    if {$file == {}} {
	return -code error "No file known to save data into"
    }

    set tmp [file join [file dirname $file] [pid]]

    set   f [open $tmp w]
    puts $f "# -*- tcl -*-"
    puts $f "# ----------- user authentication database -"
    puts $f ""

    foreach name [array names user] {
	set password [lindex $user($name) 0]
	set storage  [lindex $user($name) 1]

	puts $f "\tadd [list $name] [list $password] [list $storage]"
    }

    puts  $f ""
    close $f
    
    if {[file exists $file]} {
	file rename -force $file $file.old
    }
    file rename -force $tmp $file
    return
}


proc ::pop3d::udb::_read {name path} {
    # @c Reads the contents of the specified <a path> into the in-memory
    # @c database of users, passwords and storage references.

    # @a path: The name of the file to read.

    # @n The name of the file is remembered internally, and used by
    # @n <m save> (if called without or empty argument).

    upvar ::pop3d::udb::udb::${name}::user user
    upvar ::pop3d::udb::udb::${name}::lastfile lastfile

    if {$path == {}} {
	return -code error "No file known to read from"
    }

    set lastfile $path

    foreach key [array names user] {unset user($key)}

    set ip [interp create -safe]
    interp alias $ip add {} ::pop3d::udb::_add $name
    $ip invokehidden -global source $path
    interp delete $ip

    return
}

##########################
# Module initialization

package provide pop3d::udb 1.1
