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

namespace eval macports::libsolv {

    ## Variable for pool
    variable pool

    ## Variable for portindexinfo
    variable portindexinfo

    ## Some debugging related printing of variable contents
    proc print {} {
        variable pool
        puts $solv::Job_SOLVER_SOLVABLE
        puts $pool
        
        set si [$pool cget -solvables]
        puts "-------Printing Pool solvables------"
        while {[set s [$si __next__]] ne "NULL"} {
            puts "$s: [$s __str__]"
        }
    }

    ## Procedure to create the libsolv pool. This is similar to PortIndex. \
    #  Read the PortIndex contents and write into libsolv readable solv's.
    #  To Do:
    #  Add additional information regarding arch, vendor, dependency, etc to solv.
    #  Done:
    #  Add epoch, version and revision to each solv.
    #  Add more info to solv about its description, long_description, license, category and homepage.
    proc create_pool {} {
        variable pool
        variable portindexinfo

        ## Check if libsolv cache (pool) is already created or not.
        if {![info exists pool]} {
            global macports::sources

            ## Create a new pool instance by calling Pool contructor.
            set pool [solv::Pool]

            foreach source $sources {
                set source [lindex $source 0]
                ## Add a repo in the pool for each source as mentioned in sources.conf
                set repo [$pool add_repo $source]
                set repodata [$repo add_repodata]
 
                if {[catch {set fd [open [macports::getindex $source] r]} result]} {
                    ui_warn "Can't open index file for source: $source"
                } else {
                    try {
                        while {[gets $fd line] >= 0} {
                            # Create a solvable for each port processed.
                            set solvable [$repo add_solvable]

                            ## Clear the portinfo contents to prevent attribute leak \
                            #  from previous iterations
                            array unset portinfo
                            set name [lindex $line 0]
                            set len  [lindex $line 1]
                            set line [read $fd $len]
                            
                            array set portinfo $line

                            $solvable configure -name $name \
                            -evr "$portinfo(epoch)@$portinfo(version)-$portinfo(revision)" \
                            -arch "i386"

                            set solvid [$solvable cget -id]

                            ## Add extra info to repodata i.e. Summary, Description, etc to the solvables
                            #  Valid constant fields can be found at src/knownid.h of libsolv.
                            if {[info exists portinfo(description)]} {
                                $repodata set_str $solvid $solv::SOLVABLE_SUMMARY $portinfo(description)
                            }
                            if {[info exists portinfo(long_description)]} {
                                $repodata set_str $solvid $solv::SOLVABLE_DESCRIPTION $portinfo(long_description)
                            }
                            if {[info exists portinfo(license)]} {
                                $repodata set_str $solvid $solv::SOLVABLE_LICENSE $portinfo(license)
                            }
                            if {[info exists portinfo(homepage)]} {
                                $repodata set_str $solvid $solv::SOLVABLE_URL $portinfo(homepage)
                            }
                            if {[info exists portinfo(categories)]} {
                                $repodata set_str $solvid $solv::SOLVABLE_CATEGORY $portinfo(categories)
                            }
                            ## Add dependency information to solvable using portinfo
                            #  $marker i.e last arg to add_deparray is set to 1 for build dependencies
                            #  and -1 for runtime dependencies
                            ## Add Build dependencies:
                            if {[info exists portinfo(depends_fetch)]} {
                                foreach dep $portinfo(depends_fetch) {
                                    set dep_name [lindex [split $dep :] end]
                                    $solvable add_deparray $solv::SOLVABLE_REQUIRES \
                                    [$pool str2id $dep_name 1] 1
                                }
                            }
                            if {[info exists portinfo(depends_extract)]} {
                                foreach dep $portinfo(depends_extract) {
                                    set dep_name [lindex [split $dep :] end]
                                    $solvable add_deparray $solv::SOLVABLE_REQUIRES \
                                    [$pool str2id $dep_name 1] 1
                                }
                            }
                            if {[info exists portinfo(depends_build)]} {
                                foreach dep $portinfo(depends_build) {
                                    set dep_name [lindex [split $dep :] end]
                                    $solvable add_deparray $solv::SOLVABLE_REQUIRES \
                                    [$pool str2id $dep_name 1] 1
                                }
                            }
                            ## Add Runtime dependencies
                            if {[info exists portinfo(depends_lib)]} {
                                foreach dep $portinfo(depends_lib) {
                                    set dep_name [lindex [split $dep :] end]
                                    $solvable add_deparray $solv::SOLVABLE_REQUIRES \
                                    [$pool str2id $dep_name 1] -1
                                }
                            }
                            if {[info exists portinfo(depends_run)]} {
                                foreach dep $portinfo(depends_run) {
                                    set dep_name [lindex [split $dep :] end]
                                    $solvable add_deparray $solv::SOLVABLE_REQUIRES \
                                    [$pool str2id $dep_name 1] -1
                                }
                            }
                            ## Add Conflicts to the solvables
                            if {[info exists portinfo(conflicts)]} {
                                foreach conf $portinfo(conflicts) {
                                    $solvable add_deparray $solv::SOLVABLE_CONFLICTS \
                                    [$pool str2id $conf 1]
                                }
                            }
                            ## Add Obsoletes(replaced_by) to the solvables
                            if {[info exists portinfo(replaced_by)]} {
                                foreach conf $portinfo(replaced_by) {
                                    $solvable add_deparray $solv::SOLVABLE_OBSOLETES \
                                    [$pool str2id $conf 1]
                                }
                            }

                            ## Set portinfo of each solv object. Map it to correct solvid.
                            set portindexinfo([$solvable cget -id]) $line
                        }

                    } catch * {
                        ui_warn "It looks like your PortIndex file for $source may be corrupt."
                        throw
                    } finally {
                        ## Internalize should be run on the repodata so that the extra info \
                        #  is available for lookup and dataiterator functions. Do this after\
                        #  all the solvables are added to repo as it is a costly operation.
                        $repodata internalize
                        close $fd
                    }
                }
            }
            ## createwhatprovides creates hash over all the provides of the package \
            #  This method is necessary before we can run any lookups on provides.
            $pool createwhatprovides
        } else {
            return {}
        }
    }

    ## Search using libsolv. Needs some more work.
    #  To Do list:
    #  Add support for searching in License and other fields too. Some changes to be made port.tcl to
    #  support these options to be passed i.e. --license
    #  Done:
    #  Add support for search options i.e. --exact, --case-sensitive, --glob, --regex.
    #  Return portinfo to mportsearch which will pass the info to port.tcl to print results.
    #  Add more info to the solv's to search into more details of the ports (description, \
    #  homepage, category, etc.
    proc search {pattern {case_sensitive yes} {matchstyle regexp} {field name}} {
        variable pool
        variable portindexinfo

        set matches [list]
        set sel [$pool Selection]
        variable search_option
       
        ## Initialize search option flag depending on the option passed to port search
        switch -- $matchstyle {
            exact {
                set di_flag $solv::Dataiterator_SEARCH_STRING
            }
            glob {
                set di_flag $solv::Dataiterator_SEARCH_GLOB
            }
            regexp {
                set di_flag $solv::Dataiterator_SEARCH_REGEX
            }
            default {
                return -code error "Libsolv search: Unsupported matching style: ${matchstyle}."
            }
        }

        ## If --case-sensitive is not passed, Binary OR "|" with no_case flag.
        if {!${case_sensitive}} {
            set di_flag [expr $di_flag | $solv::Dataiterator_SEARCH_NOCASE]
        }

        ## Set options for search. Binary OR the $search_option to lookup more fields.
        switch -- $field {
            name {
                set search_option $solv::SOLVABLE_NAME
            }
            description {
                set search_option $solv::SOLVABLE_SUMMARY
            } 
            long_description {
                set search_option $solv::SOLVABLE_DESCRIPTION
            } 
            homepage {
                set search_option $solv::SOLVABLE_URL
            } 
            categories {
                set search_option $solv::SOLVABLE_CATEGORY
            }
            default {
                return -code error "Libsolv search: Unsupported field: ${field}."
            }
        }
        
        set di [$pool Dataiterator $search_option $pattern $di_flag]

        while {[set data [$di __next__]] ne "NULL"} { 
            $sel add_raw $solv::Job_SOLVER_SOLVABLE [$data cget -solvid]
        }

        ## This prints all the solvable's information that matched the pattern.
        foreach s [$sel solvables] {
            ## Print information about mathed solvable on debug option.
            ui_debug "solvable = [$s __str__]"
            ui_debug "summary = [$s lookup_str $solv::SOLVABLE_SUMMARY]"
            ui_debug "description = [$s lookup_str $solv::SOLVABLE_DESCRIPTION]"
            ui_debug "license = [$s lookup_str $solv::SOLVABLE_LICENSE]"
            ui_debug "URL = [$s lookup_str $solv::SOLVABLE_URL]"
            ui_debug "category = [$s lookup_str $solv::SOLVABLE_CATEGORY]"

            lappend matches [$s cget -name]
            lappend matches $portindexinfo([$s cget -id])
        }

        return $matches
    }

    ## Dependency calculation using libsolv
    proc dep_calc {portname} {
        ui_msg -nonewline "$macports::ui_prefix Computing dependencies for $portname using libsolv"
        set jobs [list]
        foreach arg $portname {
            lappend jobs [$solv::pool_Job $solv::Job_SOLVER_SOLVABLE [$arg cget -id]]
            puts "Jobs = $jobs"
        }
    }
}
