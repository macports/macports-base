repo system 0 testtags <inline>
#>=Pkg: a 1 1 i686
#>=Pkg: b 1 1 i686
repo available 0 testtags <inline>
#>=Pkg: a 2 1 i586
#>=Pkg: b 2 1 i586
#>=Pkg: b 2 1 i686
system i686 * system
solverflags !dupallowarchchange
job distupgrade all packages
result transaction,problems <inline>
#>problem c43b1300 info problem with installed package a-1-1.i686
#>problem c43b1300 solution c43b1300 replace a-1-1.i686@system a-2-1.i586@available
#>upgrade a-1-1.i686@system a-2-1.i586@available
#>upgrade b-1-1.i686@system b-2-1.i686@available
