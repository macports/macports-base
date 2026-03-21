# Set up a custom environment with its own configuration.
# Shared by macports1.0, port1.0, and package1.0 test suites.
proc init_tmp_prefix {srcpath dstpath} {
    global env

    umask 022
    # use custom macports.conf and sources.conf
    makeDirectory $dstpath
    makeDirectory $dstpath/share/macports/install
    makeDirectory $dstpath/var/macports/registry
    makeDirectory $dstpath/var/macports/distfiles
    set fd [open $dstpath/macports.conf w+]
    puts $fd "portdbpath $dstpath/var/macports"
    puts $fd "prefix $dstpath"
    puts $fd "variants_conf $dstpath/variants.conf"
    puts $fd "sources_conf $srcpath/sources.conf"
    puts $fd "applications_dir $dstpath/Applications"
    puts $fd "frameworks_dir $dstpath/Library/Frameworks"
    puts $fd "extra_env TCLLIBPATH"
    close $fd

    # Populate share/macports from the source tree instead of the
    # installed prefix, so tests can run fully in-tree.
    set top $macports::autoconf::top_srcdir
    file copy $top/macports-pubkey.pem $dstpath/share/macports/
    file copy $top/setupenv.bash $dstpath/share/macports/
    file copy $top/doc/base.mtree $dstpath/share/macports/install/
    file copy $top/doc/prefix.mtree $dstpath/share/macports/install/
    file copy $top/doc/macosx.mtree $dstpath/share/macports/install/
    file copy $top/keys $dstpath/share/macports/

    close [open $dstpath/variants.conf w+]

    set env(PORTSRC) $dstpath/macports.conf
}
