repo system 0 empty
repo test 0 testtags <inline>
#>=Pkg: X 1 1 noarch
#>=Req: Y
#>=Pkg: B 1 1 noarch
#>=Prv: Y = 2
#>=Pkg: C 1 1 noarch
#>=Prv: Y = 1.1
#>=Pkg: A 1 1 noarch
#>=Prv: Y = 1
system i686 rpm system
job install name X
result transaction,problems <inline>
#>install B-1-1.noarch@test
#>install X-1-1.noarch@test
