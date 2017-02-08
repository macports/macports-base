repo system 0 testtags <inline>
#>=Ver: 2
#>=Pkg: B 1 1 noarch
#>=Prv: locale(en)
#>=Pkg: C 1 1 noarch
repo test 0 testtags <inline>
#>=Ver: 2
#>=Pkg: A 1 1 noarch
#>=Prv: locale(de)
#>=Pkg: C-de 1 1 noarch
#>=Prv: locale(C:de)
#>=Pkg: C-en 1 1 noarch
#>=Prv: locale(C:en)
system i686 rpm system

# first test an empty job
namespace namespace:language(de) @SYSTEM
result transaction,problems <inline>

# then test addalreadyrecommended
nextjob
namespace namespace:language(de) @SYSTEM
solverflags addalreadyrecommended
result transaction,problems <inline>
#>install A-1-1.noarch@test
#>install C-de-1-1.noarch@test

nextjob
namespace namespace:language(de) @SYSTEM
job install provides namespace:language(de)
result transaction,problems <inline>
#>install A-1-1.noarch@test
#>install C-de-1-1.noarch@test

nextjob
namespace namespace:language(de) @SYSTEM
job erase provides namespace:language(en) [cleandeps]
result transaction,problems <inline>
#>erase B-1-1.noarch@system

nextjob
namespace namespace:language(de) @SYSTEM
job install provides namespace:language(<NULL>)
result transaction,problems <inline>
#>install A-1-1.noarch@test
#>install C-de-1-1.noarch@test

nextjob
namespace namespace:language(de) @SYSTEM
job erase provides namespace:language(<NULL>) [cleandeps]
result transaction,problems <inline>
#>erase B-1-1.noarch@system

nextjob
namespace namespace:language(de) @SYSTEM
job install provides namespace:language(<NULL>)
job erase provides namespace:language(<NULL>) [cleandeps]
result transaction,problems <inline>
#>erase B-1-1.noarch@system
#>install A-1-1.noarch@test
#>install C-de-1-1.noarch@test
