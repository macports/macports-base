repo system 0 testtags <inline>
#>=Pkg: A 1 1 noarch
#>=Vnd: foo
#>=Pkg: D 1 1 noarch
#>=Vnd: foo
#>=Con: A = 3-1
repo available 0 testtags <inline>
#>=Pkg: A 2 1 noarch
#>=Vnd: foo
#>=Pkg: A 3 1 noarch
#>=Vnd: bar
system i686 rpm system

job distupgrade name A [forcebest]
result transaction,problems <inline>
#>erase D-1-1.noarch@system
#>problem 1210fdfb info package D-1-1.noarch conflicts with A = 3-1 provided by A-3-1.noarch
#>problem 1210fdfb solution 0d75a914 erase D-1-1.noarch@system
#>problem 1210fdfb solution d85f7c4e allow A-2-1.noarch@available
#>upgrade A-1-1.noarch@system A-3-1.noarch@available

# test if bestobeypolicy is a noop for dup jobs
nextjob
solverflags bestobeypolicy
job distupgrade name A [forcebest]
result transaction,problems <inline>
#>erase D-1-1.noarch@system
#>problem 1210fdfb info package D-1-1.noarch conflicts with A = 3-1 provided by A-3-1.noarch
#>problem 1210fdfb solution 0d75a914 erase D-1-1.noarch@system
#>problem 1210fdfb solution d85f7c4e allow A-2-1.noarch@available
#>upgrade A-1-1.noarch@system A-3-1.noarch@available
