repo system 0 testtags <inline>
#>=Pkg: A 1 1 noarch
#>=Req: B1
#>=Pkg: B1 1 1 noarch
repo test 0 testtags <inline>
#>=Pkg: A 2 1 noarch
#>=Req: B2 = 1
#>=Pkg: B1 1 1 noarch
#>=Pkg: B2 1 1 noarch
system i686 rpm system
job install name A = 2 [cleandeps]
result transaction,problems <inline>
#>erase B1-1-1.noarch@system
#>install B2-1-1.noarch@test
#>upgrade A-1-1.noarch@system A-2-1.noarch@test
