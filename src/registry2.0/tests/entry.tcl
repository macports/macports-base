# $Id$
# Test file for registry::item
# Syntax:
# tclsh item.tcl <Pextlib name>

proc main {pextlibname} {
    load $pextlibname

	file delete [glob -nocomplain test.db*]

    # can't create registry in some brain-dead place or in protected place
    test_throws {registry::open /some/brain/dead/place} registry::cannot-init
    test_throws {registry::open /etc/macports_test~} registry::cannot-init

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
        set vim1 [registry::entry create vim 7.1.000 0 {multibyte +} 0]
        set vim2 [registry::entry create vim 7.1.002 0 {} 0]
        set vim3 [registry::entry create vim 7.1.002 0 {multibyte +} 0]
        set zlib [registry::entry create zlib 1.2.3 1 {} 0]
        set pcre [registry::entry create pcre 7.1 1 {utf8 +} 0]

        # check that their properties can be set
        $vim1 state imaged
        $vim2 state imaged
        $vim3 state installed
        $zlib state installed
        $pcre state imaged

    }

    # check that their properties can be retrieved
    # (also try a read transaction)
    registry::read {
        test_equal {[$vim1 name]} vim
        test_equal {[$vim2 epoch]} 0
        test_equal {[$vim3 version]} 7.1.002
        test_equal {[$zlib revision]} 1
        test_equal {[$pcre variants]} {utf8 +}
    
        # check that imaged and installed give correct results
        # have to sort these because their orders aren't defined
        set imaged [registry::entry imaged]
        test_equal {[lsort $imaged]} {[lsort "$vim1 $vim2 $vim3 $zlib $pcre"]}

        set installed [registry::entry installed]
        test_equal {[lsort $installed]} {[lsort "$vim3 $zlib"]}
    }


    # try searching for ports
    # note that 7.1.2 != 7.1.002 but the VERSION collation should be smart
    # enough to ignore the zeroes
    set vim71002 [registry::entry search name vim version 7.1.2]
    test_equal {[lsort $vim71002]} {[lsort "$vim2 $vim3"]}

    set no_variants [registry::entry search variants {}]
    test_equal {[lsort $no_variants]} {[lsort "$vim2 $zlib"]}

    set vistar [registry::entry search -glob name vi*]
    test_equal {[lsort $vistar]} {[lsort "$vim1 $vim2 $vim3"]}

    set zlibpcre [registry::entry search -regexp name {zlib|pcre}]
    test_equal {[lsort $zlibpcre]} {[lsort "$zlib $pcre"]}

    # try mapping files and checking their owners
    registry::write {
        $vim3 map [list /opt/local/bin/vim]
        $vim3 map [list /opt/local/bin/vimdiff /opt/local/bin/vimtutor]
        test_equal {[registry::entry owner /opt/local/bin/vimtutor]} {$vim3}
        test_equal {[registry::entry owner /opt/local/bin/emacs]} {}

        # don't have to sort because order is defined as alpha
        test_equal {[$vim3 files]} {[list /opt/local/bin/vim \
            /opt/local/bin/vimdiff /opt/local/bin/vimtutor]}
        test_equal {[$zlib files]} {[list]}

        # try unmapping and remapping
        $vim3 unmap {/opt/local/bin/vim}
        test_equal {[registry::entry owner /opt/local/bin/vim]} {}
        $vim3 map {/opt/local/bin/vim}
        test_equal {[registry::entry owner /opt/local/bin/vim]} {$vim3}

        # make sure you can't unmap a file you don't own
        test_throws {$zlib unmap [list /opt/local/bin/vim]} registry::invalid
        test_throws {$zlib unmap [list /opt/local/bin/emacs]} registry::invalid
    }

    # try some deletions
    test_equal {[registry::entry installed zlib]} {$zlib}
    test_equal {[registry::entry imaged pcre]} {$pcre}

    # try rolling a deletion back
    registry::write {
        registry::entry delete $zlib
        break
    }
    test_equal {[registry::entry open zlib 1.2.3 1 {} 0]} {$zlib}

    # try actually deleting something
    registry::entry delete $pcre
    test_throws {registry::entry open pcre 7.1 1 {utf8 +} 0} \
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
    test_throws {registry::entry open pcre 7.1 1 {utf8 +} 0} \
        registry::not-found

    registry::close

	file delete [glob -nocomplain test.db*]
}

source tests/common.tcl
main $argv
