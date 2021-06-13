# Test file for registry::entry
# Syntax:
# tclsh entry.tcl registry.dylib

proc main {pextlibname} {
    load $pextlibname

    # totally lame that file delete won't do it
    exec -ignorestderr rm -f {*}[glob -nocomplain test.db*]

    # can't create registry in some brain-dead place or in protected place
    test_throws {registry::open /some/brain/dead/place} registry::cannot-init
    # This would actually work when testing with sudo :(
    #test_throws {registry::open /etc/macports_test_prot~} registry::cannot-init

    # can't use registry before it's opened
    test_throws {registry::write {}} registry::misuse
    registry::open test.db

    # no nested transactions
    registry::write {
        test_throws {registry::read {}} registry::misuse
    }

    # write transaction
    registry::write {

        # create some (somewhat contrived) ports to play with
        set vim1 [registry::entry create vim 7.1.000 0 +cscope+multibyte 0]
        set vim2 [registry::entry create vim 7.1.002 0 {} 0]
        set vim3 [registry::entry create vim 7.1.002 0 +cscope+multibyte 0]
        set zlib [registry::entry create zlib 1.2.3 1 {} 0]
        set pcre [registry::entry create pcre 7.1 1 +utf8 0]

        # check that their properties can be set
        $vim1 state imaged
        $vim2 state imaged
        $vim3 state installed
        $zlib state installed
        $pcre state imaged

        $vim1 installtype image
        $vim2 installtype image
        $vim3 installtype image
        $zlib installtype direct
        $pcre installtype image

    }

    # check that their properties can be retrieved
    # (also try a read transaction)
    registry::read {
        test_equal {[$vim1 name]} vim
        test_equal {[$vim2 epoch]} 0
        test_equal {[$vim3 version]} 7.1.002
        test_equal {[$zlib revision]} 1
        test_equal {[$pcre variants]} +utf8
    
        # check that imaged and installed give correct results
        test_set {[registry::entry imaged]} {$vim1 $vim2 $vim3 $zlib $pcre}
        test_set {[registry::entry installed]} {$vim3 $zlib}
        test_set {[registry::entry imaged vim]} {$vim1 $vim2 $vim3}
        test_set {[registry::entry imaged vim 7.1.000]} {$vim1}
        test_set {[registry::entry imaged vim 7.1.002]} {$vim2 $vim3}
        test_set {[registry::entry imaged vim 7.1.002 0 {}]} {$vim2}
        test_set {[registry::entry imaged vim 7.1.002 0 +cscope+multibyte]} \
            {$vim3}

        # try searching for ports
        # note that 7.1.2 != 7.1.002 but the VERSION collation should be smart
        # enough to ignore the zeroes
        test_set {[registry::entry search name vim version 7.1.2]} {$vim2 $vim3}
        test_set {[registry::entry search variants {}]} {$vim2 $zlib}
        test_set {[registry::entry search name -glob vi*]} {$vim1 $vim2 $vim3}
        test_set {[registry::entry search name -regexp {zlib|pcre}]} \
            {$zlib $pcre}

        # test that passing in confusing arguments doesn't crash
        test {[catch {registry::entry search name vim1 --}] == 1}
    }

    # try mapping files and checking their owners
    registry::write {

        test_equal {[registry::entry owner /opt/local/bin/vimtutor]} {}
        test_equal {[$vim3 files]} {}

        $vim1 map {}
        $vim1 map /opt/local/bin/vim
        $vim1 map [list /opt/local/bin/vimdiff /opt/local/bin/vimtutor]
        $vim2 map [$vim1 imagefiles]
        $vim3 map [$vim1 imagefiles]
        test_equal {[registry::entry owner /opt/local/bin/vimtutor]} {}
        test_equal {[$vim3 files]} {}

        $vim3 activate [$vim3 imagefiles]
        test_equal {[registry::entry owner /opt/local/bin/vimtutor]} {$vim3}
        test_equal {[registry::entry owner /opt/local/bin/emacs]} {}

        test_set {[$vim3 imagefiles]} {/opt/local/bin/vim \
            /opt/local/bin/vimdiff /opt/local/bin/vimtutor}
        test_set {[$vim3 files]} [$vim3 imagefiles]
        test_set {[$zlib imagefiles]} {}

        # try activating over files
        test_throws {$vim2 activate [$vim2 imagefiles]} registry::already-active

        # try unmapping and remapping
        $vim3 unmap /opt/local/bin/vimtutor
        test_equal {[registry::entry owner /opt/local/bin/vimtutor]} {}

        $vim3 deactivate /opt/local/bin/vim
        test_equal {[registry::entry owner /opt/local/bin/vim]} {}
        $vim3 unmap /opt/local/bin/vim
        test_equal {[registry::entry owner /opt/local/bin/vim]} {}
        $vim3 map /opt/local/bin/vim
        test_equal {[registry::entry owner /opt/local/bin/vim]} {}
        $vim3 activate /opt/local/bin/vim
        puts [$vim3 files]
        puts [registry::entry owner /opt/local/bin/vim]
        test_equal {[registry::entry owner /opt/local/bin/vim]} {$vim3}

        # activate to a different location
        $vim3 deactivate /opt/local/bin/vimdiff
        $vim3 activate /opt/local/bin/vimdiff /opt/local/bin/vimdiff.0
        $vim2 activate /opt/local/bin/vimdiff
        test_set {[$vim3 files]} {/opt/local/bin/vim /opt/local/bin/vimdiff.0}
        test_set {[$vim3 imagefiles]} {/opt/local/bin/vim \
            /opt/local/bin/vimdiff}
        test_equal {[registry::entry owner /opt/local/bin/vimdiff]} {$vim2}
        test_equal {[registry::entry owner /opt/local/bin/vimdiff.0]} {$vim3}

        # make sure you can't unmap a file you don't own
        test_throws {$zlib unmap [list /opt/local/bin/vim]} registry::invalid
        test_throws {$zlib unmap [list /opt/local/bin/emacs]} registry::invalid
    }

    test_set {[$vim3 imagefiles]} {/opt/local/bin/vim /opt/local/bin/vimdiff}
    test_set {[$vim3 files]} {/opt/local/bin/vim /opt/local/bin/vimdiff.0}

    # try some deletions
    test_set {[registry::entry installed zlib]} {$zlib}
    test_set {[registry::entry imaged pcre]} {$pcre}

    # try rolling a deletion back
    registry::write {
        registry::entry delete $zlib
        break
    }
    test_equal {[registry::entry open zlib 1.2.3 1 {} 0]} {$zlib}

    # try actually deleting something
    registry::entry delete $pcre
    test_throws {registry::entry open pcre 7.1 1 +utf8 0} \
        registry::not-found
    test {![registry::entry exists $pcre]}

    # close vim1
    test {[registry::entry exists $vim1]}
    registry::entry close $vim1
    test {![registry::entry exists $vim1]}

    # close the registry; make sure the registry isn't usable after being
    # closed, then ensure state persists between open sessions
    registry::close
    test_throws {registry::entry search} registry::misuse
    test {![registry::entry exists $vim3]}
    registry::open test.db

    # check that the same vim is installed from before
    set vim3 [registry::entry installed vim]
    test_equal {[$vim3 version]} 7.1.002

    # find the zlib we inserted before
    set zlib [registry::entry open zlib 1.2.3 1 {} 0]
    test {[registry::entry exists $zlib]}

    # check that pcre is still gone
    test_throws {registry::entry open pcre 7.1 1 +utf8 0} \
        registry::not-found

    registry::close

    file delete -force test.db test.db-shm test.db-wal
}

source tests/common.tcl
main $argv
