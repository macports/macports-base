# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portstartupitem_run.tcl

package provide portstartupitem 1.0

namespace eval portstartupitem {
    proc loaded {} {
        package require portstartupitem_run
        return [_loaded]
    }
}

#   Newly added keys:
#
#   startupitem.executable  the command to start the executable
#       This is exclusive of init, start, stop, restart
#       - This may be composed of exec arguments only--not shell code
#
#   startupitem.pidfile     none
#       There is no pidfile we can track
#
#   startupitem.pidfile     auto [filename.pid]
#       The daemon is responsible for creating/deleting the pidfile
#
#   startupitem.pidfile     clean [filename.pid]
#       The daemon creates the pidfile, but we must delete it
#
#   startupitem.pidfile     manual [filename.pid]
#       We create and destroy the pidfile to track the pid we receive from the executable
#
#   startupitem.logfile     logpath
#       Log stdout to the specified logfile
#       - If not specified, then output to /dev/null
#       - For launchd, set the stdout plist key
#
#   startupitem.logfile.stderr logpath
#       Log stderr to the specified logfile
#       - If not specified, defaults to startupitem.logfile
#       - If cleared, disables stderr logging
#       - For launchd, set the stderr plist key
#
#   startupitem.logevents   yes/no
#       Log events to the log
#       - for launchd, generate log messages inside daemondo
#       - daemondo verbosity is controlled by startupitem.daemondo.verbosity
#
#   startupitem.autostart   yes/no
#       Automatically load the startupitem after activating. Defaults to no.
#
#   startupitem.user        <user>
#       User to run the service/daemon as.
#
#   startupitem.group       <group>
#       Group to run the service/daemon as.
#
#   startupitem.debug       yes/no
#       Enable additional debug logging
#       - for launchd, sets the Debug key to true

options startupitems startupitem.autostart startupitem.debug \
        startupitem.create startupitem.custom_file \
        startupitem.executable startupitem.group \
        startupitem.init startupitem.install startupitem.location \
        startupitem.logevents startupitem.logfile \
        startupitem.logfile.stderr startupitem.name \
        startupitem.netchange startupitem.pidfile startupitem.plist \
        startupitem.requires startupitem.restart startupitem.start \
        startupitem.stop startupitem.type startupitem.uniquename \
        startupitem.user startupitem.daemondo.verbosity

default startupitem.autostart   no
default startupitem.custom_file {}
default startupitem.debug       no
default startupitem.executable  {}
default startupitem.group       {}
default startupitem.init        {}
default startupitem.install     {$system_options(startupitem_install)}
default startupitem.location    LaunchDaemons
default startupitem.logevents   no
default startupitem.logfile     {}
default startupitem.logfile.stderr {${startupitem.logfile}}
default startupitem.name        {${subport}}
default startupitem.netchange   no
default startupitem.pidfile     {}
default startupitem.plist       {${startupitem.uniquename}.plist}
default startupitem.requires    {}
default startupitem.restart     {}
default startupitem.start       {}
default startupitem.stop        {}
default startupitem.type        {[portstartupitem::get_startupitem_type]}
default startupitem.uniquename  {org.macports.${startupitem.name}}
default startupitem.user        {}

default startupitem.daemondo.verbosity  1

# Calculate a default value for startupitem.type
proc portstartupitem::get_startupitem_type {} {
    global system_options os.platform startupitem.create

    if {![tbool startupitem.create]} {
        return "none"
    }

    set type $system_options(startupitem_type)
    if {$type eq "default" || $type eq ""} {
        switch -- ${os.platform} {
            darwin {
                return "launchd"
            }
            default {
                return "none"
            }
        }
    }
    return $type
}

# run a loop body with variables set up representing the attributes of
# each startupitem that has been defined in the portfile
proc portstartupitem::foreach_startupitem {body} {
    global startupitems
    set vars [list autostart create custom_file debug executable group \
              init install location logevents logfile logfile.stderr \
              name netchange pidfile plist requires restart start stop type \
              uniquename user daemondo.verbosity]

    set startupitems_dict [dict create]
    if {[info exists startupitems] && $startupitems ne ""} {
        foreach {key val} $startupitems {
            if {$key eq "name"} {
                set curname $val
                # these have defaults based on the name
                set uniquename org.macports.${val}
                dict set startupitems_dict $curname uniquename $uniquename
                dict set startupitems_dict $curname plist ${uniquename}.plist
            }
            dict set startupitems_dict $curname $key $val
        }
    } else {
        global startupitem.name
        foreach var $vars {
            global startupitem.${var}
            if {[info exists startupitem.${var}]} {
                dict set startupitems_dict ${startupitem.name} $var [set startupitem.${var}]
            }
        }
    }

    uplevel 1 [list set si_vars $vars]
    dict for {item subdict} $startupitems_dict {
        uplevel 1 [list set si_dict $subdict]
        uplevel 1 {
            foreach si_var $si_vars {
                if {[dict exists $si_dict $si_var]} {
                    set si_${si_var} [dict get $si_dict $si_var]
                } else {
                    global startupitem.${si_var}
                    if {[info exists startupitem.${si_var}]} {
                        set si_${si_var} [set startupitem.${si_var}]
                        dict set si_dict $si_var [set startupitem.${si_var}]
                    }
                }
            }
        }
        uplevel 1 $body
    }
}

# Add user notes regarding any installed startupitem
proc portstartupitem::add_notes {} {
    global subport startupitem_autostart
    set autostart_names [list]
    set normal_names [list]

    foreach_startupitem {
        if {$si_type eq "none"} {
            continue
        }
        # Add some information for the user to the port's notes
        if {$si_autostart && [tbool startupitem_autostart]} {
            lappend autostart_names $si_name
        } else {
            lappend normal_names $si_name
        }
    }

    if {$normal_names ne ""} {
        if {[exists notes]} {
            # leave a blank line after the existing notes
            notes-append ""
        }
        if {[llength $normal_names] == 1} {
        notes-append \
            "A startup item has been generated that will aid in\
            starting ${subport} with launchd. It is disabled\
            by default. Execute the following command to start it,\
            and to cause it to launch at startup:

    sudo port load ${subport}"
        } else {
            set namelist [join $normal_names ", "]
            notes-append \
            "Startup items (named '$namelist') have been generated that will aid in\
            starting ${subport} with launchd. They are disabled\
            by default. Execute the following command to start them,\
            and to cause them to launch at startup:

    sudo port load ${subport}"
        }
    }
    if {$autostart_names ne ""} {
        if {[exists notes]} {
            # leave a blank line after the existing notes
            notes-append ""
        }
        if {[llength $autostart_names] == 1} {
            notes-append \
            "A startup item has been generated that will\
            start ${subport} with launchd, and will be enabled\
            automatically on activation. Execute the following\
            command to manually _disable_ it:

    sudo port unload ${subport}"
        } else {
            set namelist [join $autostart_names ", "]
            notes-append \
            "Startup items (named '$namelist') have been generated that will\
            start ${subport} with launchd, and will be enabled\
            automatically on activation. Execute the following\
            command to manually _disable_ them:

    sudo port unload ${subport}"
        }
    }
}

# Register the above procedure as a callback after Portfile evaluation
port::register_callback portstartupitem::add_notes
