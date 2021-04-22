# ftpd.tcl --
#
#       This file contains Tcl/Tk package to create a ftp daemon.
#       I believe it was originally written by Matt Newman (matt@sensus.org).  
#       Modified by Dan Kuchler (kuchler@ajubasolutions.com) to handle
#       more ftp commands and to fix some bugs in the original implementation
#       that was found in the stdtcl module.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: ftpd.tcl,v 1.34 2011/08/09 20:55:38 andreas_kupries Exp $
#

# Define the ftpd package version 1.2.5

package require Tcl 8.2
namespace eval ::ftpd {

    # The listening port.

    variable port 21

    variable contact
    if {![info exists contact]} {
        global tcl_platform
	set contact "$tcl_platform(user)@[info hostname]"
    }

    variable cwd
    if {![info exists cwd]} {
	set cwd ""
    }
    
    variable welcome
    if {![info exists welcome]} {
	set welcome "[info hostname] FTP server ready."
    }

    # Global configuration.

    variable cfg
    if {![info exists cfg]} {
	array set cfg [list \
	    closeCmd    {} \
	    authIpCmd   {} \
	    authUsrCmd  {::ftpd::anonAuth} \
            authFileCmd {::ftpd::fileAuth} \
	    logCmd      {::ftpd::logStderr} \
	    fsCmd       {::ftpd::fsFile::fs} \
	    xferDoneCmd {}]
    }

    variable commands
    if {![info exists commands]} {
	array set commands [list \
	    ABOR       {ABOR (abort operation)} \
	    ACCT       {(specify account); unimplemented.} \
	    ALLO       {(allocate storage - vacuously); unimplemented.} \
	    APPE       {APPE <sp> file-name} \
	    CDUP       {CDUP (change to parent directory)} \
	    CWD        {CWD [ <sp> directory-name ]} \
	    DELE       {DELE <sp> file-name} \
            HELP       {HELP [ <sp> <string> ]} \
	    LIST       {LIST [ <sp> path-name ]} \
	    NLST       {NLST [ <sp> path-name ]} \
	    MAIL       {(mail to user); unimplemented.} \
            MDTM       {MDTM <sp> path-name} \
	    MKD        {MKD <sp> path-name} \
	    MLFL       {(mail file); unimplemented.} \
	    MODE       {(specify transfer mode); unimplemented.} \
	    MRCP       {(mail recipient); unimplemented.} \
	    MRSQ       {(mail recipient scheme question); unimplemented.} \
	    MSAM       {(mail send to terminal and mailbox); unimplemented.} \
	    MSND       {(mail send to terminal); unimplemented.} \
	    MSOM       {(mail send to terminal or mailbox); unimplemented.} \
	    NOOP       {NOOP} \
	    PASS       {PASS <sp> password} \
            PASV       {(set server in passive mode); unimplemented.} \
	    PORT       {PORT <sp> b0, b1, b2, b3, b4, b5} \
            PWD        {PWD (return current directory)} \
	    QUIT       {QUIT (terminate service)} \
	    REIN       {REIN (reinitialize server state)} \
	    REST       {(restart command); unimplemented.} \
	    RETR       {RETR <sp> file-name} \
	    RMD        {RMD <sp> path-name} \
	    RNFR       {RNFR <sp> file-name} \
	    RNTO       {RNTO <sp> file-name} \
	    SIZE       {SIZE <sp> path-name} \
	    SMNT       {(structure mount); unimplemented.} \
	    STOR       {STOR <sp> file-name} \
	    STOU       {STOU <sp> file-name} \
	    STRU       {(specify file structure); unimplemented.} \
	    SYST       {SYST (get type of operating system)} \
	    TYPE       {TYPE <sp> [ A | E | I | L ]} \
	    USER       {USER <sp> username} \
	    XCUP       {XCUP (change to parent directory)} \
	    XCWD       {XCWD [ <sp> directory-name ]} \
	    XMKD       {XMKD <sp> path-name} \
	    XPWD       {XPWD (return current directory)} \
	    XRMD       {XRMD <sp> path-name}]
    }

    variable passwords [list ]

    # Exported procedures

    namespace export config hasCallback logStderr 
    namespace export fileAuth anonAuth unixAuth server accept read
}


# ::ftpd::config --
#
#       Configure the configurable parameters of the ftp daemon.
#
# Arguments:
#       options -    -authIpCmd proc      procedure that accepts or rejects an
#                                         incoming connection. A value of 0 or
#                                         an error causes the connection to be
#                                         rejected. There is no  default.
#                    -authUsrCmd proc     procedure that accepts or rejects a
#                                         login.  Defaults to ::ftpd::anonAuth
#                    -authFileCmd proc    procedure that accepts or rejects
#                                         access to read or write a certain
#                                         file or path.  Defaults to
#                                         ::ftpd::userAuth
#                    -logCmd proc         procedure that logs information from
#                                         the ftp engine.  Default is
#                                         ::ftpd::logStderr
#                    -fsCmd proc          procedure to connect the ftp engine
#                                         to the file system it operates on.
#                                         Default is ::ftpd::fsFile::fs
#
# Results:
#       None.
#
# Side Effects:
#       Changes the value of the specified configurables.

proc ::ftpd::config {args} {

    # Processing of global configuration changes.

    package require cmdline

    variable cfg

     # Make default value be the current value so we can call this
     # command multiple times without resetting already set values

    array set cfg [cmdline::getoptions args [list \
        [list closeCmd.arg    $cfg(closeCmd)    {Callback when a connection is closed.}] \
        [list authIpCmd.arg   $cfg(authIpCmd)   {Callback to authenticate new connections based on the ip-address of the peer. Optional}] \
        [list authUsrCmd.arg  $cfg(authUsrCmd)  {Callback to authenticate new connections based on the user logging in.}] \
        [list authFileCmd.arg $cfg(authFileCmd) {Callback to accept or deny a users access to read and write to a specific path or file.}] \
        [list logCmd.arg      $cfg(logCmd)      {Callback for log information generated by the FTP engine.}] \
        [list xferDoneCmd.arg $cfg(xferDoneCmd) {Callback for transfer completion notification. Optional}] \
        [list fsCmd.arg       $cfg(fsCmd)       {Callback to connect the engine to the filesystem it operates on.}]]]
    return
}


# ::ftpd::hasCallback --
#
#       Determines whether or not a non-NULL callback has been defined for one
#       of the callback types.
#
# Arguments:
#       callbackType -        One of authIpCmd, authUsrCmd, logCmd, or fsCmd
#
# Results:
#       Returns 1 if a non-NULL callback has been specified for the
#       callbackType that is passed in.
#
# Side Effects:
#       None.

proc ::ftpd::hasCallback {callbackType} {
    variable cfg

    return [expr {[info exists cfg($callbackType)] && [string length $cfg($callbackType)]}]
}


# ::ftpd::logStderr --
#
#       Outputs a message with the specified severity to stderr.  The default
#       logCmd callback.
#
# Arguments:
#       severity -            The severity of the error.  One of debug, error,
#                             or note.
#       text -                The error message.
#
# Results:
#       None.
#
# Side Effects:
#       A message is written to the stderr channel.

proc ::ftpd::logStderr {severity text} {

    # Standard log handler. Prints to stderr.

    puts stderr "\[$severity\] $text"
    return
}


# ::ftpd::Log --
#
#       Used for all ftpd logging.
#
# Arguments:
#       severity -            The severity of the error.  One of debug, error,
#                             or note.
#       text -                The error message.
#
# Results:
#       None.
#
# Side Effects:
#       The ftpd logCmd callback is called with the specified severity and
#       text if there is a non-NULL ftpCmd.

proc ::ftpd::Log {severity text} {

    # Central call out to log handlers.

    variable     cfg
    
    if {[hasCallback logCmd]} {
        set cmd $cfg(logCmd)
        lappend cmd $severity $text
        eval $cmd
    }
    return
}


# ::ftpd::fileAuth --
#
#       Given a username, path, and operation- decides whether or not to accept
#       the attempted read or write operation.
#
# Arguments:
#       user -                The name of the user that is attempting to
#                             connect to the ftpd.
#       path -                The path or filename that the user is attempting
#                             to read or write.
#       operation -           read or write.
#
# Results:
#       Returns 0 if it rejects access and 1 if it accepts access.
#
# Side Effects:
#       None.

proc ::ftpd::fileAuth {user path operation} {
    # Standard authentication handler

    if {(![Fs exists $path]) && ([string equal $operation "write"])} {
        if {[Fs exists [file dirname $path]]} {
            set path [file dirname $path]
	}
    } elseif {(![Fs exists $path]) && ([string equal $operation "read"])} {
        return 0
    }

    if {[Fs exists $path]} {
        set mode [Fs permissions $path]
        if {([string equal $operation "read"] && (($mode & 00004) > 0)) || \
                ([string equal $operation "write"] && (($mode & 00002) > 0))} {
            return 1
        }
    }
    return 0
}

# ::ftpd::anonAuth --
#
#       Given a username and password, decides whether or not to accept the
#       attempted login.  This is the default ftpd authUsrCmd callback. By
#       default it accepts the annonymous user and does some basic checking
#       checking on the form of the password to see if it has the form of an
#       email address.
#
# Arguments:
#       user -                The name of the user that is attempting to
#                             connect to the ftpd.
#       pass -                The password of the user that is attempting to
#                             connect to the ftpd.
#
# Results:
#       Returns 0 if it rejects the login and 1 if it accepts the login.
#
# Side Effects:
#       None.

proc ::ftpd::anonAuth {user pass} {
    # Standard authentication handler
    #
    # Accept user 'anonymous' if a password was
    # provided which is at least similar to an
    # fully qualified email address.

    if {(![string equal $user anonymous]) && (![string equal $user ftp])} {
	return 0
    }

    set pass [split $pass @]
    if {[llength $pass] != 2} {
	return 0
    }

    set domain [split [lindex $pass 1] .]
    if {[llength $domain] < 2} {
	return 0
    }

    return 1
}

# ::ftpd::unixAuth --
#
#       Given a username and password, decides whether or not to accept the
#       attempted login.  This is an alternative to the default ftpd
#       authUsrCmd callback. By default it accepts the annonymous user and does
#       some basic checking checking on the form of the password to see if it
#       has the form of an email address.
#
# Arguments:
#       user -                The name of the user that is attempting to
#                             connect to the ftpd.
#       pass -                The password of the user that is attempting to
#                             connect to the ftpd.
#
# Results:
#       Returns 0 if it rejects the login and 1 if it accepts the login.
#
# Side Effects:
#       None.

proc ::ftpd::unixAuth {user pass} {

    variable passwords
    array set password $passwords

    # Standard authentication handler
    #
    # Accept user 'anonymous' if a password was
    # provided which is at least similar to an
    # fully qualified email address.

    if {([llength $passwords] == 0) && (![catch {package require crypt}])} {
        foreach file [list /etc/passwd /etc/shadow] {
            if {([file exists $file]) && ([file readable $file])} {
                set fh [open $file r]
                set data [read $fh [file size $file]]
                foreach line [split $data \n] {
                    foreach {username passwd uid gid dir sh} [split $line :] {
                        if {[string length $passwd] > 2} {
                            set password($username) $passwd
		        } elseif {$passwd == ""} {
                            set password($username) ""
		        }
                        break
		    }
		}
	    }
	}
        set passwords [array get password]
    }

    ::ftpd::Log debug $passwords

    if {[string equal $user anonymous] || [string equal $user ftp]} {

        set pass [split $pass @]
        if {[llength $pass] != 2} {
	    return 0
        }

        set domain [split [lindex $pass 1] .]
        if {[llength $domain] < 2} {
	    return 0
        }

        return 1
    }

    if {[info exists password($user)]} {
        if {$password($user) == ""} {
            return 1
	}
        if {[string equal $password($user) [::crypt $pass $password($user)]]} {
	    return 1
        }
    }

    return 0
}

# ::ftpd::server --
#
#       Creates a server socket at the specified port.
#
# Arguments:
#       myaddr -              The domain-style name or numerical IP address of
#                             the client-side network interface to use for the
#                             connection. The name of the user that is
#                             attempting to connect to the ftpd.
#
# Results:
#       None.
#
# Side Effects:
#       A listener is setup on the specified port which will call
#       ::ftpd::accept when it is connected to.

proc ::ftpd::server {{myaddr {}}} {
    variable port
    variable serviceSock
    if {[string length $myaddr]} {
	set serviceSock [socket -server ::ftpd::accept -myaddr $myaddr $port]
    } else {
	set serviceSock [socket -server ::ftpd::accept $port]
    }
    set port [lindex [fconfigure $serviceSock -sockname] 2]
    return
}


# ::ftpd::accept --
#
#       Checks if the connecting IP is authorized to connect or not.  If not
#       the socket is closed and failure is logged.  Otherwise, a welcome is
#       printed out, and a ftpd::Read filevent is placed on the socket.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       ipaddr -              The client's IP address.
#       client_port -         The client's port number.
#
# Results:
#       None.
#
# Side Effects:
#       Sets up a ftpd::Read fileevent to trigger whenever the channel is
#       readable.  Logs an error and closes the connection if the IP is
#       not authorized to connect.

proc ::ftpd::accept {sock ipaddr client_port} {
    upvar #0 ::ftpd::$sock data
    variable welcome
    variable cfg
    variable cwd
    variable CurrentSocket 

    set CurrentSocket $sock
    if {[info exists data]} {
	unset data
    }

    if {[hasCallback authIpCmd]} {
	# Call out to authenticate the peer. A return value of 0 or an
	# error causes the system to reject the connection. Everything
	# else (with 1 prefered) leads to acceptance.

	set     cmd $cfg(authIpCmd)
	lappend cmd $ipaddr

	set fail [catch {eval $cmd} res]

	if {$fail} {
	    Log error "AuthIp error: $res"
	}
	if {$fail || ($res == 0)} {
	    Log note "AuthIp: Access denied to $ipaddr"

	    # Now: Close the connection. (Is there a standard response
	    # before closing down to signal the peer that we don't want
	    # to talk to it ? -> read RFC).

	    close $sock
	    return
	}

	# Accept the connection (for now, 'authUsrCmd' may revoke this
	# decision).
    }

    array set data [list \
        access          0 \
	ip              $ipaddr \
	state		command \
	buffering	line \
	cwd		"$cwd" \
	mode		binary \
	sock2a          "" \
        sock2           ""]

    fconfigure $sock -buffering line
    fileevent  $sock readable [list ::ftpd::Read $sock]
    puts       $sock "220 $welcome"

    Log debug "Accept $ipaddr"
    return
}

# ::ftpd::Read --
#
#       Checks the state of a channel and then reads a command from the
#       channel if it is not at end of file yet.  If there is a command named
#       ftpd::command::* where '*' is the all upper case name of the command,
#       then that proc is called to handle the command with the remaining parts
#       of the command that was read from the channel as arguments.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#
# Results:
#       None.
#
# Side Effects:
#       Runs the appropriate command depending on the state in the state
#       machine, and the command that is specified.

proc ::ftpd::Read {sock} {
    upvar #0 ::ftpd::$sock data
    variable CurrentSocket 

    set CurrentSocket $sock
    if {[eof $sock]} {
	Finish $sock
	return
    }
    switch -exact -- $data(state) {
	command {
	    gets $sock command
	    set argument ""
	    if {![regexp {^([^ ]+) (.*)$} $command -> cmd argument]} {
		if {![regexp {^([^ ]+)$} $command -> cmd]} {
		    # Very bad command syntax.
		    puts $sock "500 Command not understood."
		    return
		}
	    }
	    set cmd [string toupper $cmd]
	    auto_load ::ftpd::command::$cmd
            if {($data(access) == 0) && ((![info exists data(user)]) || \
	            ($data(user) == "")) && (![string equal $cmd "USER"])} {
                if {[string equal $cmd "PASS"]} {
		    puts $sock "503 Login with USER first."
                } else {
                    puts $sock "530 Please login with USER and PASS."
		}
	    } elseif {($data(access) == 0) && (![string equal $cmd "PASS"]) \
                    && (![string equal $cmd "USER"]) \
                    && (![string equal $cmd "QUIT"])} {
                puts $sock "530 Please login with USER and PASS."
	    } elseif {[info commands ::ftpd::command::$cmd] != ""} {
		Log debug $command
		::ftpd::command::$cmd $sock $argument
		catch {flush $sock}
	    } else {
		Log error "Unknown command: $cmd"
		puts $sock "500 Unknown command $cmd"
	    }
	}
	default {
	    error "Unknown state \"$data(state)\""
	}
    }
    return
}

# ::ftpd::Finish --
#
#       Closes the socket connection between the ftpd and client.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#
# Results:
#       None.
#
# Side Effects:
#       The channel is closed.

proc ::ftpd::Finish {sock} {
    upvar #0 ::ftpd::$sock data
    variable cfg

    if {[hasCallback closeCmd]} then {
	##
	## User specified a close command so invoke it
	##
	uplevel #0 $cfg(closeCmd)
    }
    close $sock
    if {[info exists data]} {
	unset data
    }
    return
}

# ::ftpd::FinishData --
#
#       Closes the data socket connection that is created when the 'PORT'
#       command is recieved.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#
# Results:
#       None.
#
# Side Effects:
#       The data channel is closed.

proc ::ftpd::FinishData {sock} {
    upvar #0 ::ftpd::$sock data
    catch {close $data(sock2)}
    set   data(sock2) {}
    return
}

# ::ftpd::Fs --
#
#       The general filesystem command.  Used as an intermediary for filesystem
#       access to allow alternate (virtual, etc.) filesystems to be used.  The
#       ::ftpd::Fs command will call out to the fsCmd callback with the
#       subcommand and arguments that are passed to it.
#
# The fsCmd callback is called in the following ways:
#
# <cmd> append <path>
# <cmd> delete <path> <channel-to-write-to>
# <cmd> dlist <path> <style> <channel-to-write-dir-list-to>
# <cmd> exists <path>
# <cmd> mkdir <path> <channel-to-write-to>
# <cmd> mtime <path> <channel-to-write-mtime-to>
# <cmd> permissions <path>
# <cmd> rename <path> <newpath> <channel-to-write-to>
# <cmd> retr  <path>
# <cmd> rmdir <path> <channel-to-write-to>
# <cmd> size  <path> <channel-to-write-size-to>
# <cmd> store <path>
#
# Arguments:
#       command -                The filesystem command (one of dlist, retr, or
#                                store).  'dlist' will list files in a
#                                directory, 'retr' will get a channel to
#                                to read the specified file from, 'store'
#                                will return the channel to write to, and
#                                'mtime' will print the modification time.
#       path -                   The file name or directory to read, write, or
#                                list.
#       args -                   Additional arguments for filesystem commands.
#                                Currently this is used by 'dlist' which
#                                has two additional arguments 'style' and
#                                'channel-to-write-dir-list-to'. It is also
#                                used by 'size' and 'mtime' which have one
#                                additional argument 'channel-to-write-to'.
#
# Results:
#       For a 'appe', 'retr', or 'stor' a channel is returned. For 'exists'
#       a 1 is returned if the path exists, and is not a directory.  Otherwise
#       a 0 is returned. For 'permissions' the octal file permissions (i.e.
#       the 'file stat' mode) are returned.
#
# Side Effects:
#       For 'dlist' a directory listing for the specified path is written to
#       the specified channel.  For 'mtime' the modification time is written
#       or an error is thrown.  An error is thrown if there is no fsCmd
#       callback configured for the ftpd.

proc ::ftpd::Fs {command path args} {
    variable cfg

    if {![hasCallback fsCmd]} {
	error "-fsCmd must not be empty, need a way to access files."
    }

    return [eval [list $cfg(fsCmd) $command $path] $args]
}

# Create a namespace to hold one proc for each ftp command (in upper case
# letters) that is supported by the ftp daemon.  The existance of a proc
# in this namespace is the way that the list of supported commands is
# determined, and the procs in this namespace are invoked to handle the
# ftp commands with the same name as the procs.

namespace eval ::ftpd::command {
    # All commands in this namespace are private, no export.
}

# ::ftpd::command::ABOR --
#
#       Handle the ABOR ftp command.  Closes the data socket if it
#       is open, and then prints the appropriate success message.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the APPE command.
#
# Results:
#       None.
#
# Side Effects:
#       The data is copied to from the socket data(sock2) to the
#       writable channel to create a file.

proc ::ftpd::command::ABOR {sock list} {

    ::ftpd::FinishData $sock
    puts $sock "225 ABOR command successful."

    return
}

# ::ftpd::command::APPE --
#
#       Handle the APPE ftp command.  Gets a writable channel for the file
#       specified from ::ftpd::Fs and copies the data from data(sock2) to
#       the writable channel.  If the filename already exists the data is
#       appended, otherwise the file is created and then written.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the APPE command.
#
# Results:
#       None.
#
# Side Effects:
#       The data is copied to from the socket data(sock2) to the
#       writable channel to create a file.

proc ::ftpd::command::APPE {sock filename} {
    upvar #0 ::ftpd::$sock data

    set path [file join $data(cwd) [string trimleft $filename /]]
    if {[::ftpd::hasCallback authFileCmd]} {
        set cmd $::ftpd::cfg(authFileCmd)
        lappend cmd $data(user) $path write
        if {[eval $cmd] == 0} {
	    puts $sock "550 $filename: Permission denied"
            return
        }
    }

    #
    # Patched Mark O'Connor
    #
    if {![catch {::ftpd::Fs append $path $data(mode)} f]} {
	puts $sock "150 Copy Started ($data(mode))"
	::ftpd::PasvCheckAndWait $sock
	fcopy $data(sock2) $f -command [list ::ftpd::GetDone $sock $data(sock2) $f ""]
    } else {
	puts $sock "500 Copy Failed: $path $f"
	::ftpd::FinishData $sock
    }
    return
}

# ::ftpd::command::CDUP --
#
#       Handle the CDUP ftp command.  Change the current working directory to
#       the directory above the current working directory.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the CDUP command.
#
# Results:
#       None.
#
# Side Effects:
#       Changes the data(cwd) to the appropriate directory.

proc ::ftpd::command::CDUP {sock list} {
    upvar #0 ::ftpd::$sock data

    set data(cwd) [file dirname $data(cwd)]
    puts $sock "200 CDUP command successful."
    return
}

# ::ftpd::command::CWD --
#
#       Handle the CWD ftp command.  Change the current working directory.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the CWD command.
#
# Results:
#       None.
#
# Side Effects:
#       Changes the data(cwd) to the appropriate directory.

proc ::ftpd::command::CWD {sock relativepath} {
    upvar #0 ::ftpd::$sock data

    if {[string equal $relativepath .]} {
	puts $sock "250 CWD command successful."
	return
    }

    if {[string equal $relativepath ..]} {
	set data(cwd) [file dirname $data(cwd)]
	puts $sock "250 CWD command successful."
	return
    }

    set path [file join $data(cwd) $relativepath]

    if {[::ftpd::Fs exists $path]} {
        puts $sock "550 not a directory"
        return
    }

    set data(cwd) $path
    puts $sock "250 CWD command successful."
    return
}

# ::ftpd::command::DELE --
#
#       Handle the DELE ftp command.  Delete the specified file.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the DELE command.
#
# Results:
#       None.
#
# Side Effects:
#       The specified file is deleted.

proc ::ftpd::command::DELE {sock filename} {
    upvar #0 ::ftpd::$sock data

    set path [file join $data(cwd) [string trimleft $filename /]]
    if {[::ftpd::hasCallback authFileCmd]} {
        set cmd $::ftpd::cfg(authFileCmd)
        lappend cmd $data(user) $path write
        if {[eval $cmd] == 0} {
	    puts $sock "550 $filename: Permission denied"
            return
        }
    }

    if {[catch {::ftpd::Fs delete $path $sock} msg]} {
	puts $sock "500 DELE Failed: $path $msg"
    }
    return
}

# ::ftpd::command::HELP --
#
#       Handle the HELP ftp command.  Display a list of commands
#       or syntax information about the supported commands.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the HELP command.
#
# Results:
#       None.
#
# Side Effects:
#       Displays a helpful message.

proc ::ftpd::command::HELP {sock command} {
    upvar #0 ::ftpd::$sock data

    if {$command != ""} {
        set command [string toupper $command]
        if {![info exists ::ftpd::commands($command)]} {
            puts $sock "502 Unknown command '$command'."
	} elseif {[info commands ::ftpd::command::$command] == ""} {
            puts $sock "214 $command\t$::ftpd::commands($command)"
	} else {
	    puts $sock "214 Syntax: $::ftpd::commands($command)"
        }
    } else {
        set commandList [lsort [array names ::ftpd::commands]]
        puts $sock "214-The following commands are recognized (* =>'s unimplemented)."
        set i 1
        foreach commandName $commandList {
            if {[info commands ::ftpd::command::$commandName] == ""} {
                puts -nonewline $sock [format " %-7s" "${commandName}*"]
	    } else {
                puts -nonewline $sock [format " %-7s" $commandName]
	    }
            if {($i % 8) == 0} {
                puts $sock ""
	    }
            incr i
	}
        incr i -1
        if {($i % 8) != 0} {
            puts $sock ""
	}
        puts $sock "214 Direct comments to $::ftpd::contact."
    }

    return
}

# ::ftpd::command::LIST --
#
#       Handle the LIST ftp command.  Lists the names of the files in the
#       specified path.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the LIST command.
#
# Results:
#       None.
#
# Side Effects:
#       A listing of files is written to the socket.

proc ::ftpd::command::LIST {sock filename} {
    ::ftpd::List $sock $filename list
    return
}

# ::ftpd::command::MDTM --
#
#       Handle the MDTM ftp command.  Prints the modification time of the
#       specified file to the socket.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the MDTM command.
#
# Results:
#       None.
#
# Side Effects:
#       Prints the modification time of the specified file to the socket.

proc ::ftpd::command::MDTM {sock filename} {
    upvar #0 ::ftpd::$sock data

    set path [file join $data(cwd) [string trimleft $filename /]]
    if {[catch {::ftpd::Fs mtime $path $sock} msg]} {
	puts $sock "500 MDTM Failed: $path $msg"
	::ftpd::FinishData $sock
    }
    return
}

# ::ftpd::command::MKD --
#
#       Handle the MKD ftp command.  Create the specified directory.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the MKD command.
#
# Results:
#       None.
#
# Side Effects:
#       The directory specified by $path (if it exists) is deleted.

proc ::ftpd::command::MKD {sock filename} {
    upvar #0 ::ftpd::$sock data

    set path [file join $data(cwd) [string trimleft $filename /]]

    if {[::ftpd::hasCallback authFileCmd]} {
        set cmd $::ftpd::cfg(authFileCmd)
        lappend cmd $data(user) $path write
        if {[eval $cmd] == 0} {
	    puts $sock "550 $filename: Permission denied"
            return
        }
    }

    if {[catch {::ftpd::Fs mkdir $path $sock} f]} {
	puts $sock "500 MKD Failed: $path $f"
    }
    return
}

# ::ftpd::command::NOOP --
#
#       Handle the NOOP ftp command.  Do nothing.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the NOOP command.
#
# Results:
#       None.
#
# Side Effects:
#       Prints the proper NOOP response.

proc ::ftpd::command::NOOP {sock list} {

    puts $sock "200 NOOP command successful."
    return
}

# ::ftpd::command::NLST --
#
#       Handle the NLST ftp command.  Lists the full file stat of all of the
#       files that are in the specified path.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the NLST command.
#
# Results:
#       None.
#
# Side Effects:
#       A listing of file stats is written to the socket.

proc ::ftpd::command::NLST {sock filename} {
    ::ftpd::List $sock $filename nlst
    return
}

# ::ftpd::command::PASS --
#
#       Handle the PASS ftp command.  Check whether the specified user
#       and password are allowed to log in (using the authUsrCmd).  If
#       they are allowed to log in, they are allowed to continue.  If
#       not ::ftpd::Log is used to log and error, and an "Access Denied"
#       error is sent back.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the PASS command.
#
# Results:
#       None.
#
# Side Effects:
#       The user is accepted, or an error is logged and the user/password is
#       denied..

proc ::ftpd::command::PASS {sock password} {
    upvar #0 ::ftpd::$sock data

    if {$password == ""} {
        puts $sock "530 Please login with USER and PASS."
        return
    }
    set data(pass) $password

    ::ftpd::Log debug "pass <$data(pass)>"

    if {![::ftpd::hasCallback authUsrCmd]} {
	error "-authUsrCmd must not be empty, need a way to authenticate the user."
    }

    # Call out to authenticate the user. A return value of 0 or an
    # error causes the system to reject the connection. Everything
    # else (with 1 prefered) leads to acceptance.
    
    set cmd $::ftpd::cfg(authUsrCmd)
    lappend cmd $data(user) $data(pass)

    set fail [catch {eval $cmd} res]

    if {$fail} {
	::ftpd::Log error "AuthUsr error: $res"
    }
    if {$fail || ($res == 0)} {
	::ftpd::Log note "AuthUsr: Access denied to <$data(user)> <$data(pass)>."
	unset data(user)
        unset data(pass)
        puts $sock "551 Access Denied"
    } else {
	puts $sock "230 OK"
	set data(access) 1
    }
    return
}

# ::ftpd::command::PORT --
#
#       Handle the PORT ftp command.  Create a new socket with the specified
#       paramaters.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the PORT command.
#
# Results:
#       None.
#
# Side Effects:
#       A new socket, data(sock2), is opened.

proc ::ftpd::command::PORT {sock numbers} {
    upvar #0 ::ftpd::$sock data
    set x [split $numbers ,]

    ::ftpd::FinishData $sock

    set data(sock2) [socket [join [lrange $x 0 3] .] \
	[expr {([lindex $x 4] << 8) | [lindex $x 5]}]]
    fconfigure $data(sock2) -translation $data(mode)
    puts $sock "200 PORT OK"
    return
}

# ::ftpd::command::PWD --
#
#       Handle the PWD ftp command.  Prints the current working directory to
#       the socket.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the PWD command.
#
# Results:
#       None.
#
# Side Effects:
#       Prints the current working directory to the socket.

proc ::ftpd::command::PWD {sock list} {
    upvar #0 ::ftpd::$sock data
    ::ftpd::Log debug $data(cwd)
    puts $sock "257 \"$data(cwd)\" is current directory."
    return
}

# ::ftpd::command::QUIT --
#
#       Handle the QUIT ftp command.  Closes the socket.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the PWD command.
#
# Results:
#       None.
#
# Side Effects:
#       Closes the connection.

proc ::ftpd::command::QUIT {sock list} {
    ::ftpd::Log note "Closed $sock"
    puts $sock "221 Goodbye."
    ::ftpd::Finish $sock
    # FRINK: nocheck
    #unset ::ftpd::$sock
    return
}

# ::ftpd::command::REIN --
#
#       Handle the REIN ftp command. This command terminates a USER, flushing
#       all I/O and account information, except to allow any transfer in
#       progress to be completed.  All parameters are reset to the default
#       settings and the control connection is left open.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the REIN command.
#
# Results:
#       None.
#
# Side Effects:
#       The file specified by $path (if it exists) is copied to the socket
#       data(sock2) otherwise a 'Copy Failed' message is output.

proc ::ftpd::command::REIN {sock list} {
    upvar #0 ::ftpd::$sock data

    ::ftpd::FinishData $sock
    catch {close $data(sock2a)}

    # Reinitialize the user and connection data.

    array set data [list \
        access          0 \
	state		command \
	buffering	line \
	cwd		"$::ftpd::cwd" \
	mode		binary \
	sock2a          "" \
        sock2           ""]

    return
}

# ::ftpd::command::RETR --
#
#       Handle the RETR ftp command.  Gets a readable channel for the file
#       specified from ::ftpd::Fs and copies the file to second socket 
#       data(sock2).
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the RETR command.
#
# Results:
#       None.
#
# Side Effects:
#       The file specified by $path (if it exists) is copied to the socket
#       data(sock2) otherwise a 'Copy Failed' message is output.

proc ::ftpd::command::RETR {sock filename} {
    upvar #0 ::ftpd::$sock data

    set path [file join $data(cwd) [string trimleft $filename /]]

    if {[::ftpd::hasCallback authFileCmd]} {
        set cmd $::ftpd::cfg(authFileCmd)
        lappend cmd $data(user) $path read
        if {[eval $cmd] == 0} {
	    puts $sock "550 $filename: Permission denied"
            return
        }
    }

    #
    # Patched Mark O'Connor
    #
    if {![catch {::ftpd::Fs retr $path $data(mode)} f]} {
	puts $sock "150 Copy Started ($data(mode))"
	::ftpd::PasvCheckAndWait $sock
	fcopy $f $data(sock2) -command [list ::ftpd::GetDone $sock $data(sock2) $f ""]
    } else {
	puts $sock "500 Copy Failed: $path $f"
	::ftpd::FinishData $sock
    }
    return
}

# ::ftpd::command::RMD --
#
#       Handle the RMD ftp command.  Remove the specified directory.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the RMD command.
#
# Results:
#       None.
#
# Side Effects:
#       The directory specified by $path (if it exists) is deleted.

proc ::ftpd::command::RMD {sock filename} {
    upvar #0 ::ftpd::$sock data

    set path [file join $data(cwd) [string trimleft $filename /]]

    if {[::ftpd::hasCallback authFileCmd]} {
        set cmd $::ftpd::cfg(authFileCmd)
        lappend cmd $data(user) $path write
        if {[eval $cmd] == 0} {
	    puts $sock "550 $filename: Permission denied"
            return
        }
    }
    if {[catch {::ftpd::Fs rmdir $path $sock} f]} {
	puts $sock "500 RMD Failed: $path $f"
    }
    return
}

# ::ftpd::command::RNFR --
#
#       Handle the RNFR ftp command.  Stores the name of the file to rename
#       from.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the RNFR command.
#
# Results:
#       None.
#
# Side Effects:
#       If the file specified by $path exists, then store the name and request
#       the next name.

proc ::ftpd::command::RNFR {sock filename} {
    upvar #0 ::ftpd::$sock data

    set path [file join $data(cwd) [string trimleft $filename /]]

    if {[::ftpd::Fs exists $path]} {
        if {[::ftpd::hasCallback authFileCmd]} {
            set cmd $::ftpd::cfg(authFileCmd)
            lappend cmd $data(user) $path write
            if {[eval $cmd] == 0} {
	        puts $sock "550 $filename: Permission denied"
                return
            }
	}

        puts $sock "350 File exists, ready for destination name"
        set data(renameFrom) $path
    } else {
        puts $sock "550 $path: No such file or directory."
    }
    return
}

# ::ftpd::command::RNTO --
#
#       Handle the RNTO ftp command.  Renames the file specified by 'RNFR' if
#       one was specified.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the RNTO command.
#
# Results:
#       None.
#
# Side Effects:
#       The specified file is renamed.

proc ::ftpd::command::RNTO {sock filename} {
    upvar #0 ::ftpd::$sock data

    if {$filename == ""} {
        puts $sock "500 'RNTO': command not understood."
        return
    }

    set path [file join $data(cwd) [string trimleft $filename /]]

    if {![info exists data(renameFrom)]} {
        puts $sock "503 Bad sequence of commands."
        return
    }
    if {[::ftpd::hasCallback authFileCmd]} {
        set cmd $::ftpd::cfg(authFileCmd)
        lappend cmd $data(user) $path write
        if {[eval $cmd] == 0} {
            puts $sock "550 $filename: Permission denied"
            return
        }
    }


    if {![catch {::ftpd::Fs rename $data(renameFrom) $path $sock} msg]} {
        unset data(renameFrom)
    } else {
        unset data(renameFrom)
        puts $sock "500 'RNTO': command not understood."
    }
    return
}

# ::ftpd::command::SIZE --
#
#       Handle the SIZE ftp command.  Prints the modification time of the
#       specified file to the socket.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the MDTM command.
#
# Results:
#       None.
#
# Side Effects:
#       Prints the size of the specified file to the socket.

proc ::ftpd::command::SIZE {sock filename} {
    upvar #0 ::ftpd::$sock data

    set path [file join $data(cwd) [string trimleft $filename /]]
    if {[catch {::ftpd::Fs size $path $sock} msg]} {
	puts $sock "500 SIZE Failed: $path $msg"
	::ftpd::FinishData $sock
    }
    return
}
 
# ::ftpd::command::STOR --
#
#       Handle the STOR ftp command.  Gets a writable channel for the file
#       specified from ::ftpd::Fs and copies the data from data(sock2) to
#       the writable channel.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the STOR command.
#
# Results:
#       None.
#
# Side Effects:
#       The data is copied to from the socket data(sock2) to the
#       writable channel to create a file.

proc ::ftpd::command::STOR {sock filename} {
    upvar #0 ::ftpd::$sock data

    set path [file join $data(cwd) [string trimleft $filename /]]
    if {[::ftpd::hasCallback authFileCmd]} {
        set cmd $::ftpd::cfg(authFileCmd)
        lappend cmd $data(user) $path write
        if {[eval $cmd] == 0} {
	    puts $sock "550 $filename: Permission denied"
            return
        }
    }

    #
    # Patched Mark O'Connor
    #
    if {![catch {::ftpd::Fs store $path $data(mode)} f]} {
	puts $sock "150 Copy Started ($data(mode))"
	::ftpd::PasvCheckAndWait $sock
	fcopy $data(sock2) $f -command [list ::ftpd::GetDone $sock $data(sock2) $f ""]
    } else {
	puts $sock "500 Copy Failed: $path $f"
	::ftpd::FinishData $sock
    }
    return
}

# ::ftpd::command::STOU --
#
#       Handle the STOR ftp command.  Gets a writable channel for the file
#       specified from ::ftpd::Fs and copies the data from data(sock2) to
#       the writable channel.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the STOU command.
#
# Results:
#       None.
#
# Side Effects:
#       The data is copied to from the socket data(sock2) to the
#       writable channel to create a file.

proc ::ftpd::command::STOU {sock filename} {
    upvar #0 ::ftpd::$sock data

    set path [file join $data(cwd) [string trimleft $filename /]]
    if {[::ftpd::hasCallback authFileCmd]} {
        set cmd $::ftpd::cfg(authFileCmd)
        lappend cmd $data(user) $path write
        if {[eval $cmd] == 0} {
	    puts $sock "550 $filename: Permission denied"
            return
        }
    }
    
    set file $path
    set i 0
    while {[::ftpd::Fs exists $file]} {
        set file "$path.$i"
        incr i
    }

    #
    # Patched Mark O'Connor
    #
    if {![catch {::ftpd::Fs store $file $data(mode)} f]} {
	puts $sock "150 Copy Started ($data(mode))"
	::ftpd::PasvCheckAndWait $sock
	fcopy $data(sock2) $f -command [list ::ftpd::GetDone $sock $data(sock2) $f $file]
    } else {
	puts $sock "500 Copy Failed: $path $f"
	::ftpd::FinishData $sock
    }
    return
}

# ::ftpd::command::SYST --
#
#       Handle the SYST ftp command.  Print the system information.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the SYST command.
#
# Results:
#       None.
#
# Side Effects:
#       Prints the system information.

proc ::ftpd::command::SYST {sock list} {
    upvar #0 ::ftpd::$sock data

    global tcl_platform

    if {[string equal $tcl_platform(platform) "unix"]} {
        set platform UNIX
    } elseif {[string equal $tcl_platform(platform) "windows"]} {
        set platform WIN32
    } elseif {[string equal $tcl_platform(platform) "macintosh"]} {
        set platform MACOS
    } else {
        set platform UNKNOWN
    }
    set version [string toupper $tcl_platform(os)]
    puts $sock "215 $platform Type: L8 Version: $version"

    return
}

# ::ftpd::command::TYPE --
#
#       Handle the TYPE ftp command.  Sets up the proper translation mode on
#       the data socket data(sock2)
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the TYPE command.
#
# Results:
#       None.
#
# Side Effects:
#       The translation mode of the data channel is changed to the appropriate
#       mode.
 
proc ::ftpd::command::TYPE {sock type} {
    upvar #0 ::ftpd::$sock data

    if {[string compare i [string tolower $type]] == 0} {
	set data(mode) binary
    } else {
	set data(mode) auto
    }

    if {$data(sock2) != {}} {
	fconfigure $data(sock2) -translation $data(mode)
    }
    puts $sock "200 Type set to $type."
    return
}

# ::ftpd::command::USER --
#
#       Handle the USER ftp command.  Store the username, and request a
#       password.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       list -                   The arguments to the USER command.
#
# Results:
#       None.
#
# Side Effects:
#       A message is printed asking for the password.

proc ::ftpd::command::USER {sock username} {
    upvar #0 ::ftpd::$sock data

    if {$username == ""} {
        puts $sock "530 Please login with USER and PASS."
        return
    }
    set data(user) $username
    puts $sock "331 Password Required"

    ::ftpd::Log debug "user <$data(user)>"
    return
}

# ::ftpd::GetDone --
#
#       The fcopy command callback for both the RETR and STOR calls.  Called
#       after the fcopy completes.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       sock2 -                  The data socket data(sock2).
#       f -                      The file channel.
#       filename -               The name of the unique file (if a unique
#                                transfer was requested), and the empty string
#                                otherwise
#       bytes -                  The number of bytes that were copied.
#       err -                    Passed if an error occurred during the fcopy.
#
# Results:
#       None.
#
# Side Effects:
#       The open file channel is closed and a 'complete' message is printed to
#       the socket.

proc ::ftpd::GetDone {sock sock2 f filename bytes {err {}}} {
    upvar #0 ::ftpd::$sock data
    variable cfg

    close $f
    FinishData $sock

    if {[string length $err]} {
	puts $sock "226- $err"
    } elseif {$filename == ""} {
        puts $sock "226 Transfer complete ($bytes bytes)"
    } else {
        puts $sock "226 Transfer complete (unique file name: $filename)."
    }
    if {[hasCallback xferDoneCmd]} then {
	catch {$cfg(xferDoneCmd) $sock $sock2 $f $bytes $filename $err}
    }
    Log debug "GetDone $f $sock2 $bytes bytes filename: $filename"
    return
}

# ::ftpd::List --
#
#       Handle the NLST and LIST ftp commands.  Shared command to do the
#       actual listing of files.
#
# Arguments:
#       sock -                   The channel for this connection to the ftpd.
#       filename -               The path/filename to list.
#       style -                  The type of listing -- nlst or list.
#
# Results:
#       None.
#
# Side Effects:
#       A listing of file stats is written to the socket.

proc ::ftpd::List {sock filename style} {
    upvar #0 ::ftpd::$sock data
    puts $sock "150 Opening data channel"

    set path [file join $data(cwd) $filename]

    PasvCheckAndWait $sock
    Fs dlist $path $style $data(sock2)

    FinishData $sock
    puts $sock "226 Listing complete"
    return
}

# Standard filesystem - Assume the files are held on a standard disk.  This
# namespace contains the commands to act as the default fsCmd callback for the
# ftpd.

namespace eval ::ftpd::fsFile {
    # Our document root directory

    variable docRoot
    if {![info exists docRoot]} {
	set docRoot /
    }

    namespace export docRoot fs
}

# ::ftpd::fsFile::docRoot --
#
#       Set or query the root of the ftpd file system.  If no 'dir' argument
#       is passed, or if the 'dir' argument is the null string, then the
#       current docroot is returned.  If a non-NULL 'dir' argument is passed
#       in it is set as the docRoot.
#
# Arguments:
#       dir  -                   The directory to set as the ftp docRoot.
#                                (optional. If unspecified, the current docRoot
#                                is returned).
#
# Results:
#       None.
#
# Side Effects:
#       Sets the docRoot to the specified directory if a directory is
#       specified.

proc ::ftpd::fsFile::docRoot {{dir {}}} {
    variable docRoot
    if {[string length $dir] == 0} {
	return $docRoot
    } else {
	set docRoot $dir
    }
    return ""
}

# ::ftpd::fsFile::fs --
#
#       Handles the a standard file systems file system requests and is the
#       default fsCmd callback.
#
# Arguments:
#       command -                The filesystem command (one of dlist, retr, or
#                                store).  'dlist' will list files in a
#                                directory, 'retr' will get a channel to
#                                to read the specified file from, and 'store'
#                                will return the channel to write to.
#       path -                   The file name or directory to read, write or
#                                list.
#       args -                   Additional arguments for filesystem commands.
#                                Currently this is used by 'dlist' which
#                                has two additional arguments 'style' and
#                                'channel-to-write-dir-list-to'. It is also
#                                used by 'size' and 'mtime' which have one
#                                additional argument 'channel-to-write-to'.
#
# Results:
#       For a 'appe', 'retr', or 'stor' a channel is returned. For 'exists' a 1
#       is returned if the path exists, and is not a directory.  Otherwise a
#       0 is returned.  For 'permissions' the octal file permissions (i.e.
#       the 'file stat' mode) are returned.
#
# Side Effects:
#       For 'dlist' a directory listing for the specified path is written to
#       the specified channel.  For 'mtime' the modification time is written
#       or an error is thrown.  An error is thrown if there is no fsCmd
#       callback configured for the ftpd.

proc ::ftpd::fsFile::fs {command path args} {
    # append <path>
    # delete <path> <channel-to-write-to>
    # dlist <path> <style> <channel-to-write-dir-list-to>
    # exists <path>
    # mkdir <path> <channel-to-write-to>
    # mtime <path> <channel-to-write-mtime-to>
    # permissions <path>
    # rename <path> <newpath> <channel-to-write-to>
    # retr  <path>
    # rmdir <path> <channel-to-write-to>
    # size  <path> <channel-to-write-size-to>
    # store <path>

    global tcl_platform

    variable docRoot

    set path [file join $docRoot $path]

    switch -exact -- $command {
        append {
	    #
	    # Patched Mark O'Connor
	    #
	    set fhandle [open $path a]
	    if {[lindex $args 0] == "binary"} {
		fconfigure $fhandle -translation binary -encoding binary
	    }
	    return $fhandle
        }
	retr {
	    #
	    # Patched Mark O'Connor
	    #
	    set fhandle [open $path r]
	    if {[lindex $args 0] == "binary"} {
		fconfigure $fhandle -translation binary -encoding binary
	    }
	    return $fhandle
	}
	store {
	    #
	    # Patched Mark O'Connor
	    #
	    set fhandle [open $path w]
	    if {[lindex $args 0] == "binary"} {
		fconfigure $fhandle -translation binary -encoding binary
	    }
	    return $fhandle
	}
	dlist {
	    foreach {style outchan} $args break
	    ::ftpd::Log debug "at dlist {$style} {$outchan} {$path}"
	    #set path [glob -nocomplain $path]
	    #::ftpd::Log debug "at dlist2 {$style} {$outchan} {$path}"

            # Attempt to get a list of all files (even ones that start with .)

	    if {[file isdirectory $path]} {
		set path1 [file join $path *]
                set path2 [file join $path .*]
	    } else {
                set path1 $path
                set path2 $path
	    }

            # Get a list of all files that match the glob pattern

            set fileList [lsort -unique [concat [glob -nocomplain $path1] \
                    [glob -nocomplain $path2]]]
	    
	    ::ftpd::Log debug "File list is {$fileList}"

	    switch -- $style {
	        nlst {
		    ::ftpd::Log debug "In nlist"
	            foreach f [lsort $fileList] {
                        if {[string equal [file tail $f] "."] || \
                                [string equal [file tail $f] ".."]} {
                            continue
                        }
			if {[string equal {} $f]} then continue
			::ftpd::Log debug [file tail $f]
		        puts $outchan [file tail $f]
	            }
	        }
		list {
		    # [ 766112 ] report . and .. directories (linux)
		    # Copied the code from 'nlst' above to handle this.

	            foreach f [lsort $fileList] {
                        if {[string equal [file tail $f] "."] || \
                                [string equal [file tail $f] ".."]} {
                            continue
                        }
			file stat $f stat
                        if {[string equal $tcl_platform(platform) "unix"]} {
                            set user [file attributes $f -owner]
                            set group [file attributes $f -group]
                        } else {
                            set user owner
                            set group group
                        }
			puts $outchan [format "%s %3d %s %8s %11s %s %s" \
			        [PermBits $f $stat(mode)] $stat(nlink) \
	                        $user $group $stat(size) \
                                [FormDate $stat(mtime)] [file tail $f]]
		    }
		}
		default {
		    error "Unknown list style <$style>"
		}
	    }
	}
        delete {
	    foreach {outchan} $args break

            if {![file exists $path]} {
                puts $outchan "550 $path: No such file or directory."
	    } elseif {![file isfile $path]} {
                puts $outchan "550 $path: File exists."
	    } else {
                file delete $path
                puts $outchan "250 DELE command successful."
	    }
	}
        exists {
            if {[file isdirectory $path]} {
                return 0
	    } else {
                return [file exists $path]
	    }
	}
        mkdir {
	    foreach {outchan} $args break

            set path [string trimright $path /]
            if {[file exists $path]} {
                if {[file isdirectory $path]} {
                    puts $outchan "521 \"$path\" directory exists"
		} else {
		    puts $outchan "521 \"$path\" already exists"
                }
	    } elseif {[file exists [file dirname $path]]} {
                file mkdir $path
                puts $outchan "257 \"$path\" new directory created."
	    } else {
                puts $outchan "550 $path: No such file or directory."
	    }
	}
        mtime {
	    foreach {outchan} $args break

            if {![file exists $path]} {
                puts $outchan "550 $path: No such file or directory"
            } elseif {![file isfile $path]} {
	        puts $outchan "550 $path: not a plain file."
            } else {
                set time [file mtime $path]
                puts $outchan [clock format $time -format "213 %Y%m%d%H%M%S"]
	    }
        }
        permissions {
	    file stat $path stat
            return $stat(mode)
        }
        rename {
            foreach {newname outchan} $args break

            if {![file isdirectory [file dirname $newname]]} {
	        puts $outchan "550 rename: No such file or directory."
            }
            file rename $path $newname
            puts $outchan "250 RNTO command successful."
	}
        rmdir {
	    foreach {outchan} $args break

            if {![file isdirectory $path]} {
                puts $outchan "550 $path: Not a directory."
	    } elseif {[llength [glob -nocomplain [file join $path *]]] != 0} {
                puts $outchan "550 $path: Directory not empty."
            } else {
                file delete $path
                puts $outchan "250 RMD command successful."
	    }
	}
        size {
	    foreach {outchan} $args break

            if {![file exists $path]} {
                puts $outchan "550 $path: No such file or directory"
            } elseif {![file isfile $path]} {
	        puts $outchan "550 $path: not a plain file."
            } else {
                puts $outchan "213 [file size $path]"
	    }
        }
	default {
	    error "Unknown command \"$command\""
	}
    }
    return ""
}

# ::ftpd::fsFile::PermBits --
#
#       Returns the file permissions for the specified file.
#
# Arguments:
#       file  -                  The file to return the permissions of.
#
# Results:
#       The permissions for the specified file are returned.
#
# Side Effects:
#       None.

proc ::ftpd::fsFile::PermBits {file mode} {

    array set s {
        0 --- 1 --x 2 -w- 3 -wx 4 r-- 5 r-x 6 rw- 7 rwx
    }

    set type [file type $file]
    if {[string equal $type "file"]} {
        set permissions "-"
    } else {
        set permissions [string index $type 0]
    }
    foreach j [split [format %03o [expr {$mode&0777}]] {}] {
        append permissions $s($j)
    }

    return $permissions
}

# ::ftpd::fsFile::FormDate --
#
#       Returns the file permissions for the specified file.
#
# Arguments:
#       seconds  -              The number of seconds returned by 'file mtime'.
#
# Results:
#       A formatted date is returned.
#
# Side Effects:
#       None.

proc ::ftpd::fsFile::FormDate {seconds} {

    set currentTime [clock seconds]
    set oldTime [clock scan "6 months ago" -base $currentTime]
    if {$seconds <= $oldTime} {
        set time [clock format $seconds -format "%Y"]
    } else {
        set time [clock format $seconds -format "%H:%M"]
    }
    set day [string trimleft [clock format $seconds -format "%d"] 0]
    set month [clock format $seconds -format "%b"]
    return [format "%3s %2s %5s" $month $day $time]
}

# Only provide the package if it has been successfully
# sourced into the interpreter.

#
# Patched Mark O'Connor
#
package provide ftpd 1.3


##
## Implementation of passive command
##
proc ::ftpd::command::PASV {sock argument} {
    upvar #0 ::ftpd::$sock data

    set data(sock2a) [socket -server [list ::ftpd::PasvAccept $sock] 0]
    set list1 [fconfigure $sock -sockname]
    set ip [lindex $list1 0]
    set list2 [fconfigure $data(sock2a) -sockname]
    set port [lindex $list2 2]
    ::ftpd::Log debug "PASV on {$list1} {$list2} $ip $port"
    set ans [split $ip {.}]
    lappend ans [expr {($port >> 8) & 0xff}] [expr {$port & 0xff}]
    set ans [join $ans {,}]
    puts $sock "227 Entering Passive Mode ($ans)."
    set data(sock2) ""
    return
}


proc ::ftpd::PasvAccept {sock sock2 ip port} {
    upvar #0 ::ftpd::$sock data

    ::ftpd::Log debug "In Pasv Accept with {$sock} {$sock2} {$ip} {$port}"
    ##
    ## Verify this is from who it should be
    ##
    if {![string equal $ip $data(ip)]} then {
	##
	## Nope, so close it and wait some more
	##
	close $sock2
	return
    }
    ::ftpd::FinishData $sock

    set data(sock2) $sock2 ; # (*), see ::ftpd::PasvCheckAndWait
    fconfigure $data(sock2) -translation $data(mode)
    close $data(sock2a)
    set data(sock2a) ""
    return
}

proc ::ftpd::PasvCheckAndWait {sock} {
    upvar #0 ::ftpd::$sock data

    # Check if we are in passive mode, with the data connection not
    # yet established. If so, wait for the data connection to be
    # made. This vwait is unlocked by (*) in ::ftpd::PasvAccept above.

    if {$data(sock2) != ""} return
    vwait ::ftpd::${sock}(sock2)
    return
}
