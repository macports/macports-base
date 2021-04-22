
[//000000001]: # (units \- Convert and manipulate quantities with units)
[//000000002]: # (Generated from file 'units\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2000\-2005 Mayo Foundation)
[//000000004]: # (units\(n\) 1\.2 tcllib "Convert and manipulate quantities with units")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

units \- unit conversion

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [UNIT STRING FORMAT](#section3)

      - [Example Valid Unit Strings](#subsection1)

  - [SI UNITS](#section4)

      - [SI Base Units](#subsection2)

      - [SI Derived Units with Special Names](#subsection3)

      - [SI Prefixes](#subsection4)

      - [Non\-SI Units](#subsection5)

      - [Quantities and Derived Units with Special Names](#subsection6)

  - [REFERENCES](#section5)

  - [AUTHORS](#section6)

  - [Bugs, Ideas, Feedback](#section7)

  - [Keywords](#keywords)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.1  
package require units ?2\.1?  

[__::units::convert__ *value* *targetUnits*](#1)  
[__::units::reduce__ *unitString*](#2)  
[__::units::new__ *name* *baseUnits*](#3)  

# <a name='description'></a>DESCRIPTION

This library provides a conversion facility from a variety of scientific and
engineering shorthand notations into floating point numbers\. This allows
application developers to easily convert values with different units into
uniformly scaled numbers\.

The units conversion facility is also able to convert between compatible units\.
If, for example, a application is expecting a value in *ohms* \(Resistance\),
and the user specifies units of *milliwebers/femtocoulomb*, the conversion
routine will handle it appropriately\. An error will be generated if an incorrect
conversion is attempted\.

Values are scaled from one set of units to another by dimensional analysis\. Both
the value units and the target units are reduced into primitive units and a
scale factor\. Units are checked for compatibility, and the scale factors are
applied by multiplication and division\. This technique is extremely flexible and
quite robust\.

New units and new unit abbreviations can be defined in terms of existing units
and abbreviations\. It is also possible to define a new primitive unit, although
that will probably be unnecessary\. New units will most commonly be defined to
accommodate non\-SI measurement systems, such as defining the unit *inch* as
*2\.54 cm*\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::units::convert__ *value* *targetUnits*

    Converts the *value* string into a floating point number, scaled to the
    specified *targetUnits*\. The *value* string may contain a number and
    units\. If units are specified, then they must be compatible with the
    *targetUnits*\. If units are not specified for the *value*, then it will
    be scaled to the target units\. For example,

        % ::units::convert "2.3 miles" km
        3.7014912
        % ::units::convert 300m/s miles/hour
        671.080887616
        % ::units::convert "1.0 m kg/s^2" newton
        1.0
        % ::units::convert 1.0 millimeter
        1000.0

  - <a name='2'></a>__::units::reduce__ *unitString*

    Returns a unit string consisting of a scale factor followed by a space
    separated list of sorted and reduced primitive units\. The reduced unit
    string may include a forward\-slash \(separated from the surrounding primitive
    subunits by spaces\) indicating that the remaining subunits are in the
    denominator\. Generates an error if the *unitString* is invalid\.

        % ::units::reduce pascal
        1000.0 gram / meter second second

  - <a name='3'></a>__::units::new__ *name* *baseUnits*

    Creates a new unit conversion with the specified name\. The new unit *name*
    must be only alphabetic \(upper or lower case\) letters\. The *baseUnits*
    string can consist of any valid units conversion string, including constant
    factors, numerator and denominator parts, units with prefixes, and
    exponents\. The baseUnits may contain any number of subunits, but it must
    reduce to primitive units\. BaseUnits could also be the string *\-primitive*
    to represent a new kind of quantity which cannot be derived from other
    units\. But you probably would not do that unless you have discovered some
    kind of new universal property\.

        % ::units::new furlong "220 yards"
        % ::units::new fortnight "14 days"
        % ::units::convert 100m/s furlongs/fortnight
        601288.475303

# <a name='section3'></a>UNIT STRING FORMAT

Value and unit string format is quite flexible\. It is possible to define
virtually any combination of units, prefixes, and powers\. Valid unit strings
must conform to these rules\.

  - A unit string consists of an optional scale factor followed by zero or more
    subunits\. The scale factor must be a valid floating point number, and may or
    may not be separated from the subunits\. The scale factor could be negative\.

  - Subunits are separated form each other by one or more separator characters,
    which are space \(" "\), hyphen \("\-"\), asterisk \("\*"\), and forward\-slash
    \("/"\)\. Sure, go ahead and complain about using a minus sign \("\-"\) to
    represent multiplication\. It just isn't sound mathematics, and, by rights,
    we should require everyone to use the asterisk \("\*"\) to separate all units\.
    But the bottom line is that complex unit strings like *m\-kg/s^2* are
    pleasantly readable\.

  - The forward\-slash seperator \("/"\) indicates that following subunits are in
    the denominator\. There can be at most one forward\-slash separator\.

  - Subunits can be floating point scale factors, but with the exception of the
    leading scale factor, they must be surrounded by valid separators\. Subunit
    scale factors cannot be negative\. \(Remember that the hyphen is a unit
    separator\.\)

  - Subunits can be valid units or abbreviations\. They may include a prefix\.
    They may include a plural suffix "s" or "es"\. They may also include a power
    string denoted by a circumflex \("^"\), followed by a integer, after the unit
    name \(or plural suffix, if there is one\)\. Negative exponents are not
    allowed\. \(Remember that the hyphen is a unit separator\.\)

## <a name='subsection1'></a>Example Valid Unit Strings

    Unit String              Reduced Unit String
    ------------------------------------------------------------
    meter                    1.0 meter
    kilometer                1000.0 meter
    km                       1000.0 meter
    km/s                     1000.0 meter / second
    /microsecond             1000000.0 / second
    /us                      1000000.0 / second
    kg-m/s^2                 1000.0 gram meter / second second
    30second                 30.0 second
    30 second                30.0 second
    30 seconds               30.0 second
    200*meter/20.5*second    9.75609756098 meter / second

# <a name='section4'></a>SI UNITS

The standard SI units are predefined according to *NIST Special* *Publication
330* \. Standard units for both SI Base Units \(Table 1\) and SI Derived Units
with Special Names \(Tables 3a and 3b\) are included here for reference\. Each
standard unit name and abbreviation are included in this package\.

## <a name='subsection2'></a>SI Base Units

    Quantity                Unit Name    Abbr.
    ---------------------------------------------
    Length                  meter        m
    Mass                    kilogram     kg
    Time                    second       s
    Current                 ampere       A
    Temperature             kelvin       K
    Amount                  mole         mol
    Luminous Intensity      candela      cd

## <a name='subsection3'></a>SI Derived Units with Special Names

    Quantity                Unit Name    Abbr.   Units     Base Units
    --------------------------------------------------------------------
    plane angle             radian      rad     m/m       m/m
    solid angle             steradian   sr      m^2/m^2   m^2/m^2
    frequency               hertz       Hz                /s
    force                   newton      N                 m-kg/s^2
    pressure                pascal      Pa      N/m^2     kg/m-s^2
    energy, work            joule       J       N-m       m^2-kg/s^2
    power, radiant flux     watt        W       J/s       m^2-kg/s^3
    electric charge         coulomb     C                 s-A
    electric potential      volt        V       W/A       m^2-kg/s^3-A
    capacitance             farad       F       C/V       s^4-A^2/m^2-kg
    electric resistance     ohm                 V/A       m^2-kg/s^3-A^2
    electric conductance    siemens     S       A/V       s^3-A^2/m^2-kg
    magnetic flux           weber       Wb      V-s       m^2-kg/s^2-A
    magnetic flux density   tesla       T       Wb/m^2    kg/s^2-A
    inductance              henry       H       Wb/A      m^2-kg/s^2-A^2
    luminous flux           lumen       lm                cd-sr
    illuminance             lux         lx      lm/m^2    cd-sr/m^2
    activity (of a
    radionuclide)           becquerel   Bq                /s
    absorbed dose           gray        Gy      J/kg      m^2/s^2
    dose equivalent         sievert     Sv      J/kg      m^2/s^2

Note that the SI unit kilograms is actually implemented as grams because 1e\-6
kilogram = 1 milligram, not 1 microkilogram\. The abbreviation for Electric
Resistance \(ohms\), which is the omega character, is not supported\.

Also note that there is no support for Celsius or Farenheit temperature\. The
units conversion routines can only scale values with multiplication and
division, so it is not possible to convert from thermodynamic temperature
\(kelvins\) to absolute degrees Celsius or Farenheit\. Conversion of thermodynamic
quantities, such as thermal expansion \(per unit temperature\), however, are easy
to add to the units library\.

SI Units can have a multiple or sub\-multiple prefix\. The prefix or its
abbreviation should appear before the unit, without spaces\. Compound prefixes
are not allowed, and a prefix should never be used alone\. These prefixes are
defined in Table 5 of *Special Publication* *330* \.

## <a name='subsection4'></a>SI Prefixes

    Prefix Name     Abbr.   Factor
    ---------------------------------------
    yotta           Y       1e24
    zetta           Z       1e21
    exa             E       1e18
    peta            P       1e15
    tera            T       1e12
    giga            G       1e9
    mega            M       1e6
    kilo            k       1e3
    hecto           h       1e2
    deka            da      1e1
    deca                    1e1

    deci            d       1e-1
    centi           c       1e-2
    milli           m       1e-3
    micro           u       1e-6
    nano            n       1e-9
    pico            p       1e-12
    femto           f       1e-15
    atto            a       1e-18
    zepto           z       1e-21
    yocto           y       1e-24

Note that we define the same prefix with both the USA \("deka"\) and non\-USA
\("deca"\) spellings\. Also note that we take the liberty of allowing "micro" to be
typed as a "u" instead of the Greek character mu\.

Many non\-SI units are commonly used in applications\. Appendix B\.8 of *NIST
Special Publication 811* lists many non\-SI conversion factors\. It is not
possible to include all possible unit definitions in this package\. In some
cases, many different conversion factors exist for a given unit, depending on
the context\. \(The appendix lists over 40 conversions for British thermal units\!\)
Application specific conversions can always be added using the __new__
command, but some well known and often used conversions are included in this
package\.

## <a name='subsection5'></a>Non\-SI Units

    Unit Name            Abbr.    Base Units
    --------------------------------------------------
    angstrom                      1.0E-10 m
    astronomicalUnit     AU       1.495979E11 m
    atmosphere                    1.01325E5 Pa
    bar                           1.0E5 Pa
    calorie                       4.1868 J
    curie                         3.7E10 Bq
    day                           8.64E4 s
    degree                        1.745329E-2 rad
    erg                           1.0E-7 J
    faraday                       9.648531 C
    fermi                         1.0E-15 m
    foot                 ft       3.048E-1 m
    gauss                         1.0E-4 T
    gilbert                       7.957747E-1 A
    grain                gr       6.479891E-5 kg
    hectare              ha       1.0E4 m^2
    hour                 h        3.6E3 s
    inch                 in       2.54E-2 m
    lightYear                     9.46073E15 m
    liter                L        1.0E-3 m^3
    maxwell              Mx       1.0E-8 Wb
    mho                           1.0 S
    micron                        1.0E-6 m
    mil                           2.54E-5 m
    mile                 mi       1.609344E3 m
    minute               min      6.0E1 s
    parsec               pc       3.085E16 m
    pica                          4.233333E-3 m
    pound                lb       4.535924E-1 kg
    revolution                    6.283185 rad
    revolutionPerMinute  rpm      1.047198E-1 rad/s
    yard                 yd       9.144E-1 m
    year                          3.1536E7 s

## <a name='subsection6'></a>Quantities and Derived Units with Special Names

This units conversion package is limited specifically to unit reduction,
comparison, and scaling\. This package does not consider any of the quantity
names for either base or derived units\. A similar implementation or an extension
in a typed or object\-oriented language might introduce user defined types for
the quantities\. Quantity type checking could be used, for example, to ensure
that all *length* values properly reduced to *meters*, or that all
*velocity* values properly reduced to *meters/second*\.

A C implementation of this package has been created to work in conjunction with
the Simplified Wrapper Interface Generator
\([http://www\.swig\.org/](http://www\.swig\.org/)\)\. That package \(units\.i\)
exploits SWIG's typemap system to automatically convert script quantity strings
into floating point quantities\. Function arguments are specified as quantity
types \(e\.g\., *typedef float Length*\), and target units \(expected by the C
application code\) are specified in an associative array\. Default units are also
defined for each quantity type, and are applied to any unit\-less quantity
strings\.

A units system enhanced with quantity type checking might benefit from inclusion
of other derived types which are expressed in terms of special units, as
illustrated in Table 2 of *NIST Publication* *330* \. The quantity *area*,
for example, could be defined as units properly reducing to *meter^2*,
although the utility of defining a unit named *square meter* is arguable\.

# <a name='section5'></a>REFERENCES

The unit names, abbreviations, and conversion values are derived from those
published by the United States Department of Commerce Technology Administration,
National Institute of Standards and Technology \(NIST\) in *NIST Special
Publication 330: The International System of* *Units \(SI\)* and *NIST Special
Publication 811: Guide for* *the Use of the International System of Units
\(SI\)* \. Both of these publications are available \(as of December 2000\) from
[http://physics\.nist\.gov/cuu/Reference/contents\.html](http://physics\.nist\.gov/cuu/Reference/contents\.html)

The ideas behind implementation of this package is based in part on code written
in 1993 by Adrian Mariano which performed dimensional analysis of unit strings
using fixed size tables of C structs\. After going missing in the late 1990's,
Adrian's code has reappeared in the GNU Units program at
[http://www\.gnu\.org/software/units/](http://www\.gnu\.org/software/units/)

# <a name='section6'></a>AUTHORS

Robert W\. Techentin

# <a name='section7'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *units* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[angle](\.\./\.\./\.\./\.\./index\.md\#angle),
[constants](\.\./\.\./\.\./\.\./index\.md\#constants),
[conversion](\.\./\.\./\.\./\.\./index\.md\#conversion),
[distance](\.\./\.\./\.\./\.\./index\.md\#distance),
[radians](\.\./\.\./\.\./\.\./index\.md\#radians),
[unit](\.\./\.\./\.\./\.\./index\.md\#unit)

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2000\-2005 Mayo Foundation
