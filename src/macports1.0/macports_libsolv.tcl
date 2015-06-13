# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# macports_libsolv.tcl
# $Id$
#
# Copyright (c) 2015 Jackson Isaac <ijackson@macports.org>
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
#

package provide macports_libsolv 1.0
package require macports 1.0
# Load solv.dylib, bindings for libsolv
package require solv

## Testing solv.dylib
#global solv::Job_SOLVER_SOLVABLE


#set pool [solv::Pool]
#puts $pool

namespace eval macports::libsolv {

    ## Variable to keep check if libsolv cache is created or not.
    variable libsolv_pool

    ## Variable for pool
    variable pool

    proc print {} {
        variable libsolv_pool
        puts $solv::Job_SOLVER_SOLVABLE
        puts $libsolv_pool
    }

    proc create_pool {} {
        variable libsolv_pool
        variable pool

        if {![info exists libsolv_pool]} {
            global macports::sources
            set matches [list]

            set pool [solv::Pool]

            foreach source $sources {
                set source [lindex $source 0]
                set repo [$pool add_repo $source]
                set solvable [$repo add_solvable]
 
                if {[catch {set fd [open [macports::getindex $source] r]} result]} {
                    ui_warn "Can't open index file for source: $source"
                } else {
                    try {
                        #incr found 1
                        while {[gets $fd line] >= 0} {
                            #puts $line
                            array unset portinfo
                            set name [lindex $line 0]
                            set len  [lindex $line 1]
                            set line [read $fd $len]
                            
                            #puts "\nname = ${name}\n" 
                            $solvable configure -name $name
                            #puts [$solvable cget -name]
                        }
                    }
                }
            }
            set libsolv_pool ${pool}
            puts $libsolv_pool
        } else {
            return {}
        }
    }

    proc search {pattern} {
        # Search using libsolv
        # puts "pattern = $pattern"
        # global macports::libsolv::pool
        variable pool

        set sel [$pool Selection]
        #set di [$pool Dataiterator $solv::SOLVABLE_NAME $pattern [expr $solv::Dataiterator_SEARCH_SUBSTRING | $solv::Dataiterator_SEARCH_NOCASE]]
        #puts [$pool Dataiterator $solv::SOLVABLE_NAME $pattern [expr $solv::Dataiterator_SEARCH_SUBSTRING | $solv::Dataiterator_SEARCH_NOCASE]]
       
        #puts [$di __next__ ]

        foreach data [$pool Dataiterator $solv::SOLVABLE_NAME $pattern [expr $solv::Dataiterator_SEARCH_SUBSTRING | $solv::Dataiterator_SEARCH_NOCASE]] {
        #while {[$di __next__] ne "NULL"}  
            puts "data = $data"
            $sel add_raw $solv::Job_SOLVER_SOLVABLE $data::solvid
        }

        foreach s [$sel solvables] {
            puts "solvable = $s"
        }
        
        #puts $res

        #if {[info exists res]} {
        #    puts "$pattern found by libsolv"
        #} else {
        #    puts "$pattern not found by libsolv"
        #}
    }
}
