repo system 0 testtags <inline>
#>=Pkg: a 1 1 i686
#>=Pkg: b 2 1 i686
repo available 0 testtags <inline>
#>=Pkg: a 2 1 i586
#>=Con: b = 1-1
#>=Pkg: b 1 1 i586
system i686 * system
solverflags !dupallowarchchange allowuninstall
job distupgrade all packages
result transaction,problems <inline>
#>erase b-2-1.i686@system
#>upgrade a-1-1.i686@system a-2-1.i586@available
