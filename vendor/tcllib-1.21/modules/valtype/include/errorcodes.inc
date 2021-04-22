

The validation type in this package is able to 




INVALID <> CHAR		- Unexpected, incorrect character in input		for <> type of thing.
INVALID <> CHECK-DIGIT	- Validation of the check digit in the input failed	for <> type of thing.
INVALID <> LENGTH	- Unexpected, incorrect length of the input		for <> type of thing.
INVALID <> PREFIX	- Unexpected, incorrect prefix characters in the input	for <> type of thing.

<> currently in

	LUHN		- Unadorned luhn check digit
	LUHN5		- Unadorned luhn 10+5 check digit
	VERHOEFF	- Unadorned verhoeff check digit
	IMEI		- International Mobile Equipment Identity
			  14 digit number + luhn check digit.
	USNPI		- US National Provider Identifier (Medicare)
	ISBN		- International Standard Book Number (-10 and -13 variants)
			  (ISBN13 is a subset of EAN13)
	EAN13		- International Article Number

	CREDITCARD VISA	      - VISA creditcard number.
	CREDITCARD AMEX	      - AMerican EXpress creditcard number.
	CREDITCARD DISCOVER   - Discovery creditcard number
	CREDITCARD MASTERCARD - MasterCard creditcard number

// not yet full there
	EAN8		- Ditto, a reduced form using only 8 characters
