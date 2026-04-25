# Create a throwaway MacPorts prefix at dstpath for unit testing.
#
# Generates a minimal macports.conf (pointing sources_conf at the
# single shared sources.conf in this directory), an empty
# variants.conf, and the directory layout that mportinit expects.
# Data files (pubkey, mtree specs, keys) are copied from the source
# tree so tests can run fully in-tree without an installed prefix.
#
# Sets PORTSRC so that a subsequent mportinit picks up the generated
# configuration.
#
# Shared by macports1.0, port1.0, and package1.0 test suites via
# test_setup.tcl.
#
# dstpath - Absolute path to the directory that will serve as the
#           prefix.  Created if it does not exist; callers should
#           delete it when the test is finished.
proc init_tmp_prefix {dstpath} {
    global env

    umask 022
    # use custom macports.conf and sources.conf
    makeDirectory $dstpath
    makeDirectory $dstpath/share/macports/install
    makeDirectory $dstpath/var/macports/registry
    makeDirectory $dstpath/var/macports/distfiles
    set top $macports::autoconf::top_srcdir
    set fd [open $dstpath/macports.conf w+]
    puts $fd "portdbpath $dstpath/var/macports"
    puts $fd "prefix $dstpath"
    puts $fd "variants_conf $dstpath/variants.conf"
    puts $fd "sources_conf [file join $top src macports1.0 tests sources.conf]"
    puts $fd "applications_dir $dstpath/Applications"
    puts $fd "frameworks_dir $dstpath/Library/Frameworks"
    puts $fd "extra_env TCLLIBPATH"
    close $fd

    # Populate share/macports from the source tree instead of the
    # installed prefix, so tests can run fully in-tree.
    file copy $top/macports-pubkey.pem $dstpath/share/macports/
    file copy $top/setupenv.bash $dstpath/share/macports/
    file copy $top/doc/base.mtree $dstpath/share/macports/install/
    file copy $top/doc/prefix.mtree $dstpath/share/macports/install/
    file copy $top/doc/macosx.mtree $dstpath/share/macports/install/
    file copy $top/keys $dstpath/share/macports/

    close [open $dstpath/variants.conf w+]

    set env(PORTSRC) $dstpath/macports.conf
}
