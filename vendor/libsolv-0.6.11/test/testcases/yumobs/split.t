repo system 0 testtags <inline>
#>=Ver: 2.0
#>=Pkg: c 27 1 x86_64
repo available 0 testtags <inline>
#>=Ver: 2.0
#>=Pkg: d 28 1 x86_64
#>=Obs: c
#>=Pkg: e 28 1 x86_64
#>=Obs: c

system x86_64 rpm system

job update all packages
result transaction,problems <inline>
#>erase c-27-1.x86_64@system d-28-1.x86_64@available
#>install d-28-1.x86_64@available

nextjob
solverflags yumobsoletes
job update all packages
result transaction,problems <inline>
#>erase c-27-1.x86_64@system d-28-1.x86_64@available
#>install d-28-1.x86_64@available
#>install e-28-1.x86_64@available
