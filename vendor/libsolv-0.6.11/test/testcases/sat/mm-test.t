#
# testcase to check enabling/disabling of learnt rules
#
repo system 0 testtags <inline>
#>=Ver: 2.0
#>=Pkg: A 1.0 1 noarch
#>=Req: D
#>=Prv: A = 1.0-1
#>=Con: C
#>=Pkg: C 1.0 1 noarch
#>=Prv: foo
#>=Prv: C = 1.0-1
#>=Con: D
#>=Pkg: D 1.0 1 noarch
#>=Prv: D = 1.0-1
#>=Pkg: A2 1.0 1 noarch
#>=Req: D2
#>=Prv: A2 = 1.0-1
#>=Con: C2
#>=Pkg: C2 1.0 1 noarch
#>=Prv: foo
#>=Prv: C2 = 1.0-1
#>=Con: D2
#>=Pkg: D2 1.0 1 noarch
#>=Prv: D2 = 1.0-1
repo test 0 testtags <inline>
#>=Ver: 2.0
#>=Pkg: C 2.0 1 noarch
#>=Prv: C = 2.0-1
#>=Pkg: A 2.0 1 noarch
#>=Prv: A = 2.0-1
#>=Pkg: D 2.0 1 noarch
#>=Prv: D = 2.0-1
#>=Pkg: C2 2.0 1 noarch
#>=Prv: C2 = 2.0-1
#>=Pkg: A2 2.0 1 noarch
#>=Prv: A2 = 2.0-1
#>=Pkg: D2 2.0 1 noarch
#>=Prv: D2 = 2.0-1
#>=Pkg: E 2.0 1 noarch
#>=Req: foo
#>=Prv: E = 2.0-1
system unset * system
job install provides E
job verify all packages
result transaction,problems <inline>
#>erase D-1.0-1.noarch@system
#>erase D2-1.0-1.noarch@system
#>problem a3755a16 info package E-2.0-1.noarch requires foo, but none of the providers can be installed
#>problem a3755a16 solution 6d40bce1 deljob install provides E
#>problem a3755a16 solution c06ed43e erase D-1.0-1.noarch@system
#>problem a3755a16 solution c8a04f77 erase D2-1.0-1.noarch@system
#>upgrade A-1.0-1.noarch@system A-2.0-1.noarch@test
#>upgrade A2-1.0-1.noarch@system A2-2.0-1.noarch@test
