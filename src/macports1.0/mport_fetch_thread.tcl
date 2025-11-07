# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2025 The MacPorts Project
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of The MacPorts Project nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

package provide mport_fetch_thread 1.0

package require Thread

##
# Main thread side
##

namespace eval mport_fetch_thread {
    variable active_requests [dict create]
    variable next_id 0
    variable management_thread
    trace add variable management_thread read mport_fetch_thread::init_management_thread

    # Management thread code
    variable init_script {
        package require Thread
        package require Pextlib

        # Worker thread code
        set worker_init_script {
            package require Thread
            package require Pextlib

            # Perform a curl-based operation and return the result.
            # Result format: 2 element list: status, body
            # status = 0: success, body is the actual result
            # status = 1: error, body is error message
            proc do_curl {op opargs result_tid result_var} {
                global management_thread
                set result {}
                try {
                    switch -- $op {
                        # Check if an archive and matching signature exist at
                        # any of the given URLs.
                        archive_exists {
                            set result [list 0 0]
                            lassign $opargs fixed_args credential_args urls
                            foreach {url sigurl} $urls {creds sigcreds} $credential_args {
                                # curl getsize can return -1 instead of throwing an error for
                                # nonexistent files on FTP sites.
                                if {![catch {curl getsize {*}$creds {*}$fixed_args $url} size] && $size > 0
                                      && ![catch {curl getsize {*}$sigcreds {*}$fixed_args $sigurl} sigsize] && $sigsize > 0} {
                                    set result [list 0 1]
                                    break
                                }
                            }
                        }
                        default {
                            error "Unhandled curl op: $op"
                        }
                    }
                } on error {err} {
                    set result [list 1 $err]
                }
                tsv::set mport_fetch_thread::thread_busy [thread::id] 0
                # Set the result in the thread that wants it
                thread::send -async $result_tid [list set $result_var $result]
            }

            thread::wait
        }
        # End worker_init_script

        proc init_max_threads {} {
            global max_threads
            if {![catch {sysctl hw.activecpu} ncpus]} {
                set max_threads [expr {$ncpus * 2}]
            } else {
                set max_threads 8
            }
        }
        init_max_threads

        set active_threads [dict create]

        # Return the ID of a thread that is available for use, or an empty
        # string if no threads are available. Creates new threads up to the
        # maximum if needed.
        proc get_available_thread {} {
            global active_threads
            set free_tid {}
            # See if any threads in the list have completed - those nearer the
            # start were started first and so more likely to be free.
            foreach tid [dict keys $active_threads] {
                if {[tsv::get mport_fetch_thread::thread_busy $tid] != 1} {
                    # Unset so it goes to the end of the list
                    dict unset active_threads $tid
                    set free_tid $tid
                    break
                }
            }
            if {$free_tid eq {}} {
                # Create a new thread if possible.
                global max_threads
                if {[dict size $active_threads] < $max_threads} {
                    global worker_init_script
                    set free_tid [thread::create -preserved $worker_init_script]
                    thread::send -async $free_tid [list set management_thread [thread::id]]
                }
            }

            if {$free_tid ne {}} {
                # Add thread to the active list and mark as busy.
                dict set active_threads $free_tid 1
                tsv::set mport_fetch_thread::thread_busy $free_tid 1
            }
            return $free_tid
        }

        set request_queue [list]
        set main_wakeup {}

        # Add a request to the queue and arrange for the main loop to
        # wake up and process it.
        proc queue_request {op opargs result_tid result_var} {
            global request_queue main_wakeup
            lappend request_queue [list $op $opargs $result_tid $result_var]
            set main_wakeup 1
        }

        # Remove a request from the queue.
        # Returns 1 if the request was in the queue, 0 otherwise.
        proc unqueue_request {id} {
            global request_queue
            set index [lsearch -exact -dictionary -sorted -index 3 $request_queue $id]
            if {$index != -1} {
                set request_queue [lreplace ${request_queue}[set request_queue {}] $index $index]
                return 1
            }
            return 0
        }

        # Main event loop for the management thread. Dispatches queued requests
        # and handles results of completed ones. Wakes up whenever a thread
        # completes its task or a new request is queued.
        proc main {} {
            global request_queue main_wakeup
            while {1} {
                for {set i 0} {$i < [llength $request_queue]} {incr i} {
                    set tid [get_available_thread]
                    if {$tid eq {}} {
                        break
                    }
                    set req [lindex $request_queue $i]
                    lassign $req op opargs result_tid result_var
                    thread::send -async $tid [list do_curl $op $opargs $result_tid $result_var] main_wakeup
                }
                if {$i > 0} {
                    set request_queue [lrange $request_queue $i end]
                }
                vwait main_wakeup
            }
        }

        main
    }
    # End init_script
}

# Lazy init for management thread
proc mport_fetch_thread::init_management_thread {args} {
    variable management_thread
    trace remove variable management_thread read mport_fetch_thread::init_management_thread
    variable init_script
    set management_thread [thread::create -preserved $init_script]
}

# Queue a fetch operation to be performed on a thread in the background.
# Returns an id that can be used with the get_result command.
proc mport_fetch_thread::queue {op opargs} {
    variable next_id
    set result_name fetchreq$next_id
    incr next_id
    variable $result_name
    set id [namespace which -variable $result_name]
    variable management_thread
    thread::send -async $management_thread [list queue_request $op $opargs [thread::id] $id]
    variable active_requests
    dict set active_requests $id 1
    return $id
}

# Get the result of the operation identified by id, waiting until it
# is complete first if needed.
proc mport_fetch_thread::get_result {id} {
    variable active_requests
    if {[dict exists $active_requests $id]} {
        dict unset active_requests $id
        variable $id
        if {![info exists $id]} {
            vwait $id
        }
        set result [set $id]
        unset $id
        return $result
    } else {
        error "No pending request with id $id"
    }
}

# Cancel the operation identified by id.
proc mport_fetch_thread::cancel {id} {
    variable active_requests
    if {![dict exists $active_requests $id]} {
        # Not in progress, guess it's fine?
        return
    }
    dict unset active_requests $id
    variable $id
    if {[info exists $id]} {
        # Already complete
        unset $id
        return
    }
    # Try to remove it from the queue
    variable management_thread
    set was_unqueued [thread::send $management_thread [list unqueue_request $id]]
    if {$was_unqueued} {
        return
    }
    # Already dispatched. thread::cancel is tricky, so just wait for the result
    # (so we can clean up the result variable)
    if {![info exists $id]} {
        vwait $id
    }
    unset $id
}
