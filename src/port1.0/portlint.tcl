# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portlint_run.tcl

package provide portlint 1.0

set org.macports.lint [target_new org.macports.lint portlint::lint_main]
target_runtype ${org.macports.lint} always
target_state ${org.macports.lint} no
target_provides ${org.macports.lint} lint
target_requires ${org.macports.lint} main
target_prerun ${org.macports.lint} portlint::lint_start
target_runpkg ${org.macports.lint} portlint_run
