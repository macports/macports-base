# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

package provide porttest 1.0

set org.macports.test [target_new org.macports.test porttest::test_main]
target_provides ${org.macports.test} test
target_requires ${org.macports.test} main fetch checksum extract patch configure build destroot
target_prerun ${org.macports.test} porttest::test_start
target_runpkg ${org.macports.test} porttest_run

# define options
options test.asroot test.ignore_archs test.run test.target
commands test

# Set defaults
default test.asroot no
default test.dir {${build.dir}}
default test.cmd {${build.cmd}}
default test.pre_args {${test.target}}
default test.target test
default test.ignore_archs no
