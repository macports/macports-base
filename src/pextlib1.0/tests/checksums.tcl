# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# Test file for Pextlib's md5 and sha1 commands.
# Requires r/w access to /tmp/
# Syntax:
# tclsh checksums.tcl <Pextlib name>

proc main {pextlibname} {
    load $pextlibname

    encoding system utf-8

    set testfile "/tmp/macports-pextlib-testchecksums"
    file delete -force $testfile

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

    # delete the file.
    file delete -force $testfile
}

main $argv
