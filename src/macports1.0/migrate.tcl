# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# restore.tcl
#
# TODO: include MacPorts copyright
#


package provide migrate 1.0

package require macports 1.0
package require registry 1.0
package require Pextlib 1.0
package require snapshot 1.0
package require registry_uninstall 2.0

namespace eval migrate {

    proc main {opts} {
        # The main function. Calls each individual function that needs to be run.
        #
        # Args:
        #           opts - options array.
        # Returns:
        #           None
        #
        # TODO: 
        # make it return some value

        array set options $opts

        # TODO: move this to restore.tcl
        # if ([info exists options(ports_restore_snapshot-id)]) {
        #     # use that snapshot
        #     set snapshot [fetch_snapshot options(ports_restore_snapshot-id)]
        # } else {
        #     # TODO: ask if the user is fine with the latest snapshot, if 'yes'
        #     # use latest snapshot
        #     set snapshot [fetch_latest_snapshot]
        # }


        # create a snapshot
        # set snapshot snapshot::main

        # fetch ports and variants for this snapshot

        # WILL WRITE FOR FETCHING AFTER DISCUSSING WITH BRAD
        
        # ASSUMING I GET THE FINAL PORTLIST FOR NOW
        # $portlist
        set portlist [registry::entry imaged]


        foreach port $portlist {
            #puts [$port name]
        }

        puts "here"
        puts

        #set portlist1 [sort_portlist_by_dependendents $portlist]

        puts "here1"
        puts ""

        set portlist2 [sort_ports $portlist]

        puts "here2"


        # foreach port $portlist1 {
        #     puts $port
        # }
        # puts

        foreach port $portlist2 {
            #puts [lindex $port 0]
        }

        #uninstall_installed $portlist
        return 0
        # recover_ports_state $portlist


        # TODO: CLEAN PARTIAL BUILDS STEP HERE

    }

    proc fetch_snapshot { snapshot_id } {

    }

    proc fetch_latest_snapshot {} {

        return

    }

    proc port_dependencies {portName variantInfo} {

        set dependencyList [list]
        set portSearchResult [mportlookup $portName]

        # TODO: error handling, if any?
        array set portInfo [lindex $portSearchResult 1]

        set dependencyTypes { depends_fetch depends_extract depends_build depends_lib depends_run }
        foreach dependencyType $dependencyTypes {
            if {[info exists portInfo($dependencyType)] && [string length $portInfo($dependencyType)] > 0} {
                foreach dependency $portInfo($dependencyType) {
                    lappend dependencyList [lindex [split $dependency:] end]
                }
            }
        }
        return $dependencyList
    }

    proc portlist_sort_dependencies_first {portlist} {

        array set port_installed {}
        array set port_deps {}
        array set port_in_list {}

        set newList [list]

        foreach port $portlist {

            #puts "in - "
            #puts $port

            set name [$port name]
            set variants [$port variants]
            set active 0

            if {[$port state] eq "installed"} {
                set active 1
            }

            #puts "$name $variants $active"

            if {![info exists port_in_list($name)]} {
                set port_in_list($name) 1
                set port_installed($name) 0
            } else {
                incr port_in_list($name)
            }

            if {![info exists port_deps(${name},${variants})]} {
                set port_deps(${name},${variants}) [port_dependencies $name $variants]
            }

            #puts "$port_deps(${name},$variants)"

            lappend newList [list $name $variants $active]
        }

        set operationList [list]

        puts

        while {[llength $newList] > 0} {

            set oldLen [llength $newList]

            foreach port $newList {
                foreach {name variants active} $port break

                #puts "out - "
                #puts "$name $variants $active"

                if {$active && $port_installed($name) < ($port_in_list($name) - 1)} {
                    continue
                }
                set installable 1
                foreach dep $port_deps(${name},${variants}) {
                    if {[info exists port_installed($dep)] && $port_installed($dep) == 0} {
                        set installable 0
                        break
                    }
                }
                if {$installable} {
                    #puts "i'm being installed: $name"
                    lappend operationList [list $name $variants $active]
                    incr port_installed($name)
                    set index [lsearch $newList [list $name $variants $active]]
                    set newList [lreplace $newList $index $index]
                }
            }

            #puts "lengths: $oldLen [llength $newList]"

            if {[llength $newList] == $oldLen} {
                return -code error "stuck in loop"
            }
        }

        return $operationList
    }

    proc portlist_sort_dependencies_later { portlist } {

        # Sorts a list of port references such that dependents come before
        # their dependencies.
        #
        # Args:
        #       portlist - the list of port references
        #
        # Returns:
        #       the list in dependency-sorted order

        foreach port $portlist {
            array set pvals $port
            lappend entries($pvals(name)) $port

            # Avoid adding ports in loop
            if {![info exists dependents($pvals(name))]} {
                set dependents($pvals(name)) {}
                foreach result [$port dependents] {
                    lappend dependents($pvals(name)) [$result name]
                }
            }
            array unset pvals
        }
        set ret {}
        foreach port $portlist {
            portlist_sort_dependencies_later_helper $port entries dependents seen ret
        }
        return $ret
    }

    proc portlist_sort_dependencies_later_helper {port up_entries up_dependents up_seen up_retlist} {
        upvar 1 $up_seen seen
        if {![info exists seen($port)]} {
            set seen($port) 1
            upvar 1 $up_entries entries $up_dependents dependents $up_retlist retlist
            array set pvals $p
            foreach dependent $dependents($pvals(name)) {
                if {[info exists entries($dependent)]} {
                    foreach entry $entries($dependent) {
                        portlist_sort_dependencies_later_helper $entry entries dependents seen retlist
                    }
                }
            }
            lappend retlist $port
        }
    }

    proc uninstall_installed { portlist } {

        set portlist [portlist_sort_dependencies_later $portlist]

        foreach port $portlist {
            puts "[$port name] [$port state]"
        }

        return 0

        if {[info exists macports::ui_options(questions_yesno)]} {

            set retvalue [$macports::ui_options(questions_yesno) "Restoring a snapshot will first uninstall all the installed ports.
            Would you like to continue?" {n} 0]

            if {$retvalue == 0} {
                foreach port $portlist {
                    set name [$port name]
                     ui_msg "Uninstalling: $name"

                    try -pass_signal {
                        # 'registry_uninstall' takes name, version, revision, variants and an options list for a port
                        registry_uninstall::uninstall [$port name] [$port version] [$port revision] [$port] variants {}
                    } catch {{*} eCode eMessage} {
                        ui_error "Error uninstalling $name: $eMessage"
                    }
                }
            } else {
                ui_msg "Not uninstalling ports."
                return 1
            }
        }
        return 0
    }

    proc recover_ports_state {portList} {

        set sorted_portlist [portlist_sort_dependencies_first $portList]
        
        foreach port $sorted_portlist {
            
            set name [string trim [lindex $port 0]]
            set variations [lindex $port 1]
            set active [lindex $port 2]

            if {$active} {
                set target install
            } else {
                set target activate
            }

            array unset portinfo
            array set portinfo [lindex $res 1]
            set porturl $portinfo(porturl)
            
            # TODO: error handling, if any?

            set workername [mportopen $porturl [list subport $portinfo(name)] $variations]

            # TODO: instead of mportexec, look for some API?
            if {[catch {set result [mportexec $workername $target]} result]} {
                global errorInfo
                mportclose $workername
                ui_msg "$errorInfo"
                return -code error "Unable to execute target 'install' for port '$name': $result"
            } else {
                mportclose $workername
            }

            # TODO: deps active?
        }

    }
}
