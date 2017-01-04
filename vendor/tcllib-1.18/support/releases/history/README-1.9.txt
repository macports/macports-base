Overview
========

 47 new packages in 9 new modules and 8 modules with new packages.
 58 changed packages.
105 unchanged packages (or non-visible changes, like testsuites)

New in Tcllib 1.9
=================
                                        Tcllib 1.9
Module          Package                 New Version     Comments
------          -------                 -----------     -----------------------
base32          base32                          0.1     Base32 encoding,
                base32::core                    0.1     standard and extended
                base32::hex                     0.1     hex forms
------          -------                 -----------     -----------------------
bench           bench                           0.1     Benchmarking support,
                bench::in                       0.1     generation, import and
                bench::out::csv               0.1.1     export of performance
                bench::out::text              0.1.1     information
------          -------                 -----------     -----------------------
fileutil        fileutil::traverse              0.1     find iterator
grammar_me      grammar::me::cpu::gasm          0.1     graph asm for ME vm
------          -------                 -----------     -----------------------
interp          interp                          0.1     Interpreter utilities,
                interp::delegate::method        0.2     runtime environments,
                interp::delegate::proc          0.2     delegation commands
------          -------                 -----------     -----------------------
json            json                            1.0     JavaScript Object Notation
ldap            ldapx                         0.2.2     OO wrapper around ldap
------          -------                 -----------     -----------------------
math            math::bigfloat                  2.0     Large FP numbers
nmea            nmea                            0.1     NMEA gps messages
otp             otp                           1.0.0     RFC 2289 One-Time Passwd
------          -------                 -----------     -----------------------
page            page::compiler::peg::mecpu      0.1     Generator for MEcpu code
                page::gen::peg::mecpu           0.1     and graph-based compiler
------          -------                 -----------     -----------------------
sasl            SASL::XGoogleToken            1.0.0     X-GOOGLE-TOKEN auth
------          -------                 -----------     -----------------------
term            term                            0.1     Low-level terminal
                term::ansi::code                0.1     control, mainly control
                term::ansi::code::attr          0.1     codes, some reception
                term::ansi::code::ctrl          0.1     processing.
                term::ansi::code::macros        0.1
                term::ansi::ctrl::unix          0.1
                term::ansi::send                0.1
                term::interact::menu            0.1
                term::interact::pager           0.1
                term::receive                   0.1
                term::receive::bind             0.1
                term::send                      0.1
------          -------                 -----------     -----------------------
textutil        textutil::adjust                0.7     Textutil functionality
                textutil::repeat                0.7     split into separate
                textutil::split                 0.7     packages
                textutil::string                0.7
                textutil::tabify                0.7
                textutil::trim                  0.7
------          -------                 -----------     -----------------------
tie             tie::std::growfile              1.0     tie backend, evergrowing
tiff            tiff                            0.1     TIFF image manipulation
------          -------                 -----------     -----------------------
transfer        transfer::connect               0.1     Classes handling and
                transfer::copy                  0.1     organizing various
                transfer::copy::queue           0.1     types of data transfers
                transfer::data::destination     0.1     across sockets.
                transfer::data::source          0.1
                transfer::receiver              0.1
                transfer::transmitter           0.1
------          -------                 -----------     -----------------------

Changes from Tcllib 1.8 to 1.9
==============================

Legend
        API:    ** incompatible ** API changes. > Implies change of major version.
        EF :    Extended functionality, API.    \ Implies change of minor verson.
        I  :    Major rewrite, but no API change/
        B  :    Bug fixes.                     \
        D  :    Documentation updates.          > Implies change of patchlevel.
        EX :    New examples.                   >
        P  :    Performance enhancement.       /

                                Tcllib 1.8      Tcllib 1.9
Module          Package         Old version     New Version     Comments
------          -------         -----------     -----------     ---------------
asn             asn             0.4             0.7             B, EF
blowfish        blowfish        1.0.0           1.0.2           B, D, EF
cmdline         cmdline         1.2.4           1.3             I
comm            comm            4.3             4.4             EF
crc             cksum           1.1.0           1.1.1           B
csv             csv             0.6             0.7             EF
------          -------         -----------     -----------     ---------------
dns             dns             1.3.0           1.3.1           B, EF
                ip              1.1.0           1.1.1           B
------          -------         -----------     -----------     ---------------
doctools        doctools        1.2             1.2.1           B
fileutil        fileutil        1.8             1.9             B, D, EF
ftp             ftp             2.4.2           2.4.4           B
------          -------         -----------     -----------     ---------------
fumagic fileutil::magic::filetype  1.0          1.0.2           B
        fileutil::magic::mimetype  1.0          1.0.2           B
------          -------         -----------     -----------     ---------------
grammar_fa      grammar::fa     0.1.1           0.2             EF
                grammar::fa::op 0.1.1           0.2             EF
------          -------         -----------     -----------     ---------------
grammar_me grammar::me::cpu        0.1          0.2             B, EF
           grammar::me::cpu::core  0.1          0.2             B, EF
------          -------         -----------     -----------     ---------------
html            html            1.3             1.4             B, EF
htmlparse       htmlparse       1.1.1           1.1.2           B
http            autoproxy       1.2.1           1.3             EF
inifile         inifile         0.1.1           0.2             B, EF
irc             irc             0.5             0.6             EF
jpeg            jpeg            0.2             0.3             B, EF
ldap            ldap            1.2.1           1.6.6           B, I, EF
------          -------         -----------     -----------     ---------------
log             logger          0.6.1           0.7             B, EF
                - appender      1.2             1.3             B
                - utils         1.2             1.3             B
------          -------         -----------     -----------     ---------------
math            math             1.2.3          1.2.4           B
                - bigfloat       1.2            1.2.1           B
                - bignum         3.1            3.1.1           B
                - calculus       0.6.1          0.7             B
                - complexnumbers 1.0.1          1.0.2           B
                - fourier        1.0.1          1.0.2           B
                - interpolate    1.0.1          1.0.2           B
                - linearalgebra  1.0            1.0.1           D, B
                - statistics     0.2            0.3             B
------          -------         -----------     -----------     ---------------
md4             md4             1.0.3           1.0.4           B
md5             md5             2.0.4           2.0.5           P
mime            mime            1.4.1           1.5.1           B, EF
ncgi            ncgi            1.3             1.3.2           B, P
ntp             time            1.2             1.2.1           B
profiler        profiler        0.2.3           0.3             EF
rc4             rc4             1.0.1           1.1.0           B, EF
------          -------         -----------     -----------     ---------------
sasl            SASL            1.0.0           1.3.1           B, EF
                SASL::NTLM      1.0.0           1.1.0           B, EF
------          -------         -----------     -----------     ---------------
snit            snit            1.1             1.2             B, D
                snit            2.0             2.1             B, D
------          -------         -----------     -----------     ---------------
stooop          switched        2.2             2.2.1           B
------          -------         -----------     -----------     ---------------
struct          struct::graph   2.0.1           2.1             B, EF
                struct::list    1.5             1.6             EF
                struct::set     2.1             2.1.1           B
                struct::tree    2.1.1           2.1.1           B
------          -------         -----------     -----------     ---------------
tar             tar             0.1             0.2             B, EF
------          -------         -----------     -----------     ---------------
textutil        textutil        0.7             0.7.1           I
                - expander      1.3             1.3.1           B
------          -------         -----------     -----------     ---------------
tie             tie             1.0.1           1.1             EF (growfile)
                tie::std::file  1.0.1           1.0.2           B
------          -------         -----------     -----------     ---------------
treeql          treeql          1.3             1.3.1           B
uri             uri             1.1.5           1.2             EF
------          -------         -----------     -----------     ---------------
