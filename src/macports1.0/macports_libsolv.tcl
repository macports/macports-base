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

    ## Variable to track registry changes.
    variable regupdate

    ## Some debugging related printing of variable contents
    proc print {} {
        set pool [create_pool]
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
        
        ## set fields for adding dependency information to the solv's by looping over $fields.
        set fields [list]
        lappend fields "depends_fetch" $solv::SOLVABLE_REQUIRES [list]
        lappend fields "depends_extract" $solv::SOLVABLE_REQUIRES [list]
        lappend fields "depends_build" $solv::SOLVABLE_REQUIRES [list]
        lappend fields "depends_lib" $solv::SOLVABLE_REQUIRES [list]
        lappend fields "depends_run" $solv::SOLVABLE_REQUIRES [list]
        lappend fields "conflicts" $solv::SOLVABLE_CONFLICTS [list]
        lappend fields "replaced_by" $solv::SOLVABLE_OBSOLETES [list]

        ## Check if libsolv cache (pool) is already created or not.
        if {![info exists pool]} {
            global macports::sources

            ## Create a new pool instance by calling Pool contructor.
            set pool [solv::Pool]
            ## Repo for installed ports
            set repo_installed [$pool add_repo "installed"]

            ## Create a list of installed ports by reading registry::installed.
            array set installed_ports [list]
            try {
                foreach installed [registry::installed] {
                    lassign $installed name version revision variants active epoch
                    if {$active != 0} {
                        set installed_ports($name,$epoch,$version,$revision) $installed
                    }
                }
            } catch * {
                ui_warn "No installed ports found in registry"
            }
            
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
                            ## Clear the portinfo contents to prevent attribute leak \
                            #  from previous iterations
                            array unset portinfo
                            set name [lindex $line 0]
                            set len  [lindex $line 1]
                            set line [read $fd $len]
                            
                            array set portinfo $line

                            # Create a solvable for each port processed.
                            # If the port is already installed add it to $repo_installed. Also add it to $repo
                            if {[info exists installed_ports($name,$portinfo(epoch),$portinfo(version),$portinfo(revision))]} {
                                    set solvable [$repo_installed add_solvable]
                            } else {
                                set solvable [$repo add_solvable]
                            }
                            # set solvable [$repo add_solvable]

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
                            foreach {fieldname deptype marker} $fields {
                                if {[info exists portinfo($fieldname)]} {
                                    foreach dep $portinfo($fieldname) {
                                        set dep_name [lindex [split $dep :] end]
                                        $solvable add_deparray $deptype [$pool str2id $dep_name 1] {*}$marker
                                    }
                                }
                            }

                            ## Set SOLVABLE_PROVIDES for the solv so that the package can be found during depcalc.
                            set provides [$pool rel2id [$solvable cget -nameid] [$solvable cget -evrid] $solv::REL_EQ 1]
                            $solvable add_deparray $solv::SOLVABLE_PROVIDES $provides
                            
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
                        $pool configure -installed $repo_installed
                        close $fd
                    }
                }
            }
            ## createwhatprovides creates hash over all the provides of the package \
            #  This method is necessary before we can run any lookups on provides.
            $pool createwhatprovides
    
            return $pool
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
        set pool [create_pool]
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
    proc dep_calc {portlist} {
        set pool [create_pool]
        # $pool set_debuglevel 3
        
        ## List of ports to be installed
        set portname [list]
        ## Append portname to $portname after extracting them from $portlist
        foreach portspec $portlist {
            array set portinfo $portspec
            set pname $portinfo(name)
            lappend portname $pname
            array unset -nocomplain portinfo
        }

        ui_msg "$macports::ui_prefix Computing dependencies for $portname using libsolv"
        set jobs [list]
        foreach arg $portname {
            set portid [$pool str2id $portname]
            set flags [expr $solv::Selection_SELECTION_NAME | $solv::Selection_SELECTION_PROVIDES \
                | $solv::Selection_SELECTION_CANON | $solv::Selection_SELECTION_DOTARCH \
                | $solv::Selection_SELECTION_REL]
            set sel [$pool select $arg $flags]
            
            ## If selection is empty, try with NOCASE.
            if {[$sel isempty]} {
                set sel [$pool select $arg [expr $flags | $solv::Selection_SELECTION_NOCASE]]
            }

            ## Append the list of jobs from selection to $jobs. Use {*} so that whole list can be appended.
            lappend jobs {*}[$sel jobs $solv::Job_SOLVER_INSTALL]
        }

        ## Solve the jobs
        set solver [$pool Solver]
        while {yes} {
            set jobs_list [list]
            foreach job $jobs { 
                puts "Jobs = [$job __str__]"
                lappend jobs_list [$job cget -how] [$job cget -what]
            }

            set problems [$solver solve_helper $jobs_list]

            ## If no problems found, break, else find a solution.
            if {[llength $problems] == 0} {
                break
            }

            ## Find a solution for the problems found.
            foreach problem $problems {
                ui_debug "Problem [$problem cget -id]/[llength $problems]"
                ui_debug "prob = [$problem __str__]"
                set solutions [$problem solutions]
                set solutions_str [list]
                foreach solution $solutions {
                    set solution_str "Solution [$solution cget -id]"
                    set elements [$solution elements yes]
                    foreach element $elements {
                        append solution_str "\n     - [$element str]"
                    }
                    lappend solution_strs $solution_str
                }
                
                if {![info exists macports::ui_options(questions_singlechoice)]} {
                    error "A conflict occurred"
                }
                set ret [$macports::ui_options(questions_singlechoice) \
                    "[$problem __str__]: Please choose a solution:" "solver" $solution_strs]
                set idx [expr {$ret - 1}]
                set solution [lindex $solutions $idx]
                foreach element [$solution elements] {
                    set newjob [$element Job]
                    if {[$element cget -type] == $solv::Solver_SOLVER_SOLUTION_JOB} {
                        lset jobs [$element cget -jobidx] $newjob
                    } elseif {$newjob ne "NULL" && $newjob ni $jobs} {
                        lappend jobs $newjob
                    }
                }
            }
        }

        ## Transaction Part
        set trans [$solver transaction]
        if {[$trans isempty]} {
            puts "Nothing to do"
            return {}
        }
        ui_msg "Transaction summary:"
        set clflag [expr $solv::Transaction_SOLVER_TRANSACTION_SHOW_OBSOLETES \
            | $solv::Transaction_SOLVER_TRANSACTION_OBSOLETE_IS_UPGRADE] 
        
        set install_list [list]

        foreach cl [$trans classify $clflag] {
            if {[$cl cget -type] == $solv::Transaction_SOLVER_TRANSACTION_ERASE} {
                puts "[$cl cget -count] Erased packages:"
            } elseif {[$cl cget -type] == $solv::Transaction_SOLVER_TRANSACTION_INSTALL} {
                puts "[$cl cget -count] Installed packages:"
            } elseif {[$cl cget -type] == $solv::Transaction_SOLVER_TRANSACTION_REINSTALLED} {
                puts "[$cl cget -count] Reinstalled packages:"
            } elseif {[$cl cget -type] == $solv::Transaction_SOLVER_TRANSACTION_DOWNGRADED} {
                puts "[$cl cget -count] Downgraded packages:"
            } elseif {[$cl cget -type] == $solv::Transaction_SOLVER_TRANSACTION_CHANGED} {
                puts "[$cl cget -count] Changed packages:"
            } elseif {[$cl cget -type] == $solv::Transaction_SOLVER_TRANSACTION_UPGRADED} {
                puts "[$cl cget -count] Upgraded packages:"
            } elseif {[$cl cget -type] == $solv::Transaction_SOLVER_TRANSACTION_VENDORCHANGE} {
                puts "[$cl cget -count] Vendor changes from [$cl cget -fromstr] to [$cl cget -tostr]" 
            } elseif {[$cl cget -type] == $solv::Transaction_SOLVER_TRANSACTION_ARCHCHANGE} {
                puts "[$cl cget -count] Arch changes from [$cl cget -fromstr] to [$cl cget -tostr]"
            } else {
                continue
            }
            foreach p [$cl solvables] {
                set upflag $solv::Transaction_SOLVER_TRANSACTION_UPGRADED
                set downflag $solv::Transaction_SOLVER_TRANSACTION_DOWNGRADED
                if {[$cl cget -type] == $upflag || [$cl cget -type] == $downflag} { 
                        set op [$trans othersolvable $p]
                        puts "[$p __str__] -> [$op __str__]"
                } else {
                    puts [$p __str__]
                    set purl [$p lookup_str $solv::SOLVABLE_URL]
                    lappend install_list [list [$p cget -name] $purl] 
                }
            }
        }
        return $install_list
    }
}
