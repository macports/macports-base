set autoconf "../../../Mk/macports.autoconf.mk"

source ../library.tcl

proc get_md5 {filename} {
    set md5 "debug: calculated (md5)"

    set line [get_line $filename $md5]
    set result [lrange [split $line " "] 4 4]

    return $result
}


proc get_sha {filename} {
    set sha "debug: calculated (sha1)"

    set line [get_line $filename $sha]
    set result [lrange [split $line " "] 4 4]

    return $result
}


proc get_rmd {filename} {
    set sha "debug: calculated (rmd160)"

    set line [get_line $filename $sha]
    set result [lrange [split $line " "] 4 4]

    return $result
}
