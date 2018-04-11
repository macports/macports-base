repo system 0 testtags <inline>
#>=Pkg: A 1 1 x86_64
#>=Prv: AA
#>=Pkg: B 1 1 x86_64
#>=Prv: AA
system x86_64 * system
job erase provides AA [weak]
job install pkg B-1-1.x86_64@system
result transaction,problems <inline>
