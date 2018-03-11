New in Tcllib 1.8
=================
                                        Tcllib 1.8
Module          Package                 New Version     Comments
------          -------                 -----------     -------------------------------
aes             aes                     1.0.0           AES Encryption
bibtex          bibtex                  0.5             Processing of BibTeX bibliographies
blowfish        blowfish                1.0.0           Blowfish Encryption
------          -------                 -----------     -------------------------------
des             tclDES                  1.0.0           DES encryption
                tclDESjr                1.0.0
------          -------                 -----------     -------------------------------
docstrip        docstrip                1.2             Literate programming tools
                docstrip::util          1.2
------          -------                 -----------     -------------------------------
fumagic         fileutil::magic::filetype 1.0           File types basic on magic numbers.
                fileutil::magic::mimetype 1.0
------          -------                 -----------     -------------------------------
grammar_me      grammar::me::cpu        0.1             Match Engine. Foundation for
                grammar::me::cpu::core  0.1             parsers.
                grammar::me::tcl        0.1
                grammar::me::util       0.1
------          -------                 -----------     -------------------------------
grammar_peg     grammar::peg            0.1             Container for Parsing Expression
                grammar::peg::interp    0.1             Grammars, PEG interpreter.
------          -------                 -----------     -------------------------------
log             logger::appender        1.2             Utilities for logger.
                logger::utils           1.2
------          -------                 -----------     -------------------------------
math            math::bigfloat          1.2             Arbitrary-precision floating point.
                math::linearalgebra     1.0             Matrix & vector processing.
		math::roman             1.0             Handling of roman numerals.
------          -------                 -----------     -------------------------------
page            page::analysis::*       0.1             Parser generator packages. Plugin
                page::config::peg       0.1             based. Can be used for arbitrary
                page::gen::*            0.1             text processing as well because
                page::parse::*          0.1             of that.
                page::pluginmgr         0.1
                page::reader::*         0.1
                page::transform::*      0.1
                page::util::*           0.1
                page::writer::*         0.1
------          -------                 -----------     -------------------------------
pluginmgr       pluginmgr               0.1             Generic plugin management.
rcs             rcs                     0.1             Processing of RCS patches.
sha             sha256                  1.0.1           Extended SHA hash
------          -------                 -----------     -------------------------------
sasl            SASL                    1.0.0           Simple Authentication & Security Layer
                SASL::NTLM              1.0.0
------          -------                 -----------     -------------------------------
snit            snit                    2.0             Snit for Tcl 8.5
units           units                   2.1             Unit conversions.
------          -------                 -----------     -------------------------------


Changes from Tcllib 1.7 to 1.8
==============================

Legend
        API:    ** incompatible ** API changes. > Implies change of major version.
        EF :    Extended functionality, API.    \ Implies change of minor verson.
        I  :    Major rewrite, but no API change/
        B  :    Bug fixes.                     \
        D  :    Documentation updates.          > Implies change of patchlevel.
        EX :    New examples.                   >
        P  :    Performance enhancement.       /
        TS :    Test suite fix                 /

                                Tcllib 1.7      Tcllib 1.8
Module          Package         Old version     New Version     Comments
------          -------         -----------     -----------     -------------------------------
asn             asn             0.1             0.4             EF, B, TS, D
------          -------         -----------     -----------     -------------------------------
base64          uuencode        1.1.2           1.1.3           TS
                base64          2.3.1           2.3.2           D
------          -------         -----------     -----------     -------------------------------
cmdline         cmdline         1.2.3           1.2.4           B, TS
------          -------         -----------     -----------     -------------------------------
comm            comm            4.2.1           4.3             D, EF
------          -------         -----------     -----------     -------------------------------
control         control         0.1.2           0.1.3           TS
------          -------         -----------     -----------     -------------------------------
counter         counter         2.0.3           2.0.4           B
------          -------         -----------     -----------     -------------------------------
crc             crc32           1.2             1.3             TS, B, I
                crc16           1.1             1.1.1           B
                cksum           1.0.1           1.1.0           D, TS, I
------          -------         -----------     -----------     -------------------------------
csv             csv             0.5.1           0.6             TS, EF
------          -------         -----------     -----------     -------------------------------
des             des             0.8.2           1.0.0           ** API **, Import tclDES(jr), s.a.
------          -------         -----------     -----------     -------------------------------
dns             ip              1.0.0           1.1.0           EF, D
                dns             1.2.0           1.3.0           B, D, EF
------          -------         -----------     -----------     -------------------------------
doctools        doctools        1.1             1.2             EF, B, TS
                - idx           0.2             0.2.1           B, TS
                - toc           0.2             0.2.1           B, TS
------          -------         -----------     -----------     -------------------------------
fileutil        fileutil        1.7             1.8             D, B, TS, EF
------          -------         -----------     -----------     -------------------------------
ftp             ftp             2.4.1           2.4.2           B
------          -------         -----------     -----------     -------------------------------
grammar_fa      grammar::fa     0.1             0.1.1           TS
                - op            0.1             0.1.1           TS
                - dexec         0.1             0.1.1           TS
                - dacceptor     0.1             0.1.1           TS
------          -------         -----------     -----------     -------------------------------
html            html            1.2.3           1.3             B, TS, EF
------          -------         -----------     -----------     -------------------------------
htmlparse       htmlparse       1.1             1.1.1           B, TS
------          -------         -----------     -----------     -------------------------------
http            autoproxy       1.2.0           1.2.1           B
------          -------         -----------     -----------     -------------------------------
inifile         inifile         0.1             0.1.1           B, TS
------          -------         -----------     -----------     -------------------------------
javascript      javascript      1.0.1           1.0.2           B
------          -------         -----------     -----------     -------------------------------
jpeg            jpeg            0.1             0.2             ** API **
------          -------         -----------     -----------     -------------------------------
ldap            ldap            1.2             1.2.1           B
------          -------         -----------     -----------     -------------------------------
log             logger          0.5             0.6.1           B, TS, D, EF
------          -------         -----------     -----------     -------------------------------
math            math                1.2.2       1.2.3           B, TS
                - bignum            3.0         3.1             B, D, TS, EF
                - calculus          0.6         0.6.1           B, TS
                - complexnumbers    1.0         1.0.1           TS
                - constants         1.0         1.0.1           B, TS
                - fourier           1.0         1.0.1           TS
                - geometry          1.0.2       1.0.3           D
                - interpolate       1.0         1.0.1           B, TS
                - optimize          0.2         1.0             B, D, TS, EF
                - polynomials       1.0         1.0.1           TS
                - rationalfunctions 1.0         1.0.1           B
                - special           0.1         0.2             B, TS, EF
                - statistics        0.1.2       0.2             B, TS, EF
------          -------         -----------     -----------     -------------------------------
md4             md4             1.0.2           1.0.3           B, TS
------          -------         -----------     -----------     -------------------------------
md5             md5             1.4.3           1.4.4           B, TS, D
                md5             2.0.1           2.0.4           B, TS
------          -------         -----------     -----------     -------------------------------
mime            smtp            1.4             1.4.1           B
                mime            1.4             1.4.2           B
------          -------         -----------     -----------     -------------------------------
ncgi		ncgi		1.2.3		1.3		EF
------          -------         -----------     -----------     -------------------------------
ntp             time            1.1             1.2             B, TS, EF (ceptcl)
------          -------         -----------     -----------     -------------------------------
png             png             0.1             0.1.1           B
------          -------         -----------     -----------     -------------------------------
pop3            pop3            1.6.2           1.6.3           B/TS
------          -------         -----------     -----------     -------------------------------
pop3d           pop3d           1.0.3           1.1.0           B, TS, EF
------          -------         -----------     -----------     -------------------------------
profiler        profiler        0.2.2           0.2.3           B
------          -------         -----------     -----------     -------------------------------
rc4             rc4             1.0.0           1.0.1           D, B, TS
------          -------         -----------     -----------     -------------------------------
ripemd          ripemd128       1.0.0           1.0.3           TS, D, B
                ripemd160       1.0.0           1.0.3           TS, D, B
------          -------         -----------     -----------     -------------------------------
sha             sha1            1.0.3           1.1.0           TS, B, EF (cryptkit)
                sha1            --              2.0.2           TS, B, EF (cryptkit)
------          -------         -----------     -----------     -------------------------------
smtpd           smtpd           1.3.0           1.4.0           B
------          -------         -----------     -----------     -------------------------------
snit            snit            0.97            1.1             D, P, B, TS, I
------          -------         -----------     -----------     -------------------------------
struct          - tree          1.2.1           1.2.2           B
                - tree          2.0             2.1             D, EF (ext. api, critcl)
                - graph         2.0             2.0.1           B
                - queue         1.3             1.4             B, EF
                - prioqueue     1.3             1.3.1           B
                - list          1.4             1.5             D, TS, EF, B
                - matrix        2.0             2.0.1           B
                - stack         1.3             1.3.1           B
------          -------         -----------     -----------     -------------------------------
textutil        textutil        0.6.2           0.7             B, EF
------          -------         -----------     -----------     -------------------------------
tie             tie             1.0             1.0.1           D, EX, TS
                - std::file     1.0             1.0.1           B
------          -------         -----------     -----------     -------------------------------
treeql          treeql          1.2             1.3             B, D, TS, EF
------          -------         -----------     -----------     -------------------------------
uri             uri             1.1.4           1.1.5           B
------          -------         -----------     -----------     -------------------------------
uuid            uuid            1.0.0           1.0.1           B
------          -------         -----------     -----------     -------------------------------

Unchanged Modules/Packages
==========================

base64 (yencode), bee, calendar, crc (sum), dns (spf, resolv),
doctools (doctools::cvs, doctools::changelog), exif, ftp (ftp::geturl),
ftpd, ident, irc, log, math (math::fuzzy), md5crypt, multiplexer,
nntp, pop3d (pop3d::dbox, pop3d::udb), report, soundex, stooop
(stooop, switched), tar, textutil (textutil::expander),
tie (tie::std::array, tie::std::rarray, tie::std::dsource,
tie::std::log), uri (uri::urn), struct (struct, struct::graph v1,
struct::matrix v1, struct::pool, struct::record, struct::skiplist,
struct::set)
