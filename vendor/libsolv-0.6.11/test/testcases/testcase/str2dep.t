# testcase for testcase_str2dep and testcase_dep2str

#
# first test literal escaping
#
genid dep <NULL>
result genid <inline>
#>genid  1: genid null
#>genid dep <NULL>
nextjob

genid dep \00
result genid <inline>
#>genid  1: genid lit 
#>genid dep \00
nextjob

genid dep \21\20\22\23\24\25\26\27\28\29\2a\2b\2c\2d\2e\2f\3a\3b\3c\3d\3e\3f\40\5b\5c\5d\5e\5f\60\7b\7c\7d\7e
result genid <inline>
#>genid  1: genid lit ! "#$%&'()*+,-./:;<=>?@[\]^_`{|}~
#>genid dep \21\20"#$%&'\28\29*+,-./:;<=>?@[\5c]^_`{|}~
# make vim happy again: '
nextjob

genid dep foo(bar)
result genid <inline>
#>genid  1: genid lit foo(bar)
#>genid dep foo(bar)
nextjob

genid dep foo()bar\29
result genid <inline>
#>genid  1: genid lit foo()bar)
#>genid dep foo\28\29bar\29
nextjob

#
# test namespace hack
#
genid dep namespace:foo(bar)
result genid <inline>
#>genid  1: genid lit namespace:foo
#>genid  2: genid lit bar
#>genid  3: genid op <NAMESPACE>
#>genid dep namespace:foo(bar)
nextjob
genid lit namespace:foo(bar)
result genid <inline>
#>genid  1: genid lit namespace:foo(bar)
#>genid dep namespace\3afoo\28bar\29
nextjob

#
# test :any hack
#
genid dep foo:any
result genid <inline>
#>genid  1: genid lit foo
#>genid  2: genid lit any
#>genid  3: genid op <MULTIARCH>
#>genid dep foo:any
nextjob
genid lit foo:any
result genid <inline>
#>genid  1: genid lit foo:any
#>genid dep foo\3aany
nextjob

#
# test simple ops
#
genid dep foo < 1-1
result genid <inline>
#>genid  1: genid lit foo
#>genid  2: genid lit 1-1
#>genid  3: genid op <
#>genid dep foo < 1-1
nextjob

genid dep foo = 1-1
result genid <inline>
#>genid  1: genid lit foo
#>genid  2: genid lit 1-1
#>genid  3: genid op =
#>genid dep foo = 1-1
nextjob

genid dep foo > 1-1
result genid <inline>
#>genid  1: genid lit foo
#>genid  2: genid lit 1-1
#>genid  3: genid op >
#>genid dep foo > 1-1
nextjob

genid dep foo >= 1-1
result genid <inline>
#>genid  1: genid lit foo
#>genid  2: genid lit 1-1
#>genid  3: genid op >=
#>genid dep foo >= 1-1
nextjob

genid dep foo <= 1-1
result genid <inline>
#>genid  1: genid lit foo
#>genid  2: genid lit 1-1
#>genid  3: genid op <=
#>genid dep foo <= 1-1
nextjob

# test arch op
genid dep foo . i586
result genid <inline>
#>genid  1: genid lit foo
#>genid  2: genid lit i586
#>genid  3: genid op .
#>genid dep foo . i586
nextjob

# test haiku compat dep
genid dep foo = 2-1 compat >= 1-1
result genid <inline>
#>genid  1: genid lit foo
#>genid  2: genid lit 2-1
#>genid  3: genid lit 1-1
#>genid  4: genid op compat >=
#>genid  5: genid op =
#>genid dep foo = 2-1 compat >= 1-1
nextjob

#
# test complex (aka rich) deps
#

genid dep foo & bar
result genid <inline>
#>genid  1: genid lit foo
#>genid  2: genid lit bar
#>genid  3: genid op &
#>genid dep foo & bar
nextjob

genid dep foo & bar & baz
result genid <inline>
#>genid  1: genid lit foo
#>genid  2: genid lit bar
#>genid  3: genid lit baz
#>genid  4: genid op &
#>genid  5: genid op &
#>genid dep foo & bar & baz
nextjob

genid dep foo & bar | baz
result genid <inline>
#>genid  1: genid lit foo
#>genid  2: genid lit bar
#>genid  3: genid lit baz
#>genid  4: genid op |
#>genid  5: genid op &
#>genid dep foo & (bar | baz)
nextjob

genid dep (foo & bar) | baz
result genid <inline>
#>genid  1: genid lit foo
#>genid  2: genid lit bar
#>genid  3: genid op &
#>genid  4: genid lit baz
#>genid  5: genid op |
#>genid dep (foo & bar) | baz
nextjob

genid dep (foo & bar > 2) | baz
result genid <inline>
#>genid  1: genid lit foo
#>genid  2: genid lit bar
#>genid  3: genid lit 2
#>genid  4: genid op >
#>genid  5: genid op &
#>genid  6: genid lit baz
#>genid  7: genid op |
#>genid dep (foo & bar > 2) | baz
nextjob

