# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# Test file for Pextlib's vercmp command.
# Syntax:
# tclsh vercomp.tcl <Pextlib name>

proc main {pextlibname} {
    load $pextlibname

    # 2.0 > 1.0
    if {[vercmp 2.0 1.0] <= 0} {
        puts {[vercmp 2.0 1.0] <= 0}
        exit 1
    }
    # 1.0 = 1.0
    if {[vercmp 1.0 1.0] != 0} {
        puts {[vercmp 1.0 1.0] != 0}
        exit 1
    }
    # 1.0 < 2.0
    if {[vercmp 1.0 2.0] >= 0} {
        puts {[vercmp 1.0 2.0] >= 0}
        exit 1
    }

    # def > abc
    if {[vercmp def abc] <= 0} {
        puts {[vercmp def abc] <= 0}
        exit 1
    }
    # abc = abc
    if {[vercmp abc abc] != 0} {
        puts {[vercmp abc abc] != 0}
        exit 1
    }
    # abc < def
    if {[vercmp abc def] >= 0} {
        puts {[vercmp abc def] >= 0}
        exit 1
    }

    # a < 1 (digits beats alpha)
    if {[vercmp a 1] >= 0} {
        puts {[vercmp a 1] >= 0}
        exit 1
    }
}

main $argv
