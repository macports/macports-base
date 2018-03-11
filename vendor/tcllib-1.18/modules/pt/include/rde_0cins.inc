[call [arg objectName] [method i_[vset IFAIL]/[vset IOKX]]]

This method is a convenient combination of control flow and the two
PARAM instructions [cmd [vset IFAIL]] and [cmd [vset IOK]]. The former
is executed for "ST == fail", the latter for "ST == ok".
