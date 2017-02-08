repo system 0 testtags <inline>
#>=Pkg: A 1 1 noarch
#>=Req: B1
#>=Pkg: B1 1 1 noarch
repo test 0 testtags <inline>
#>=Pkg: A 1 2 noarch
#>=Req: B1
#>=Pkg: A 2 1 noarch
#>=Req: B2 = 1
#>=Pkg: B1 1 1 noarch
#>=Pkg: B2 1 1 noarch
system i686 rpm system

# check untargeted
job distupgrade name A [cleandeps]
result transaction,problems <inline>
#>erase B1-1-1.noarch@system
#>install B2-1-1.noarch@test
#>upgrade A-1-1.noarch@system A-2-1.noarch@test

# check targeted
nextjob
job distupgrade name A = 2 [cleandeps]
result transaction,problems <inline>
#>erase B1-1-1.noarch@system
#>install B2-1-1.noarch@test
#>upgrade A-1-1.noarch@system A-2-1.noarch@test

# check targeted to 1-2
nextjob
job distupgrade name A = 1-2 [cleandeps]
result transaction,problems <inline>
#>upgrade A-1-1.noarch@system A-1-2.noarch@test
