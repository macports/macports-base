repo system 0 testtags <inline>
#>=Pkg: A 1 1 noarch
#>=Pkg: B 1 1 noarch
repo test 0 testtags <inline>
#>=Pkg: A 2 1 noarch
#>=Obs: B
system i686 rpm system

solverflags keepexplicitobsoletes
job multiversion name A
job install name A = 2
result transaction,problems <inline>
#>erase B-1-1.noarch@system
#>install A-2-1.noarch@test

nextjob
solverflags keepexplicitobsoletes
poolflags noobsoletesmultiversion
job multiversion name A
job install name A = 2
result transaction,problems <inline>
#>erase B-1-1.noarch@system
#>install A-2-1.noarch@test

nextjob
poolflags !noobsoletesmultiversion
job multiversion name A
job install name A = 2
result transaction,problems <inline>
#>install A-2-1.noarch@test
