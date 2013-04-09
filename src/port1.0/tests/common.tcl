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


