[para]

Success and failure of the test are both recorded directly in ST.
Success further clears ES, wheras failure sets the pair of CL and
expected input (encoded as a leaf parsing expression) as the new ES
and then rewinds CL by one character, preparing the machine for
another parse attempt by a possible alternative.
