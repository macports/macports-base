[call [cmd valtype::[vset PACKAGE]] [method 13of] [arg value]]

This method expects an old-style 10-digit ISBN and returns the
canonical modern 13-digit ISBN.

This is used by [method validate] to canonicalize the input, so that
all parts of the system after the validation can expect to work with
modern 13-digit ISBNs.
