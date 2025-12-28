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
    variable timeout_script_template {if {![info exists %s]} {set %s timeout}}

    # Management thread code
    variable init_script {
        package require Thread
        package require Pextlib

        # Worker thread code
        set worker_init_script {
            package require Thread
            package require Pextlib

            proc progress_handler {action args} {
                global progress_tid
                switch -- $action {
                    debug -
                    notice {
                        thread::send -async $progress_tid [list ui_${action} {*}$args]
                    }
                    default {
                        global show_progress
                        if {$show_progress} {
                            global progress_inited
                            if {!$progress_inited} {
                                global current_url
                                thread::send -async $progress_tid [list ui_notice "Attempting to fetch $current_url"]
                                thread::send -async $progress_tid [list ui_progress_download start]
                                set progress_inited 1
                            }
                            thread::send -async $progress_tid [list ui_progress_download $action {*}$args]
                        }
                    }
                }
            }

            # Perform a curl-based operation and return the result.
            # Result format: 2 element list: status, body
            # status = 0: success, body is the actual result
            # status = 1: error, body is error message
            proc do_curl {op opargs result_tid result_var} {
                global management_tid
                set result {}
                try {
                    global ::pextlib::curl::cancelled
                    set cancelled 0
                    # Tell client which thread is handling this request, so it can send
                    # cancellation requests.
                    thread::send -async $result_tid [list set ${result_var}_tid [thread::id]]
                    switch -- $op {
                        archive_exists {
                            # Check if an archive and matching signature exist at
                            # any of the given URLs.
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
                                if {$cancelled} {
                                    break
                                }
                            }
                        }
                        fetch_archive {
                            # Try fetching an archive and signature from the given URLs,
                            # saving the results to outpath, until one of them succeeds.
                            global show_progress progress_tid progress_inited current_url
                            # Start silent, may be changed during the transfer.
                            set show_progress 0
                            set progress_inited 0
                            set progress_tid $result_tid
                            lassign $opargs fixed_args credential_args urls outpath sigtypes maxfails
                            set archive_fetched 0
                            set sig_fetched 0
                            set failed_sites 0
                            foreach url $urls creds $credential_args {
                                if {!$archive_fetched} {
                                    try {
                                        if {$show_progress} {
                                            progress_handler notice "Attempting to fetch $url"
                                        } else {
                                            set current_url $url
                                        }
                                        curl fetch --progress progress_handler {*}$creds {*}$fixed_args $url ${outpath}.TMP
                                        set archive_fetched 1
                                    } on error {eMessage} {
                                        progress_handler debug "Fetching $url failed: $eMessage"
                                        set result [list 1 $eMessage]
                                        incr failed_sites
                                        if {$cancelled || ($maxfails > 0 && $failed_sites >= $maxfails)} {
                                            break
                                        }
                                    }
                                }
                                if {$archive_fetched} {
                                    # fetch signature
                                    foreach sigtype $sigtypes {
                                        set sigurl ${url}.${sigtype}
                                        set signature ${outpath}.${sigtype}
                                        try {
                                            if {$show_progress} {
                                                progress_handler notice "Attempting to fetch $sigurl"
                                            } else {
                                                set current_url $sigurl
                                            }
                                            curl fetch --progress progress_handler {*}$creds {*}$fixed_args $sigurl $signature
                                            set sig_fetched 1
                                            set fetched_sigtype $sigtype
                                            set result [list 0 1]
                                            break
                                        } on error {eMessage} {
                                            progress_handler debug "Fetching $sigurl failed: $eMessage"
                                            set result [list 1 $eMessage]
                                            if {$cancelled} {
                                                break
                                            }
                                        }
                                    }
                                    if {$sig_fetched} {
                                        break
                                    }
                                }
                                if {$cancelled} {
                                    break
                                }
                            }
                            foreach sigtype $sigtypes {
                                if {!$sig_fetched || $sigtype ne $fetched_sigtype} {
                                    catch {file delete ${outpath}.${sigtype}}
                                }
                            }
                            if {!$archive_fetched} {
                                catch {file delete ${outpath}.TMP}
                            }
                        }
                        fetch_file {
                            # Try fetching the given URLs, saving the result to outpath, until
                            # one of them succeeds.
                            global show_progress progress_tid progress_inited current_url
                            # Start silent, may be changed during the transfer.
                            set show_progress 0
                            set progress_inited 0
                            set progress_tid $result_tid
                            lassign $opargs fixed_args credential_args urls outpath
                            set fetched 0
                            foreach url $urls creds $credential_args {
                                try {
                                    if {$show_progress} {
                                        progress_handler notice "Attempting to fetch $url"
                                    } else {
                                        set current_url $url
                                    }
                                    curl fetch --progress progress_handler {*}$creds {*}$fixed_args $url ${outpath}.TMP
                                    set fetched 1
                                    set result [list 0 1]
                                    break
                                } on error {eMessage} {
                                    progress_handler debug "Fetching $url failed: $eMessage"
                                    set result [list 1 $eMessage]
                                    if {$cancelled} {
                                        break
                                    }
                                }
                            }
                            if {!$fetched} {
                                catch {file delete ${outpath}.TMP}
                            }
                        }
                        default {
                            error "Unhandled curl op: $op"
                        }
                    }
                } on error {err} {
                    set result [list 1 $err]
                } finally {
                    # Set the result in the thread that wants it
                    thread::send -async $result_tid [list set $result_var $result]
                    # Tell the management thread we're done
                    set was_fetch [expr {$op in {fetch_archive fetch_file}}]
                    thread::send -async $management_tid [list thread_done [thread::id] $was_fetch]
                }
            }

            thread::wait
        }
        # End worker_init_script

        if {![catch {sysctl hw.activecpu} ncpus]} {
            set max_threads [expr {$ncpus * 2}]
        } else {
            set max_threads 8
        }
        set available_threads [list]
        set thread_count 0
        set fetch_count 0

        # Worker threads call this when they have completed a job
        proc thread_done {tid was_fetch} {
            global available_threads
            lappend available_threads $tid
            if {$was_fetch} {
                global fetch_count
                incr fetch_count -1
            }
        }

        # Return the ID of a thread that is available for use, or an empty
        # string if no threads are available. Creates new threads up to the
        # maximum if needed.
        proc get_available_thread {} {
            global available_threads
            # Look for an idle thread.
            if {[llength $available_threads] > 0} {
                set free_tid [lindex $available_threads end]
                set available_threads [lreplace $available_threads end end]
                return $free_tid
            }
            # Create a new thread if possible.
            global max_threads thread_count
            if {$thread_count < $max_threads} {
                global worker_init_script
                set free_tid [thread::create -preserved $worker_init_script]
                thread::send -async $free_tid [list set management_tid [thread::id]]
                incr thread_count
                return $free_tid
            }
            return {}
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
            global request_queue main_wakeup max_fetches fetch_count
            while {1} {
                for {set i 0} {$i < [llength $request_queue]} {incr i} {
                    lassign [lindex $request_queue $i] op opargs result_tid result_var
                    set limit_concurrency [expr {$op in {fetch_archive fetch_file}}]
                    if {$limit_concurrency && $fetch_count >= $max_fetches} {
                        # Theoretically there could be other op types further back in the queue that we could
                        # still dispatch, but that's unlikely in practice since fetching happens last.
                        break
                    }
                    set tid [get_available_thread]
                    if {$tid eq {}} {
                        break
                    }
                    if {$limit_concurrency} {
                        incr fetch_count
                    }
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
    global macports::fetch_threads
    set max_fetches [expr {[info exists fetch_threads] && $fetch_threads > 1 ? $fetch_threads : 1}]
    thread::send -async $management_thread [list set max_fetches $max_fetches]
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
        unset -nocomplain $id ${id}_tid
        macports::check_signals
        return $result
    } else {
        error "No pending request with id $id"
    }
}

# Return true if a result is available for the operation identified by
# id, false otherwise. If timeout is > 0, wait up to that many ms for
# the result to become available before returning.
proc mport_fetch_thread::is_complete {id {timeout 0}} {
    variable active_requests
    if {[dict exists $active_requests $id]} {
        variable $id
        if {![info exists $id]} {
            if {$timeout > 0} {
                variable timeout_script_template
                set timeout_script [string map [list %s $id] \
                    $timeout_script_template]
                set timeout_eventid [after $timeout $timeout_script]
                vwait $id
                if {[set $id] eq "timeout"} {
                    unset $id
                } else {
                    after cancel $timeout_eventid
                }
            } else {
                update
            }
            macports::check_signals
        }
        return [info exists $id]
    } else {
        error "No pending request with id $id"
    }
}

# Start displaying progress for the operation identified by id.
proc mport_fetch_thread::show_progress {id} {
    variable active_requests
    if {![dict exists $active_requests $id]} {
        error "No pending request with id $id"
    }
    variable ${id}_tid
    if {![info exists ${id}_tid]} {
        # Wait for the worker thread to tell us its id
        vwait ${id}_tid
        macports::check_signals
    }
    thread::send -async [set ${id}_tid] [list set show_progress 1]
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
        unset -nocomplain $id ${id}_tid
        return
    }
    # Try to remove it from the queue
    variable management_thread
    set was_unqueued [thread::send $management_thread [list unqueue_request $id]]
    if {$was_unqueued} {
        return
    }
    # Already dispatched. Send cancellation request and wait for the result
    # (so we can clean up the result variable)
    variable ${id}_tid
    if {![info exists ${id}_tid]} {
        # Wait for the worker thread to tell us its id
        vwait ${id}_tid
    }
    thread::send [set ${id}_tid] [list set ::pextlib::curl::cancelled 1]
    if {![info exists $id]} {
        vwait $id
    }
    unset -nocomplain $id ${id}_tid
    macports::check_signals
}
