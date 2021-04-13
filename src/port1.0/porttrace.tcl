# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# porttrace.tcl
#
# Copyright (c) 2005-2006 Paul Guyot <pguyot@kallisys.net>
# Copyright 2007, 2009-2010, 2012-2016 The MacPorts Project
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of The MacPorts Project nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

package provide porttrace 1.0
package require Pextlib 1.0
package require portutil 1.0

namespace eval porttrace {
    ##
    # The fifo currently used as server socket to establish communication
    # between traced processes and the server-side of trace mode.
    variable fifo

    ##
    # The mktemp(3) template used to generate a filename for the fifo.
    # Note that Unix sockets are limited to 109 characters and that the
    # macports user must be able to connect to the socket (and in case of
    # non-root installations, the current user, too).
    variable fifo_mktemp_template "/tmp/macports-trace/sock-XXXXXX"

    ##
    # The Tcl thread that runs the server side of trace mode and deals with
    # requests from traced processes.
    variable thread

    ##
    # An ordered duplicate-free list of files to which access was denied by
    # trace mode.
    variable sandbox_violation_list [list]

    ##
    # An ordered duplicate-free list of files inside the MacPorts prefix but
    # unknown to MacPorts that were used by the current trace session.
    variable sandbox_unknown_list [list]

    proc appendEntry {sandbox path action} {
        upvar 2 $sandbox sndbxlst

        set mapping {}
        # Escape backslashes with backslashes
        lappend mapping "\\" "\\\\"
        # Escape colons with \:
        lappend mapping ":" "\\:"
        # Escape equal signs with \=
        lappend mapping "=" "\\="

        # file normalize will leave symlinks as the very last
        # path component intact. This will, for instance, prevent /tmp from
        # being resolved to /private/tmp.
        # Use realpath to avoid this behavior.
        set normalizedPath [file normalize $path]
        # realpath only works on files that exist
        if {![catch {file type $normalizedPath}]} {
            set normalizedPath [realpath $normalizedPath]
        }
        lappend sndbxlst "[string map $mapping $path]=$action"
        if {$normalizedPath ne $path} {
            lappend sndbxlst "[string map $mapping $normalizedPath]=$action"
        }
    }

    ##
    # Append a trace sandbox entry suitable for allowing access to
    # a directory to a given sandbox list.
    #
    # @param sandbox The name of the sandbox list variable
    # @param path The path that should be permitted
    proc allow {sandbox path} {
        appendEntry $sandbox $path "+"
    }

    ##
    # Append a trace sandbox entry suitable for denying access to a directory
    # (and stopping processing of the sandbox) to a given sandbox list.
    #
    # @param sandbox The name of the sandbox list variable
    # @param path The path that should be denied
    proc deny {sandbox path} {
        appendEntry $sandbox $path "-"
    }

    ##
    # Append a trace sandbox entry suitable for deferring the access decision
    # back to MacPorts to query for dependencies to a given sandbox list.
    #
    # @param sandbox The name of the sandbox list variable
    # @param path The path that should be handed back to MacPorts for further
    #             processing.
    proc ask {sandbox path} {
        appendEntry $sandbox $path "?"
    }

    ##
    # Start a trace mode session with the given $workpath. Creates a thread to
    # handle requests from traced processes and sets up the sandbox bounds. You
    # must call trace_stop once for each call to trace_start after you're done
    # tracing processes.
    #
    # @param workpath The $workpath of the current installation
    proc trace_start {workpath} {
        global \
            developer_dir distpath env macportsuser os.platform configure.sdkroot \
            portpath prefix use_xcode

        variable fifo
        variable fifo_mktemp_template

        if {[catch {package require Thread} error]} {
            ui_warn "Trace mode requires Tcl Thread package ($error)"
            return 0
        }

        # Generate a name for the socket to be used to communicate with the
        # processes being traced.
        set fifo [mktemp $fifo_mktemp_template]

        # Create enclosing directory with correct permissions, i.e. no
        # finding out what the socket is called by listing the directory,
        # but it can be opened if you know its name.
        set fifo_dir [file dirname $fifo]
        file mkdir $fifo_dir
        if {[geteuid] == 0} {
            file attributes $fifo_dir -permissions 0311 -owner $macportsuser
        } else {
            file attributes $fifo_dir -permissions 0311
        }

        # Make sure the socket doesn't exist yet (this would cause errors
        # later)
        file delete -force $fifo

        # Create the server-side of the trace socket; this will handle requests
        # from the traced processed.
        create_slave $workpath $fifo

        # Launch darwintrace.dylib.
        set darwintracepath [file join ${portutil::autoconf::tcl_package_path} darwintrace1.0 darwintrace.dylib]

        # Add darwintrace.dylib as last entry in DYLD_INSERT_LIBRARIES
        if {[info exists env(DYLD_INSERT_LIBRARIES)] && [string length $env(DYLD_INSERT_LIBRARIES)] > 0} {
            set env(DYLD_INSERT_LIBRARIES) "${env(DYLD_INSERT_LIBRARIES)}:${darwintracepath}"
        } else {
            set env(DYLD_INSERT_LIBRARIES) ${darwintracepath}
        }
        # Tell traced processes where to find their communication socket back
        # to this code.
        set env(DARWINTRACE_LOG) $fifo

        # The sandbox is limited to:
        set trace_sandbox [list]

        # Allow work-, port-, and distpath
        allow trace_sandbox $workpath
        allow trace_sandbox $portpath
        allow trace_sandbox $distpath

        # Allow standard system directories
        allow trace_sandbox "/bin"
        allow trace_sandbox "/sbin"
        allow trace_sandbox "/dev"
        allow trace_sandbox "/usr/bin"
        allow trace_sandbox "/usr/sbin"
        allow trace_sandbox "/usr/include"
        allow trace_sandbox "/usr/lib"
        allow trace_sandbox "/usr/libexec"
        allow trace_sandbox "/usr/share"
        allow trace_sandbox "/System/Library"
        # Deny /Library/Frameworks, third parties install there
        deny  trace_sandbox "/Library/Frameworks"
        # But allow the rest of /Library
        allow trace_sandbox "/Library"

        # Allow a few configuration files
        allow trace_sandbox "/etc"

        # Allow temporary locations
        allow trace_sandbox "/tmp"
        allow trace_sandbox "/var/tmp"
        allow trace_sandbox "/var/folders"
        allow trace_sandbox "/var/empty"
        allow trace_sandbox "/var/run"
        if {[info exists env(TMPDIR)]} {
            set tmpdir [string trim $env(TMPDIR)]
            if {$tmpdir ne ""} {
                allow trace_sandbox $tmpdir
            }
        }

        # Allow timezone info & access to system certificates
        allow trace_sandbox "/var/db/timezone/zoneinfo"
        allow trace_sandbox "/var/db/mds/system"

        # Allow access to SDK if it's not inside the Developer folder.
        if {${configure.sdkroot} ne ""} {
            allow trace_sandbox "${configure.sdkroot}"
        }

        # Allow access to some Xcode specifics
        set xcode_paths {}
        lappend xcode_paths "/var/db/xcode_select_link"
        lappend xcode_paths "/var/db/mds"
        lappend xcode_paths [file normalize ~${macportsuser}/Library/Preferences/com.apple.dt.Xcode.plist]
        lappend xcode_paths "$env(HOME)/Library/Preferences/com.apple.dt.Xcode.plist"

        # Allow access to developer_dir; however, if it ends with /Contents/Developer, strip
        # that. If it doesn't leave that in place to avoid allowing access to "/"!
        set ddsplit [file split [file normalize [file join ${developer_dir} ".." ".."]]]
        if {[llength $ddsplit] > 2 && [lindex $ddsplit end-1] eq "Contents" && [lindex $ddsplit end] eq "Developer"} {
            set ddsplit [lrange $ddsplit 0 end-2]
        }
        lappend xcode_paths [file join {*}$ddsplit]

        set cltpath "/Library/Developer/CommandLineTools"
        if {[tbool use_xcode]} {
            foreach xcode_path $xcode_paths {
                allow trace_sandbox $xcode_path
            }
        } else {
            foreach xcode_path $xcode_paths {
                deny trace_sandbox $xcode_path
            }
        }

        # Allow launchd.db access to avoid failing on port-load(1)/port-unload(1)/port-reload(1)
        allow trace_sandbox "/var/db/launchd.db"

        # Deal with ccache
        allow trace_sandbox "$env(HOME)/.ccache"
        if {[info exists env(CCACHE_DIR)]} {
            set ccachedir [string trim $env(CCACHE_DIR)]
            if {$ccachedir ne ""} {
                allow trace_sandbox $ccachedir
            }
        }

        # Grant access to the directory we use to mirror binaries under SIP
        allow trace_sandbox ${portutil::autoconf::trace_sipworkaround_path}
        # Defer back to MacPorts for dependency checks inside $prefix. This must be at the end,
        # or it'll be used instead of more specific rules.
        ask trace_sandbox $prefix

        ui_debug "Tracelib Sandbox is:"
        foreach trace_entry $trace_sandbox {
            ui_debug "\t$trace_entry"
        }

        tracelib setsandbox [join $trace_sandbox :]
    }

    ##
    # Stop the running trace session and clean up the trace helper thread and
    # the communication socket. Just must call this once for each call to
    # trace_start.
    proc trace_stop {} {
        global env

        variable fifo

        foreach var {DYLD_INSERT_LIBRARIES DARWINTRACE_LOG} {
            array unset env $var
        }

        # Kill socket
        tracelib closesocket
        tracelib clean
        # Delete the socket file
        file delete -force $fifo
        file delete -force [file dirname $fifo]

        # Delete the slave.
        delete_slave
    }

    ##
    # Enable the sandbox. This is only called for targets that should be run
    # inside the sandbox.
    proc trace_enable_fence {} {
        tracelib enablefence
    }

    ##
    # Print a list of sandbox violations, separated into a list of files that
    # actually exist and were hidden, and a list of files that would have been
    # hidden, if they existed.
    #
    # Also print a list of files inside the MacPorts prefix that were not
    # installed by a port and thus not hidden, but might still cause
    # non-repeatable builds.
    #
    # This method must not be called before trace_start or after trace_stop.
    proc trace_check_violations {} {
        # Get the list of violations and print it; separate the list into existing
        # and non-existent files to cut down the noise.
        set violations [slave_send porttrace::slave_get_sandbox_violations]

        set existingFiles [list]
        set missingFiles  [list]
        foreach violation $violations {
            if {![catch {file lstat $violation _}]} {
                lappend existingFiles $violation
            } else {
                lappend missingFiles $violation
            }
        }

        set existingFilesLen [llength $existingFiles]
        if {$existingFilesLen > 0} {
            if {$existingFilesLen > 1} {
                ui_warn "The following existing files were hidden from the build system by trace mode:"
            } else {
                ui_warn "The following existing file was hidden from the build system by trace mode:"
            }
            foreach violation $existingFiles {
                ui_msg "  $violation"
            }
        }

        set missingFilesLen [llength $missingFiles]
        if {$missingFilesLen > 0} {
            if {$missingFilesLen > 1} {
                ui_info "The following files would have been hidden from the build system by trace mode if they existed:"
            } else {
                ui_info "The following file would have been hidden from the build system by trace mode if it existed:"
            }
            foreach violation $missingFiles {
                ui_info "  $violation"
            }
        }

        set unknowns [slave_send porttrace::slave_get_sandbox_unknowns]
        set existingUnknowns [list]
        foreach unknown $unknowns {
            if {![catch {file lstat $unknown _}]} {
                lappend existingUnknowns $unknown
            }
            # We don't care about files that don't exist inside MacPorts' prefix
        }

        set existingUnknownsLen [llength $existingUnknowns]
        if {$existingUnknownsLen > 0} {
            if {$existingUnknownsLen > 1} {
                ui_warn "The following files inside the MacPorts prefix not installed by a port were accessed:"
            } else {
                ui_warn "The following file inside the MacPorts prefix not installed by a port was accessed:"
            }
            foreach unknown $existingUnknowns {
                ui_msg "  $unknown"
            }
        }
    }

    ##
    # Create a thread that will contain the server-side of a macports trace
    # mode setup. This part of the code (most of it actually implemented in
    # pextlib1.0/tracelib.c) will create a Unix socket that all traced
    # processes will initially connect to to get the sandbox bounds. It will
    # also handle requests for dependency checks from traced processes and
    # provide the appropriate answers to the client and track sandbox
    # violations.
    #
    # You must call delete_slave to clean up the data structures associated
    # with this slave thread.
    #
    # @param workpath The workpath of this installation
    # @param fifo The Unix socket name to be created
    proc create_slave {workpath fifo} {
        global prefix developer_dir registry.path
        variable thread

        # Create the thread.
        set thread [macports_create_thread]

        # The slave thread needs this file and macports 1.0
        thread::send $thread "package require porttrace 1.0"
        thread::send $thread "package require macports 1.0"

        # slave needs ui_{info,warn,debug,error}...
        # make sure to sync this with ../pextlib1.0/tracelib.c!
        thread::send $thread "macports::ui_init debug"
        thread::send $thread "macports::ui_init info"
        thread::send $thread "macports::ui_init warn"
        thread::send $thread "macports::ui_init error"

        # and these variables
        thread::send $thread "set prefix \"$prefix\"; set developer_dir \"$developer_dir\""
        # The slave thread requires the registry package.
        thread::send $thread "package require registry 1.0"
        # and an open registry
        thread::send $thread "registry::open [file join ${registry.path} registry registry.db]"

        # Initialize the slave
        thread::send $thread "porttrace::slave_init $fifo $workpath"

        # Run slave asynchronously
        thread::send -async $thread "porttrace::slave_run"
    }

    ##
    # Initialize the slave thread. This is the first user code called in the
    # thread after creating it and setting it up.
    #
    # @param fifo The path of the Unix socket that should be created by
    #             tracelib
    # @param p_workpath The workpath of the current installation
    proc slave_init {fifo p_workpath} {
        variable sandbox_violation_list
        variable sandbox_unknown_list

        # Save the workpath.
        set workpath $p_workpath

        # Initialize the sandbox violation lists
        set sandbox_violation_list {}
        set sandbox_unknown_list {}

        # Create the socket
        tracelib setname $fifo
        tracelib opensocket
    }

    ##
    # Actually start the server component that will deal with requests from
    # trace mode clients. This will occupy the thread until a different thread
    # calls tracelib closesocket or tracelib clean.
    proc slave_run {} {
        tracelib run
    }

    ##
    # Destroy the slave thread. You must call this once for each call to
    # create_slave.
    proc delete_slave {} {
        variable thread

        # Destroy the thread.
        thread::release $thread
    }

    ##
    # Send a command to the trace thread created by create_slave, wait for its
    # completion and return its result. The behavior of this proc is undefined
    # when called before create_slave or after delete_slave.
    #
    # @param command The Tcl command to be executed in the trace thread
    # @return The return value of the Tcl command, executed in the trace thread
    proc slave_send {command} {
        variable thread

        if {[thread::send $thread "$command" result]} {
            return -code error "thread::send \"$command\" failed: $result"
        }
        return $result
    }

    ##
    # Return a list of sandbox violations stored in the trace server thread.
    #
    # @return List of files that the traced processed tried to access but were
    #         outside the sandbox bounds.
    proc slave_get_sandbox_violations {} {
        variable sandbox_violation_list

        return $sandbox_violation_list
    }

    ##
    # Add a sandbox violation. This is called directly from
    # pextlib1.0/tracelib.c. You won't find calls to this method in Tcl code.
    #
    # @param path The path of the file that a traced process tried to access
    #             but violated the sandbox bounds.
    proc slave_add_sandbox_violation {path} {
        variable sandbox_violation_list

        sorted_list_insert sandbox_violation_list $path
    }

    ##
    # Return a list of files accessed inside the MacPorts prefix but not
    # registered to any port.
    #
    # @return List of files that the traced processed tried to access but
    #         couldn't be matched to a port by MacPorts.
    proc slave_get_sandbox_unknowns {} {
        variable sandbox_unknown_list

        return $sandbox_unknown_list
    }

    ##
    # Track an access to a file within the MacPorts prefix that MacPorts
    # doesn't know about. This is called directly from pextlib1.0/tracelib.c.
    # You won't find calls to this method in Tcl code.
    #
    # @param path The path of the file that a traced process tried to access
    #             inside the MacPorts prefix, but MacPorts couldn't match to
    #             a port.
    proc slave_add_sandbox_unknown {path} {
        variable sandbox_unknown_list

        sorted_list_insert sandbox_unknown_list $path
    }

    ##
    # Insert an element into a sorted list, keeping the list sorted. If the
    # element is already present in the list, do nothing. This should run in
    # O(log n) to be useful.
    proc sorted_list_insert {listname element} {
        upvar $listname l

        set rboundary [llength $l]
        set lboundary 0

        while {[set distance [expr {$rboundary - $lboundary}]] > 0} {
            set index [expr {$lboundary + ($distance / 2)}]

            set cmp [string compare $element [lindex $l $index]]
            if {$cmp == 0} {
                # element already present, do nothing
                return
            } elseif {$cmp < 0} {
                # continue left
                set rboundary $index
            } else {
                # continue right
                set lboundary [expr {$index + 1}]
            }
        }

        # we're at the end, lets insert here
        set l [linsert $l $lboundary $element]
    }
}
