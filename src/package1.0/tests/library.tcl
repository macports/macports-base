proc env_init {} {
    global os.platform os.major os.arch epoch destpath package.destpath build_arch configure.build_arch \
        subport version revision package.flat maintainers description categories homepage \
        supported_archs porturl workpath distname license filespath portpath pwd name

    set os.platform darwin
    set os.major 9
    set os.arch i386
    set epoch 0

    set workpath $pwd/work
    set destpath $pwd/pkg
    set portpath $pwd
    set portdbpath $pwd/dbpath
    set filespath $pwd/files
    set build_arch i386
    set configure.build_arch $build_arch
    set package.destpath $pwd/pkg

    set name fondu
    set subport fondu
    set version 060102
    set distname fondu_src-060102
    set revision 1
    set license BSD
    set package.flat no
    set maintainers {test@macports.org}
    set description test.description
    set categories test
    set supported_archs noarch
    set homepage "http://fondu.sourceforge.net/"
    set porturl "file://${pwd}"

    # mock mport_lookup, it normally needs a PortIndex
    proc mport_lookup {portname} {
        global porturl
        return [list $portname [list variants universal portdir print/${portname} description {A set of programs to interconvert between Mac font formats and pfb, ttf, otf and bdf files on UNIX.} homepage http://fondu.sourceforge.net/ epoch 0 platforms darwin name $portname license BSD maintainers nomaintainer version 060102 categories print revision 1 porturl $porturl]]
    }
}

##
# This is basically a copy of macports::worker_init, but without using
# sub-interpreters
proc macports_worker_init {} {
    interp alias {} _cd {} cd

    proc PortSystem {version} {
        package require port $version
    }

    # Clearly separate slave interpreters and the master interpreter.
    interp alias {} mport_exec      {} mportexec
    interp alias {} mport_open      {} mportopen
    interp alias {} mport_close     {} mportclose
    interp alias {} mport_lookup    {} mportlookup
    interp alias {} mport_info      {} mportinfo

    # Export some utility functions defined here.
    interp alias {} macports_create_thread          {} macports::create_thread
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

testConstraint darwin [expr {$tcl_platform(os) eq "Darwin"}]
