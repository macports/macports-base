# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# Test file for Pextlib's checksum commands.
# Requires r/w access to /tmp/
# Syntax:
# tclsh checksums.tcl <Pextlib name>

proc write_blake3_test_vector_file {path length} {
    set chan [open $path w]
    fconfigure $chan -translation binary -encoding binary

    set hex {}
    for {set i 0} {$i < $length} {incr i} {
        append hex [format %02x [expr {$i % 251}]]
    }

    puts -nonewline $chan [binary format H* $hex]
    close $chan
}

proc main {pextlibname} {
    load $pextlibname

    encoding system utf-8

    set testfile "/tmp/macports-pextlib-testchecksums"
    set largetestfile "/tmp/macports-pextlib-testchecksums-large"
    file delete -force $testfile
    file delete -force $largetestfile

    # create a dummy file.
    set chan [open $testfile w]
    puts $chan "Article premier"
    puts $chan "  Tous les êtres humains naissent libres et égaux en dignité "
    puts $chan " et en droits. Ils sont doués de raison et de conscience et "
    puts $chan " doivent agir les uns envers les autres dans un esprit de "
    puts $chan " fraternité."
    puts $chan "Article 2"
    puts $chan "  Chacun peut se prévaloir de tous les droits et de toutes les "
    puts $chan " libertés proclamés dans la présente Déclaration, sans "
    puts $chan " distinction aucune, notamment de race, de couleur, de sexe, "
    puts $chan " de langue, de religion, d'opinion politique ou de toute autre "
    puts $chan " opinion, d'origine nationale ou sociale, de fortune, de "
    puts $chan " naissance ou de toute autre situation."
    puts $chan "  De plus, il ne sera fait aucune distinction fondée sur le "
    puts $chan " statut politique, juridique ou international du pays ou du "
    puts $chan " territoire dont une personne est ressortissante, que ce pays "
    puts $chan " ou territoire soit indépendant, sous tutelle, non autonome ou "
    puts $chan " soumis à une limitation quelconque de souveraineté."
    close $chan

    # checksum the file.
    if {[md5 file $testfile] != "91d3ef5cd86741957b0b5d8f8911166d"} {
        puts {[md5 file $testfile] != "91d3ef5cd86741957b0b5d8f8911166d"}
        exit 1
    }
    if {[sha1 file $testfile] != "a40f8539f217a0032d194c3a8c42cc832b6379cf"} {
        puts {[sha1 file $testfile] != "a40f8539f217a0032d194c3a8c42cc832b6379cf"}
        exit 1
    }
    if {[rmd160 file $testfile] != "b654ecbdced69aba8a4ea8d6824dd1ac103b3116"} {
        puts {[rmd160 file $testfile] != "b654ecbdced69aba8a4ea8d6824dd1ac103b3116"}
        exit 1
    }
    if {[sha256 file $testfile] != "424359e1002a1d117f12f95346a81987037b3fde60a564a7aacb48c65a518fe5"} {
        puts {[sha256 file $testfile] != "424359e1002a1d117f12f95346a81987037b3fde60a564a7aacb48c65a518fe5"}
        exit 1
    }
    if {[blake3 file $testfile] != "756171f6ef52a9255a4d4ef375ace3338f5f175bf1089cdb0db17761f505cec2"} {
        puts {[blake3 file $testfile] != "756171f6ef52a9255a4d4ef375ace3338f5f175bf1089cdb0db17761f505cec2"}
        exit 1
    }

    # Exercise the upstream 1025-byte test vector to cross the chunk boundary.
    write_blake3_test_vector_file $largetestfile 1025
    if {[blake3 file $largetestfile] != "d00278ae47eb27b34faecf67b4fe263f82d5412916c1ffd97c8cb7fb814b8444"} {
        puts {[blake3 file $largetestfile] != "d00278ae47eb27b34faecf67b4fe263f82d5412916c1ffd97c8cb7fb814b8444"}
        exit 1
    }

    # delete the file.
    file delete -force $testfile
    file delete -force $largetestfile
}

main $argv
