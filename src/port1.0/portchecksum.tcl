# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

package provide portchecksum 1.0

set org.macports.checksum [target_new org.macports.checksum portchecksum::checksum_main]
target_provides ${org.macports.checksum} checksum
target_requires ${org.macports.checksum} main fetch
target_prerun ${org.macports.checksum} portchecksum::checksum_start
target_runpkg ${org.macports.checksum} portchecksum_run

namespace eval portchecksum {

    # The list of the types of checksums we know.
    variable checksum_types [list md5 sha1 rmd160 sha256 blake3 size]

    # types to recommend if none are specified in the portfile
    variable default_checksum_types [list rmd160 sha256 size]

    # types that are considered secure
    variable secure_checksum_types [list rmd160 sha256]
}

# Options
options checksums checksum.skip

# Defaults
default checksums {}
default checksum.skip false
