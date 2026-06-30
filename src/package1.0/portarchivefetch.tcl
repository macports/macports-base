# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portarchivefetch_run.tcl

package provide portarchivefetch 1.0

set org.macports.archivefetch [target_new org.macports.archivefetch portarchivefetch::archivefetch_main]
target_provides ${org.macports.archivefetch} archivefetch
target_requires ${org.macports.archivefetch} main
target_runtype ${org.macports.archivefetch} always
target_prerun ${org.macports.archivefetch} portarchivefetch::archivefetch_start
target_runpkg ${org.macports.archivefetch} portarchivefetch_run

namespace eval portarchivefetch {
    # List of URLs to attempt, filled in by checkarchivefiles
    variable archivefetch_urls {}
    # Whether fetching an archive has been attempted. Used to print an
    # explanatory message when an archive was not available.
    variable attempted 0
}
namespace eval portfetch::mirror_sites {}

options archive_sites archivefetch.user archivefetch.password \
    archivefetch.use_epsv archivefetch.ignore_sslcert \
    archive_sites.mirror_subdir archivefetch.pubkeys \
    archive.subdir

# user name & password
default archivefetch.user {}
default archivefetch.password {}
# Use EPSV for FTP transfers
default archivefetch.use_epsv no
# Ignore SSL certificate
default archivefetch.ignore_sslcert no
default archivefetch.pubkeys {$archivefetch_pubkeys}

default archive_sites {[portarchivefetch::filter_sites]}
default archive_sites.listfile archive_sites.tcl
default archive_sites.listpath port1.0/fetch
default archive.subdir {${subport}}

# returns full path to mirror list file
proc portarchivefetch::get_full_archive_sites_path {} {
    global archive_sites.listfile archive_sites.listpath porturl
    # look up archive sites only from this ports tree,
    # do not fallback to the default
    return [getportresourcepath $porturl [file join ${archive_sites.listpath} ${archive_sites.listfile}] no]
}

proc portarchivefetch::filter_sites {} {
    global prefix_frozen frameworks_dir_frozen applications_dir_frozen porturl \
        cxx_stdlib delete_la_files \
        portfetch::mirror_sites::sites portfetch::mirror_sites::archive_type \
        portfetch::mirror_sites::archive_prefix \
        portfetch::mirror_sites::archive_frameworks_dir \
        portfetch::mirror_sites::archive_applications_dir \
        portfetch::mirror_sites::archive_cxx_stdlib \
        portfetch::mirror_sites::archive_delete_la_files  \
        portfetch::mirror_sites::archive_sigtype \
        portfetch::mirror_sites::archive_pubkey

    # get defaults from ports tree resources
    set mirrorfile [get_full_archive_sites_path]
    if {[file exists $mirrorfile]} {
        source $mirrorfile
    }
    # get archive_sites.conf values
    foreach {key val} [get_archive_sites_conf_values] {
        set $key $val
    }

    set ret [list]
    foreach site [array names archive_prefix] {
        set missing 0
        foreach var {archive_frameworks_dir archive_applications_dir archive_type archive_cxx_stdlib archive_delete_la_files} {
            if {![info exists ${var}($site)]} {
                ui_warn "no $var configured for site '$site'"
                set missing 1
            }
        }
        if {$missing} {
            continue
        }
        # The paths in the portfile vars are fully resolved, so resolve
        # these too before comparing them.
        foreach var {archive_prefix archive_frameworks_dir archive_applications_dir} {
            if {[catch {set ${var}_norm [realpath [set ${var}($site)]]}]} {
                set ${var}_norm [file normalize [set ${var}($site)]]
            }
        }
        if {$sites($site) ne {} &&
            $archive_prefix_norm eq $prefix_frozen &&
            $archive_frameworks_dir_norm eq $frameworks_dir_frozen &&
            $archive_applications_dir_norm eq $applications_dir_frozen &&
            $archive_cxx_stdlib($site) eq $cxx_stdlib &&
            $archive_delete_la_files($site) eq $delete_la_files &&
            ![catch {archiveTypeIsSupported $archive_type($site)}]} {
            # using the archive type as a tag
            lappend ret ${site}::$archive_type($site)
        }
    }

    # check if porturl itself points to an archive
    if {![catch {get_portimage_name} portimage_name] && [file rootname [file tail $porturl]] eq [file rootname $portimage_name] && [file extension $porturl] ne ""} {
        lappend ret [string range $porturl 0 end-[string length [file tail $porturl]]]:[string range [file extension $porturl] 1 end]
        archive.subdir
    }
    return $ret
}

# Start asynchronous fetch of archive
proc portarchivefetch::archivefetch_async_start {logid} {
    package require portarchivefetch_run
    global all_archive_files
    _archivefetch_start yes
    if {![info exists all_archive_files]} {
        # No files to fetch
        return 0
    }
    variable async_logid $logid
    fetchfiles yes
}

proc portarchivefetch::_async_cleanup {} {
    variable async_job
    if {[info exists async_job]} {
        lassign $async_job jobid tmpfiles
        curlwrap_async_cancel $jobid
        file delete {*}$tmpfiles
        unset async_job
    }
}
