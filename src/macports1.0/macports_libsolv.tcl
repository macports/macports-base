# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# macports_libsolv.tcl
#
# Copyright (c) 2017 Jackson Isaac <ijackson@macports.org>
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
    #  Read the PortIndex contents and write into libsolv readable solv's (solvables).
    #  To Do:
    #  Add additional information regarding arch, vendor, etc to solv.
    #  Done:
    #  Add epoch, version and revision to each solv.
    #  Add more info to solv about its description, long_description, license, category and homepage.
    #  Add dependency information to each solv.
    #  Create a repo of installed packages for dependency calculation and Transaction summary.
    #  Add obsoletes information to solv by parsing the replaced_by field in PortIndex. \
    #  They mean the converse of each other, hence cannot assign them directly.
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

        ## Variable for replace_by to set obsoletes of solv.
        variable replaced_by

        ## Variable to map portname to its corresponding solvable.
        variable solvs

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
                if {[macports::getprotocol $source] eq "file"} {
                    set repo [$pool add_repo [macports::getportdir $source]]
                } else {
                    set repo [$pool add_repo [macports::getsourcepath $source]]
                }
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

                            $solvable configure -name $name \
                            -evr "$portinfo(epoch)@$portinfo(version)-$portinfo(revision)" \
                            -arch "i386"

                            set solvid [$solvable cget -id]

                            ## Add extra info to repodata i.e. Summary, Description, License, homepage, category to the solvables
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
                            #  and -1 for runtime dependencies (Still need to figure this out correctly).
                            foreach {fieldname deptype marker} $fields {
                                if {[info exists portinfo($fieldname)]} {
                                    foreach dep $portinfo($fieldname) {
                                        set dep_name [lindex [split $dep :] end]
                                        $solvable add_deparray $deptype [$pool str2id $dep_name 1] {*}$marker
                                    }
                                }
                            }

                            ## Set up map from port to its solvable if replaced_by another package.
                            if {[info exists portinfo(replaced_by)]} {
                                set replaced_by($name) $solvable
                            }

                            ## Set SOLVABLE_PROVIDES for the solv so that the package can be found during depcalc.
                            set provides [$pool rel2id [$solvable cget -nameid] [$solvable cget -evrid] $solv::REL_EQ 1]
                            $solvable add_deparray $solv::SOLVABLE_PROVIDES $provides
                            
                            ## Set portinfo of each solv object. Map it to correct solvid.
                            set portindexinfo([$solvable cget -id]) $line

                            ## Map portname to its correspoding solvable.
                            set solvs($name) $solvable
                        }

                        ## Set obsoletes by reading the replaced_by contents.
                        ## Obsoletes: A replaced_by B means B obsoletes A.
                        if {[array exists replaced_by] && [array size replaced_by] > 0} {
                            foreach name [array names replaced_by] {
                                array set portinfo $portindexinfo([$replaced_by($name) cget -id])
                                set A $name
                                set B $portinfo(replaced_by)
                                ## Check if the replaced_by port actually exists or not.
                                if {![info exists solvs($B)]} {
                                    ui_debug "No port with the name $B exists. Skipping adding obsoletes for $A."
                                } else {
                                    $solvs($B) add_deparray $solv::SOLVABLE_OBSOLETES [$pool str2id $A 1]
                                }
                                array unset -nocomplain portinfo
                            }
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
    
        }
        return $pool
    }

    ## Search using libsolv.
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
        
        ## Dataiterator procedure will iterate over the solvables and return the matched solv's.
        set di [$pool Dataiterator $search_option $pattern $di_flag]

        ## Add the matched solvables to the Selection (set of solvables).
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

    ## Dependency calculation using libsolv.
    #  Pass the complete list of ports to dep_calc instead of calling
    #  it for every single portname. This helps to optimize the end result
    #  and resolving conflicts between multiple ports.
    proc dep_calc {portlist} {
        set pool [create_pool]
        variable portindexinfo
        ## Uncomment the following line for debuging output related to solvables and pool information.
        # $pool set_debuglevel 3
        
        ## Create list of ports to be installed.
        set portname [list]
        ## Append portnames to $portname list after extracting them from $portlist.
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

        ## Solve the jobs.
        set solver [$pool Solver]
        while {yes} {
            set jobs_list [list]
            foreach job $jobs { 
                ui_debug "Jobs = [$job __str__]"
                lappend jobs_list [$job cget -how] [$job cget -what]
            }

            set problems [$solver solve_helper $jobs_list]

            ## If no problems found, break, else find a solution.
            if {[llength $problems] == 0} {
                break
            }

            ## Conflict Resolution.
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

        ## Create Transaction.
        #  To Do:
        #  Add support for uninstall, reinstall, upgrade and downgrade (Versioned portname required).
        #  Done:
        #  Create list of ports to be installed.
        set trans [$solver transaction]
        if {[$trans isempty]} {
            ui_msg "Nothing to do"
            return {}
        }
        ui_msg "Transaction summary:"
        set clflag [expr $solv::Transaction_SOLVER_TRANSACTION_SHOW_OBSOLETES \
            | $solv::Transaction_SOLVER_TRANSACTION_OBSOLETE_IS_UPGRADE] 
        
        set install_list [list]
        set dep_list [list]
        foreach cl [$trans classify $clflag] {
            switch -- [$cl cget -type] \
                $solv::Transaction_SOLVER_TRANSACTION_ERASE {
                    ui_msg "[$cl cget -count] Erased packages:"
                } \
                $solv::Transaction_SOLVER_TRANSACTION_INSTALL {
                    ui_msg "[$cl cget -count] Installed packages:"
                } \
                $solv::Transaction_SOLVER_TRANSACTION_REINSTALLED {
                    ui_msg "[$cl cget -count] Reinstalled packages:"
                } \
                $solv::Transaction_SOLVER_TRANSACTION_DOWNGRADED {
                    ui_msg "[$cl cget -count] Downgraded packages:"
                } \
                $solv::Transaction_SOLVER_TRANSACTION_CHANGED {
                    ui_msg "[$cl cget -count] Changed packages:"
                } \
                $solv::Transaction_SOLVER_TRANSACTION_UPGRADED {
                    ui_msg "[$cl cget -count] Upgraded packages:"
                } \
                $solv::Transaction_SOLVER_TRANSACTION_VENDORCHANGE {
                    ui_msg "[$cl cget -count] Vendor changes from [$cl cget -fromstr] to [$cl cget -tostr]" 
                } \
                $solv::Transaction_SOLVER_TRANSACTION_ARCHCHANGE {
                    ui_msg "[$cl cget -count] Arch changes from [$cl cget -fromstr] to [$cl cget -tostr]"
                } \
                default continue
            
            foreach p [$cl solvables] {
                set cltype [$cl cget -type]
                set upflag $solv::Transaction_SOLVER_TRANSACTION_UPGRADED
                set downflag $solv::Transaction_SOLVER_TRANSACTION_DOWNGRADED
                if {$cltype == $upflag || $cltype == $downflag} { 
                        set op [$trans othersolvable $p]
                        ui_msg "[$p __str__] -> [$op __str__]"
                } else {
                    lappend dep_list [$p __str__]
                }
            }
        }
        if {[info exists macports::ui_options(questions_yesno)]} {
            set retvalue [$macports::ui_options(questions_yesno) "The following packages will be installed by libsolv: " "" [lsort $dep_list] {y} 0]
            if {$retvalue == 1} {
                return {}
            }
        } else {
            set depstring "$macports::ui_prefix Packages to be installed by libsolv:"
        }

        # Commiting Transaction.
        $trans order
        ui_msg "Comitting Transaction:"
        foreach p [$trans steps] {
            array set portinfo $portindexinfo([$p cget -id])
            set porturl "file://[[$p cget -repo] cget -name]/${portinfo(portdir)}"
            lappend install_list [list $p $porturl] 
            array unset -nocomplain portinfo
        }
        return $install_list
    }
}
