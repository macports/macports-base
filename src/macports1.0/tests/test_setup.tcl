# Shared test initialization for macports1.0, port1.0, and package1.0 tests.
#
# Prerequisites before sourcing this file:
#   package require tcltest 2
#   namespace import tcltest::*
#   set pwd [file dirname [file normalize $argv0]]
#   source ../XXX_test_autoconf.tcl   ;# sets macports::autoconf::*

package require macports 1.0

# Source shared test helpers from this directory.
set _test_setup_dir [file dirname [file normalize [info script]]]
source [file join $_test_setup_dir init_tmp_prefix.tcl]

# Clean leftovers from interrupted tests and set up a temporary prefix.
file delete -force $pwd/tmpdir
init_tmp_prefix $pwd/tmpdir

array set ui_options {}
set ui_options(ports_noninteractive) yes
mportinit ui_options

# Constraint for darwin platform.
testConstraint darwin [expr {$tcl_platform(os) eq "Darwin"}]

##
# Consolidated copy of macports::worker_init for testing, without using
# sub-interpreters.  Superset of aliases needed by macports1.0, port1.0,
# and package1.0 test suites.
proc macports_worker_init {} {
    interp alias {} _cd {} cd
    proc PortSystem {version} {
        package require port $version
        portmain::report_platform_info
    }
    # Clearly separate slave interpreters and the master interpreter.
    interp alias {} mport_exec      {} mportexec
    interp alias {} mport_open      {} mportopen
    interp alias {} mport_close     {} mportclose
    interp alias {} mport_lookup    {} mportlookup
    interp alias {} mport_info      {} mportinfo
    # Export some utility functions defined here.
    interp alias {} macports_create_thread          {} macports::create_thread
    interp alias {} getportbuildpath                {} macports::getportbuildpath
    interp alias {} getportworkpath_from_buildpath  {} macports::getportworkpath_from_buildpath
    interp alias {} getportresourcepath             {} macports::getportresourcepath
    interp alias {} getportlogpath                  {} macports::getportlogpath
    interp alias {} getdefaultportresourcepath      {} macports::getdefaultportresourcepath
    interp alias {} getprotocol                     {} macports::getprotocol
    interp alias {} getportdir                      {} macports::getportdir
    interp alias {} findBinary                      {} macports::findBinary
    interp alias {} binaryInPath                    {} macports::binaryInPath
    interp alias {} shellescape                     {} macports::shellescape
    # New Registry/Receipts stuff
    interp alias {} registry_new                    {} registry::new_entry
    interp alias {} registry_open                   {} registry::open_entry
    interp alias {} registry_write                  {} registry::write_entry
    interp alias {} registry_prop_store             {} registry::property_store
    interp alias {} registry_prop_retr              {} registry::property_retrieve
    interp alias {} registry_exists                 {} registry::entry_exists
    interp alias {} registry_exists_for_name        {} registry::entry_exists_for_name
    interp alias {} registry_activate               {} portimage::activate
    interp alias {} registry_deactivate             {} portimage::deactivate
    interp alias {} registry_deactivate_composite   {} portimage::deactivate_composite
    interp alias {} registry_install                {} portimage::install
    interp alias {} registry_uninstall              {} registry_uninstall::uninstall
    interp alias {} registry_register_deps          {} registry::register_dependencies
    interp alias {} registry_fileinfo_for_index     {} registry::fileinfo_for_index
    interp alias {} registry_fileinfo_for_file      {} registry::fileinfo_for_file
    interp alias {} registry_bulk_register_files    {} registry::register_bulk_files
    interp alias {} registry_active                 {} registry::active
    interp alias {} registry_file_registered        {} registry::file_registered
    interp alias {} registry_port_registered        {} registry::port_registered
    interp alias {} registry_list_depends           {} registry::list_depends
    # deferred options processing.
    interp alias {} getoption {} macports::getoption
    # ping cache
    interp alias {} get_pingtime {} macports::get_pingtime
    interp alias {} set_pingtime {} macports::set_pingtime
    # archive_sites.conf handling
    interp alias {} get_archive_sites_conf_values {} macports::get_archive_sites_conf_values
    foreach opt $macports::portinterp_options {
        if {![info exists $opt]} {
            global macports::$opt
            set ::$opt macports::$opt
        }
        if {[info exists $opt]} {
            set system_options($opt) $opt
            set ::$opt $opt
        }
    }

    # We don't need to handle portinterp_deferred_options, they're
    # automatically handled correctly.
}
