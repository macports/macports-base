# Test file for registry::entry dependencies
# Syntax:
# tclsh depends.tcl registry.dylib

proc main {pextlibname} {
    load $pextlibname

    # totally lame that file delete won't do it
	exec -ignorestderr rm -f {*}[glob -nocomplain test.db*]

    registry::open test.db

    # some really contrived ports to test with
    # this is the dependency graph, roughly:

    #            a1     a2     a3
    #              \   /      /
    #              b1&b2     /
    #              /\ /\    c
    #             f  d  g  /
    #                 \   /
    #                   e

    registry::write {
        set a1 [registry::entry create a 1 0 {} 0]
        set a2 [registry::entry create a 2 0 {} 0]
        set a3 [registry::entry create a 3 0 {} 0]
        $a1 depends b
        $a2 depends b
        $a3 depends c

        set b1 [registry::entry create b 1 0 {} 0]
        set b2 [registry::entry create b 2 0 {} 0]
        $b1 depends d
        $b1 depends f
        $b2 depends d
        $b2 depends g

        set c [registry::entry create c 1 0 {} 0]
        $c depends e

        set d [registry::entry create d 1 0 {} 0]
        $d depends e

        set e [registry::entry create e 1 0 {} 0]
        set f [registry::entry create f 1 0 {} 0]
        set g [registry::entry create g 1 0 {} 0]

        $a1 state installed
        $a2 state imaged
        $a3 state imaged
        $b1 state installed
        $b2 state imaged
        $c state installed
        $d state installed
        $e state installed
        $f state installed
        $g state imaged
    }

    registry::read {
        test_set {[$a1 dependents]} {}
        test_set {[$a2 dependents]} {}
        test_set {[$a3 dependents]} {}
        test_set {[$b1 dependents]} {$a1 $a2}
        test_set {[$b2 dependents]} {$a1 $a2}
        test_set {[$c dependents]} {$a3}
        test_set {[$d dependents]} {$b1 $b2}
        test_set {[$e dependents]} {$c $d}
        test_set {[$f dependents]} {$b1}
        test_set {[$g dependents]} {$b2}

        test_set {[$a1 dependencies]} {$b1 $b2}
        test_set {[$a2 dependencies]} {$b1 $b2}
        test_set {[$a3 dependencies]} {$c}
        test_set {[$b1 dependencies]} {$d $f}
        test_set {[$b2 dependencies]} {$d $g}
        test_set {[$c dependencies]} {$e}
        test_set {[$d dependencies]} {$e}
        test_set {[$e dependencies]} {}
        test_set {[$f dependencies]} {}
        test_set {[$g dependencies]} {}
    }

    file delete -force test.db test.db-shm test.db-wal
}

source tests/common.tcl
main $argv
