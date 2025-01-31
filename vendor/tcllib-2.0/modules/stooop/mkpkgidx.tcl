# command line:
# $ interpreter mkpkgidx.tcl -p package1.n.n -p package2 -p package3.n ...
#     packageName file1 file2 ...
# use wish as interpreter instead of tclsh in order to handle graphical packages

# Copyright (c) 2001 by Jean-Luc Fontaine <jfontain@free.fr>.
# This code may be distributed under the same terms as Tcl.
#
# $Id: mkpkgidx.tcl,v 1.3 2004/01/15 06:36:14 andreas_kupries Exp $

# this utility must be used to create the package index file for a package that
# uses stooop.
# it differs from the tcl pkg_mkIndex procedure in the way it sources files.
# since base classes can usually be found in files separate from the derived
# class source file, sourcing each file in a different interpreter (as is done
# in the pkg_mkIndex procedure) results in an error for stooop that catches the
# fact that the base class is not defined. the solution is to use a single
# interpreter which will source the class files in order (base classes first at
# the user's responsibility). since stooop is loaded in that single interpreter,
# inheritance problems and others are automatically caught in the process.
# the generated package index file is fully compatible with the tcl generated
# ones.
# the stooop library makes sure that base classes source files are automatically
# sourced when a derived class is defined (see the stooop.tcl source file for
# more information).
# if your software requires one or more packages, you may force their loading
# by using the -p arguments. each package version number is optionally appended
# to the package name and follows the same rules as the Tcl package require
# command
# example: $ tclsh -p switched.1 -p scwoop foo bar.tcl barfoo.tcl foobar.tcl ...

if {[catch {package require stooop 4}]} {
    # in case stooop package is not installed
    source stooop.tcl
}
namespace import stooop::*

proc indexData {packageName files} {
    global auto_index

    set index "# Package index file created with stooop version [package provide stooop] for stooop packages\n"
    set data {}

    foreach command [info commands] {
        set defined($command) {}
    }

    foreach file $files {
        # source at global level to avoid variable names collisions:
        uplevel #0 source [list $file]

        catch {unset newCommands}                    ;# empty new commands array
        foreach command [info commands] {
            # check new commands at the global level
            # filter out tk widget commands and ignore commands eventually
            # loaded from a package required by the new commands
            if {
                [string match .* $command]||[info exists defined($command)]||
                [info exists auto_index($command)]||\
                [info exists auto_index(::$command)]
            } continue
            set newCommands($command) {}
            set defined($command) {}
        }
        # check new classes, which actually are namespaces:
        foreach class [array name stooop::declared] {
            if {![info exists declared($class)]} {
                # check new commands at the class namespace level:
                foreach command [info commands ::${class}::*] {
                    # ignore commands eventually loaded from a package required
                    # by the new commands
                    if {\
                        [info exists defined($command)]||\
                        [info exists auto_index($command)]||\
                        [info exists auto_index(::$command)]\
                    } continue
                    set newCommands($command) {}
                    set defined($command) {}
                }
                set declared($class) {}
            }
        }
        # so far only sourceable file, not shared libraries, are handled
        lappend data [list $file source [lsort [array names newCommands]]]
    }
    set version [package provide $packageName]
    append index "\npackage ifneeded $packageName $version \[list tclPkgSetup \$dir $packageName $version [list $data]\]"
    return $index
}

proc printUsage {exitCode} {
    global argv0

    puts stderr "usage: $argv0 \[\[-p package.n.n\] \[-p package.n.n\] ...\] moduleName tclFile tclFile ..."
    exit $exitCode
}

# first gather eventual packages:
for {set index 0} {$index<[llength $argv]} {incr index} {
    if {[string compare [lindex $argv $index] -p]!=0} break
    set version {}
    scan [lindex $argv [incr index]] {%[^.].%s} name version
    eval package require $name $version
}

set argv [lrange $argv $index end]                   ;# keep remaining arguments
if {[llength $argv]<2} {
    printUsage 1
}

puts [open pkgIndex.tcl w] [indexData [lindex $argv 0] [lrange $argv 1 end]]
exit                                                     ;# in case wish is used
