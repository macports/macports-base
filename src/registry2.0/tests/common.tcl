# Common functions for test cases

proc test {condition} {
    uplevel 1 "\
        puts -nonewline {checking if $condition... }
        if {\[catch {
                if {$condition} { \n\
                    puts yes
                } else { \n\
                    puts no \n\
                    exit 1 \n\
                } \n\
            } msg\]} { \n\
                puts \"caught error: \$msg\" \n\
                exit 1 \n\
            }"
}

proc test_equal {statement value} {
    uplevel 1 "\
        puts -nonewline {checking if $statement == \"$value\"... }
        if {\[catch {
                set actual $statement
                if {\$actual == \[subst {$value}\]} { \n\
                    puts yes
                } else { \n\
                    puts \"no (was \$actual)\" \n\
                    exit 1 \n\
                } \n\
            } msg\]} { \n\
                puts \"caught error: \$msg\" \n\
                exit 1 \n\
            }"
}

proc test_set {statement value} {
    uplevel 1 "\
        puts -nonewline {checking if $statement is \[list $value\]... }
        if {\[catch {
                set actual \[lsort $statement\]
                if {\$actual == \[lsort \[subst {\[list $value\]}\]\]} { \n\
                    puts yes
                } else { \n\
                    puts \"no (was \$actual)\" \n\
                    exit 1 \n\
                } \n\
            } msg\]} { \n\
                puts \"caught error: \$msg\" \n\
                exit 1 \n\
            }"
}

proc test_throws {statement error} {
    uplevel 1 "\
        puts -nonewline {checking if \[$statement\] throws $error... }
        if {\[catch {$statement} error\]} { \n\
            if {\$::errorCode == {$error}} {
                puts yes
            } else {
                puts \"no (threw \$::errorCode instead)\" \n\
                exit 1 \n\
            } \n\
        } else { \n\
            puts {no (did not throw)} \n\
            exit 1 \n\
        }"
}

