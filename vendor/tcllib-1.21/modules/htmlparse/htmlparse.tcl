# htmlparse.tcl --
#
#	This file implements a simple HTML parsing library in Tcl.
#	It may take advantage of parsers coded in C in the future.
#
#	The functionality here is a subset of the
#
#		Simple HTML display library by Stephen Uhler (stephen.uhler@sun.com)
#		Copyright (c) 1995 by Sun Microsystems
#		Version 0.3 Fri Sep  1 10:47:17 PDT 1995
#
#	The main restriction is that all Tk-related code in the above
#	was left out of the code here. It is expected that this code
#	will go into a 'tklib' in the future.
#
# Copyright (c) 2001 by ActiveState Tool Corp.
# See the file license.terms.

package require Tcl       8.2
package require struct::stack
package require cmdline   1.1

namespace eval ::htmlparse {
    namespace export		\
	    parse		\
	    debugCallback	\
	    mapEscapes		\
	    2tree		\
	    removeVisualFluff	\
	    removeFormDefs

    # Table of escape characters. Maps from their names to the actual
    # character.  See http://htmlhelp.org/reference/html40/entities/

    variable namedEntities

    # I. Latin-1 Entities (HTML 4.01)
    array set namedEntities {
	nbsp \xa0 iexcl \xa1 cent \xa2 pound \xa3 curren \xa4
	yen \xa5 brvbar \xa6 sect \xa7 uml \xa8 copy \xa9
	ordf \xaa laquo \xab not \xac shy \xad reg \xae
	macr \xaf deg \xb0 plusmn \xb1 sup2 \xb2 sup3 \xb3
	acute \xb4 micro \xb5 para \xb6 middot \xb7 cedil \xb8
	sup1 \xb9 ordm \xba raquo \xbb frac14 \xbc frac12 \xbd
	frac34 \xbe iquest \xbf Agrave \xc0 Aacute \xc1 Acirc \xc2
	Atilde \xc3 Auml \xc4 Aring \xc5 AElig \xc6 Ccedil \xc7
	Egrave \xc8 Eacute \xc9 Ecirc \xca Euml \xcb Igrave \xcc
	Iacute \xcd Icirc \xce Iuml \xcf ETH \xd0 Ntilde \xd1
	Ograve \xd2 Oacute \xd3 Ocirc \xd4 Otilde \xd5 Ouml \xd6
	times \xd7 Oslash \xd8 Ugrave \xd9 Uacute \xda Ucirc \xdb
	Uuml \xdc Yacute \xdd THORN \xde szlig \xdf agrave \xe0
	aacute \xe1 acirc \xe2 atilde \xe3 auml \xe4 aring \xe5
	aelig \xe6 ccedil \xe7 egrave \xe8 eacute \xe9 ecirc \xea
	euml \xeb igrave \xec iacute \xed icirc \xee iuml \xef
	eth \xf0 ntilde \xf1 ograve \xf2 oacute \xf3 ocirc \xf4
	otilde \xf5 ouml \xf6 divide \xf7 oslash \xf8 ugrave \xf9
	uacute \xfa ucirc \xfb uuml \xfc yacute \xfd thorn \xfe
	yuml \xff
    }

    # II. Entities for Symbols and Greek Letters (HTML 4.01)
    array set namedEntities {
	fnof \u192 Alpha \u391 Beta \u392 Gamma \u393 Delta \u394
	Epsilon \u395 Zeta \u396 Eta \u397 Theta \u398 Iota \u399
	Kappa \u39A Lambda \u39B Mu \u39C Nu \u39D Xi \u39E
	Omicron \u39F Pi \u3A0 Rho \u3A1 Sigma \u3A3 Tau \u3A4
	Upsilon \u3A5 Phi \u3A6 Chi \u3A7 Psi \u3A8 Omega \u3A9
	alpha \u3B1 beta \u3B2 gamma \u3B3 delta \u3B4 epsilon \u3B5
	zeta \u3B6 eta \u3B7 theta \u3B8 iota \u3B9 kappa \u3BA
	lambda \u3BB mu \u3BC nu \u3BD xi \u3BE omicron \u3BF
	pi \u3C0 rho \u3C1 sigmaf \u3C2 sigma \u3C3 tau \u3C4
	upsilon \u3C5 phi \u3C6 chi \u3C7 psi \u3C8 omega \u3C9
	thetasym \u3D1 upsih \u3D2 piv \u3D6 bull \u2022
	hellip \u2026 prime \u2032 Prime \u2033 oline \u203E
	frasl \u2044 weierp \u2118 image \u2111 real \u211C
	trade \u2122 alefsym \u2135 larr \u2190 uarr \u2191
	rarr \u2192 darr \u2193 harr \u2194 crarr \u21B5
	lArr \u21D0 uArr \u21D1 rArr \u21D2 dArr \u21D3 hArr \u21D4
	forall \u2200 part \u2202 exist \u2203 empty \u2205
	nabla \u2207 isin \u2208 notin \u2209 ni \u220B prod \u220F
	sum \u2211 minus \u2212 lowast \u2217 radic \u221A
	prop \u221D infin \u221E ang \u2220 and \u2227 or \u2228
	cap \u2229 cup \u222A int \u222B there4 \u2234 sim \u223C
	cong \u2245 asymp \u2248 ne \u2260 equiv \u2261 le \u2264
	ge \u2265 sub \u2282 sup \u2283 nsub \u2284 sube \u2286
	supe \u2287 oplus \u2295 otimes \u2297 perp \u22A5
	sdot \u22C5 lceil \u2308 rceil \u2309 lfloor \u230A
	rfloor \u230B lang \u2329 rang \u232A loz \u25CA
	spades \u2660 clubs \u2663 hearts \u2665 diams \u2666
    }

    # III. Special Entities (HTML 4.01)
    array set namedEntities {
	quot \x22 amp \x26 lt \x3C gt \x3E OElig \u152 oelig \u153
	Scaron \u160 scaron \u161 Yuml \u178 circ \u2C6
	tilde \u2DC ensp \u2002 emsp \u2003 thinsp \u2009
	zwnj \u200C zwj \u200D lrm \u200E rlm \u200F ndash \u2013
	mdash \u2014 lsquo \u2018 rsquo \u2019 sbquo \u201A
	ldquo \u201C rdquo \u201D bdquo \u201E dagger \u2020
	Dagger \u2021 permil \u2030 lsaquo \u2039 rsaquo \u203A
	euro \u20AC
    }

    # IV. Special Entities (XHTML, XML)
    array set namedEntities {
	apos \u0027
    }

    # HTML5 section 8.5 Named character references (additions only)
    # http://www.w3.org/TR/2011/WD-html5-20110113/named-character-references.html

    array set namedEntities {
	Abreve \u102  abreve \u103  ac \u223e  acd \u223f 
	acE \u223e\u333  Acy \u410  acy \u430  af \u2061 
	Afr \ud835\udd04  afr \ud835\udd1e  aleph \u2135  Amacr \u100 
	amacr \u101  amalg \u2a3f  AMP \u26  andand \u2a55  And \u2a53 
	andd \u2a5c  andslope \u2a58  andv \u2a5a  ange \u29a4 
	angle \u2220  angmsdaa \u29a8  angmsdab \u29a9  angmsdac \u29aa 
	angmsdad \u29ab  angmsdae \u29ac  angmsdaf \u29ad 
	angmsdag \u29ae  angmsdah \u29af  angmsd \u2221  angrt \u221f 
	angrtvb \u22be  angrtvbd \u299d  angsph \u2222  angst \uc5 
	angzarr \u237c  Aogon \u104  aogon \u105  Aopf \ud835\udd38 
	aopf \ud835\udd52  apacir \u2a6f  ap \u2248  apE \u2a70 
	ape \u224a  apid \u224b  ApplyFunction \u2061  approx \u2248 
	approxeq \u224a  Ascr \ud835\udc9c  ascr \ud835\udcb6 
	Assign \u2254  ast \u2a  asympeq \u224d  awconint \u2233 
	awint \u2a11  backcong \u224c  backepsilon \u3f6 
	backprime \u2035  backsim \u223d  backsimeq \u22cd 
	Backslash \u2216  Barv \u2ae7  barvee \u22bd  barwed \u2305 
	Barwed \u2306  barwedge \u2305  bbrk \u23b5  bbrktbrk \u23b6 
	bcong \u224c  Bcy \u411  bcy \u431  becaus \u2235  because \u2235 
	Because \u2235  bemptyv \u29b0  bepsi \u3f6  bernou \u212c 
	Bernoullis \u212c  beth \u2136  between \u226c  Bfr \ud835\udd05 
	bfr \ud835\udd1f  bigcap \u22c2  bigcirc \u25ef  bigcup \u22c3 
	bigodot \u2a00  bigoplus \u2a01  bigotimes \u2a02 
	bigsqcup \u2a06  bigstar \u2605  bigtriangledown \u25bd 
	bigtriangleup \u25b3  biguplus \u2a04  bigvee \u22c1 
	bigwedge \u22c0  bkarow \u290d  blacklozenge \u29eb 
	blacksquare \u25aa  blacktriangle \u25b4 
	blacktriangledown \u25be  blacktriangleleft \u25c2 
	blacktriangleright \u25b8  blank \u2423  blk12 \u2592 
	blk14 \u2591  blk34 \u2593  block \u2588  bne \u3d\u20e5 
	bnequiv \u2261\u20e5  bNot \u2aed  bnot \u2310  Bopf \ud835\udd39 
	bopf \ud835\udd53  bot \u22a5  bottom \u22a5  bowtie \u22c8 
	boxbox \u29c9  boxdl \u2510  boxdL \u2555  boxDl \u2556 
	boxDL \u2557  boxdr \u250c  boxdR \u2552  boxDr \u2553 
	boxDR \u2554  boxh \u2500  boxH \u2550  boxhd \u252c 
	boxHd \u2564  boxhD \u2565  boxHD \u2566  boxhu \u2534 
	boxHu \u2567  boxhU \u2568  boxHU \u2569  boxminus \u229f 
	boxplus \u229e  boxtimes \u22a0  boxul \u2518  boxuL \u255b 
	boxUl \u255c  boxUL \u255d  boxur \u2514  boxuR \u2558 
	boxUr \u2559  boxUR \u255a  boxv \u2502  boxV \u2551 
	boxvh \u253c  boxvH \u256a  boxVh \u256b  boxVH \u256c 
	boxvl \u2524  boxvL \u2561  boxVl \u2562  boxVL \u2563 
	boxvr \u251c  boxvR \u255e  boxVr \u255f  boxVR \u2560 
	bprime \u2035  breve \u2d8  Breve \u2d8  bscr \ud835\udcb7 
	Bscr \u212c  bsemi \u204f  bsim \u223d  bsime \u22cd 
	bsolb \u29c5  bsol \u5c  bsolhsub \u27c8  bullet \u2022 
	bump \u224e  bumpE \u2aae  bumpe \u224f  Bumpeq \u224e 
	bumpeq \u224f  Cacute \u106  cacute \u107  capand \u2a44 
	capbrcup \u2a49  capcap \u2a4b  Cap \u22d2  capcup \u2a47 
	capdot \u2a40  CapitalDifferentialD \u2145  caps \u2229\ufe00 
	caret \u2041  caron \u2c7  Cayleys \u212d  ccaps \u2a4d 
	Ccaron \u10c  ccaron \u10d  Ccirc \u108  ccirc \u109 
	Cconint \u2230  ccups \u2a4c  ccupssm \u2a50  Cdot \u10a 
	cdot \u10b  Cedilla \ub8  cemptyv \u29b2  centerdot \ub7 
	CenterDot \ub7  cfr \ud835\udd20  Cfr \u212d  CHcy \u427 
	chcy \u447  check \u2713  checkmark \u2713  circeq \u2257 
	circlearrowleft \u21ba  circlearrowright \u21bb 
	circledast \u229b  circledcirc \u229a  circleddash \u229d 
	CircleDot \u2299  circledR \uae  circledS \u24c8 
	CircleMinus \u2296  CirclePlus \u2295  CircleTimes \u2297 
	cir \u25cb  cirE \u29c3  cire \u2257  cirfnint \u2a10 
	cirmid \u2aef  cirscir \u29c2  ClockwiseContourIntegral \u2232 
	CloseCurlyDoubleQuote \u201d  CloseCurlyQuote \u2019 
	clubsuit \u2663  colon \u3a  Colon \u2237  Colone \u2a74 
	colone \u2254  coloneq \u2254  comma \u2c  commat \u40 
	comp \u2201  compfn \u2218  complement \u2201  complexes \u2102 
	congdot \u2a6d  Congruent \u2261  conint \u222e  Conint \u222f 
	ContourIntegral \u222e  copf \ud835\udd54  Copf \u2102 
	coprod \u2210  Coproduct \u2210  COPY \ua9  copysr \u2117 
	CounterClockwiseContourIntegral \u2233  cross \u2717 
	Cross \u2a2f  Cscr \ud835\udc9e  cscr \ud835\udcb8  csub \u2acf 
	csube \u2ad1  csup \u2ad0  csupe \u2ad2  ctdot \u22ef 
	cudarrl \u2938  cudarrr \u2935  cuepr \u22de  cuesc \u22df 
	cularr \u21b6  cularrp \u293d  cupbrcap \u2a48  cupcap \u2a46 
	CupCap \u224d  Cup \u22d3  cupcup \u2a4a  cupdot \u228d 
	cupor \u2a45  cups \u222a\ufe00  curarr \u21b7  curarrm \u293c 
	curlyeqprec \u22de  curlyeqsucc \u22df  curlyvee \u22ce 
	curlywedge \u22cf  curvearrowleft \u21b6  curvearrowright \u21b7 
	cuvee \u22ce  cuwed \u22cf  cwconint \u2232  cwint \u2231 
	cylcty \u232d  daleth \u2138  Darr \u21a1  dash \u2010 
	Dashv \u2ae4  dashv \u22a3  dbkarow \u290f  dblac \u2dd 
	Dcaron \u10e  dcaron \u10f  Dcy \u414  dcy \u434  ddagger \u2021 
	ddarr \u21ca  DD \u2145  dd \u2146  DDotrahd \u2911 
	ddotseq \u2a77  Del \u2207  demptyv \u29b1  dfisht \u297f 
	Dfr \ud835\udd07  dfr \ud835\udd21  dHar \u2965  dharl \u21c3 
	dharr \u21c2  DiacriticalAcute \ub4  DiacriticalDot \u2d9 
	DiacriticalDoubleAcute \u2dd  DiacriticalGrave \u60 
	DiacriticalTilde \u2dc  diam \u22c4  diamond \u22c4 
	Diamond \u22c4  diamondsuit \u2666  die \ua8 
	DifferentialD \u2146  digamma \u3dd  disin \u22f2  div \uf7 
	divideontimes \u22c7  divonx \u22c7  DJcy \u402  djcy \u452 
	dlcorn \u231e  dlcrop \u230d  dollar \u24  Dopf \ud835\udd3b 
	dopf \ud835\udd55  Dot \ua8  dot \u2d9  DotDot \u20dc 
	doteq \u2250  doteqdot \u2251  DotEqual \u2250  dotminus \u2238 
	dotplus \u2214  dotsquare \u22a1  doublebarwedge \u2306 
	DoubleContourIntegral \u222f  DoubleDot \ua8 
	DoubleDownArrow \u21d3  DoubleLeftArrow \u21d0 
	DoubleLeftRightArrow \u21d4  DoubleLeftTee \u2ae4 
	DoubleLongLeftArrow \u27f8  DoubleLongLeftRightArrow \u27fa 
	DoubleLongRightArrow \u27f9  DoubleRightArrow \u21d2 
	DoubleRightTee \u22a8  DoubleUpArrow \u21d1 
	DoubleUpDownArrow \u21d5  DoubleVerticalBar \u2225 
	DownArrowBar \u2913  downarrow \u2193  DownArrow \u2193 
	Downarrow \u21d3  DownArrowUpArrow \u21f5  DownBreve \u311 
	downdownarrows \u21ca  downharpoonleft \u21c3 
	downharpoonright \u21c2  DownLeftRightVector \u2950 
	DownLeftTeeVector \u295e  DownLeftVectorBar \u2956 
	DownLeftVector \u21bd  DownRightTeeVector \u295f 
	DownRightVectorBar \u2957  DownRightVector \u21c1 
	DownTeeArrow \u21a7  DownTee \u22a4  drbkarow \u2910 
	drcorn \u231f  drcrop \u230c  Dscr \ud835\udc9f 
	dscr \ud835\udcb9  DScy \u405  dscy \u455  dsol \u29f6 
	Dstrok \u110  dstrok \u111  dtdot \u22f1  dtri \u25bf 
	dtrif \u25be  duarr \u21f5  duhar \u296f  dwangle \u29a6 
	DZcy \u40f  dzcy \u45f  dzigrarr \u27ff  easter \u2a6e 
	Ecaron \u11a  ecaron \u11b  ecir \u2256  ecolon \u2255  Ecy \u42d 
	ecy \u44d  eDDot \u2a77  Edot \u116  edot \u117  eDot \u2251 
	ee \u2147  efDot \u2252  Efr \ud835\udd08  efr \ud835\udd22 
	eg \u2a9a  egs \u2a96  egsdot \u2a98  el \u2a99  Element \u2208 
	elinters \u23e7  ell \u2113  els \u2a95  elsdot \u2a97 
	Emacr \u112  emacr \u113  emptyset \u2205 
	EmptySmallSquare \u25fb  emptyv \u2205 
	EmptyVerySmallSquare \u25ab  emsp13 \u2004  emsp14 \u2005 
	ENG \u14a  eng \u14b  Eogon \u118  eogon \u119  Eopf \ud835\udd3c 
	eopf \ud835\udd56  epar \u22d5  eparsl \u29e3  eplus \u2a71 
	epsi \u3b5  epsiv \u3f5  eqcirc \u2256  eqcolon \u2255 
	eqsim \u2242  eqslantgtr \u2a96  eqslantless \u2a95  Equal \u2a75 
	equals \u3d  EqualTilde \u2242  equest \u225f  Equilibrium \u21cc 
	equivDD \u2a78  eqvparsl \u29e5  erarr \u2971  erDot \u2253 
	escr \u212f  Escr \u2130  esdot \u2250  Esim \u2a73  esim \u2242 
	excl \u21  Exists \u2203  expectation \u2130  exponentiale \u2147 
	ExponentialE \u2147  fallingdotseq \u2252  Fcy \u424  fcy \u444 
	female \u2640  ffilig \ufb03  fflig \ufb00  ffllig \ufb04 
	Ffr \ud835\udd09  ffr \ud835\udd23  filig \ufb01 
	FilledSmallSquare \u25fc  FilledVerySmallSquare \u25aa 
	fjlig \u66\u6a  flat \u266d  fllig \ufb02  fltns \u25b1 
	Fopf \ud835\udd3d  fopf \ud835\udd57  ForAll \u2200  fork \u22d4 
	forkv \u2ad9  Fouriertrf \u2131  fpartint \u2a0d  frac13 \u2153 
	frac15 \u2155  frac16 \u2159  frac18 \u215b  frac23 \u2154 
	frac25 \u2156  frac35 \u2157  frac38 \u215c  frac45 \u2158 
	frac56 \u215a  frac58 \u215d  frac78 \u215e  frown \u2322 
	fscr \ud835\udcbb  Fscr \u2131  gacute \u1f5  Gammad \u3dc 
	gammad \u3dd  gap \u2a86  Gbreve \u11e  gbreve \u11f 
	Gcedil \u122  Gcirc \u11c  gcirc \u11d  Gcy \u413  gcy \u433 
	Gdot \u120  gdot \u121  gE \u2267  gEl \u2a8c  gel \u22db 
	geq \u2265  geqq \u2267  geqslant \u2a7e  gescc \u2aa9 
	ges \u2a7e  gesdot \u2a80  gesdoto \u2a82  gesdotol \u2a84 
	gesl \u22db\ufe00  gesles \u2a94  Gfr \ud835\udd0a 
	gfr \ud835\udd24  gg \u226b  Gg \u22d9  ggg \u22d9  gimel \u2137 
	GJcy \u403  gjcy \u453  gla \u2aa5  gl \u2277  glE \u2a92 
	glj \u2aa4  gnap \u2a8a  gnapprox \u2a8a  gne \u2a88  gnE \u2269 
	gneq \u2a88  gneqq \u2269  gnsim \u22e7  Gopf \ud835\udd3e 
	gopf \ud835\udd58  grave \u60  GreaterEqual \u2265 
	GreaterEqualLess \u22db  GreaterFullEqual \u2267 
	GreaterGreater \u2aa2  GreaterLess \u2277 
	GreaterSlantEqual \u2a7e  GreaterTilde \u2273  Gscr \ud835\udca2 
	gscr \u210a  gsim \u2273  gsime \u2a8e  gsiml \u2a90  gtcc \u2aa7 
	gtcir \u2a7a  GT \u3e  Gt \u226b  gtdot \u22d7  gtlPar \u2995 
	gtquest \u2a7c  gtrapprox \u2a86  gtrarr \u2978  gtrdot \u22d7 
	gtreqless \u22db  gtreqqless \u2a8c  gtrless \u2277 
	gtrsim \u2273  gvertneqq \u2269\ufe00  gvnE \u2269\ufe00 
	Hacek \u2c7  hairsp \u200a  half \ubd  hamilt \u210b 
	HARDcy \u42a  hardcy \u44a  harrcir \u2948  harrw \u21ad 
	Hat \u5e  hbar \u210f  Hcirc \u124  hcirc \u125  heartsuit \u2665 
	hercon \u22b9  hfr \ud835\udd25  Hfr \u210c  HilbertSpace \u210b 
	hksearow \u2925  hkswarow \u2926  hoarr \u21ff  homtht \u223b 
	hookleftarrow \u21a9  hookrightarrow \u21aa  hopf \ud835\udd59 
	Hopf \u210d  horbar \u2015  HorizontalLine \u2500 
	hscr \ud835\udcbd  Hscr \u210b  hslash \u210f  Hstrok \u126 
	hstrok \u127  HumpDownHump \u224e  HumpEqual \u224f 
	hybull \u2043  hyphen \u2010  ic \u2063  Icy \u418  icy \u438 
	Idot \u130  IEcy \u415  iecy \u435  iff \u21d4  ifr \ud835\udd26 
	Ifr \u2111  ii \u2148  iiiint \u2a0c  iiint \u222d  iinfin \u29dc 
	iiota \u2129  IJlig \u132  ijlig \u133  Imacr \u12a  imacr \u12b 
	ImaginaryI \u2148  imagline \u2110  imagpart \u2111  imath \u131 
	Im \u2111  imof \u22b7  imped \u1b5  Implies \u21d2 
	incare \u2105  in \u2208  infintie \u29dd  inodot \u131 
	intcal \u22ba  Int \u222c  integers \u2124  Integral \u222b 
	intercal \u22ba  Intersection \u22c2  intlarhk \u2a17 
	intprod \u2a3c  InvisibleComma \u2063  InvisibleTimes \u2062 
	IOcy \u401  iocy \u451  Iogon \u12e  iogon \u12f 
	Iopf \ud835\udd40  iopf \ud835\udd5a  iprod \u2a3c 
	iscr \ud835\udcbe  Iscr \u2110  isindot \u22f5  isinE \u22f9 
	isins \u22f4  isinsv \u22f3  isinv \u2208  it \u2062 
	Itilde \u128  itilde \u129  Iukcy \u406  iukcy \u456  Jcirc \u134 
	jcirc \u135  Jcy \u419  jcy \u439  Jfr \ud835\udd0d 
	jfr \ud835\udd27  jmath \u237  Jopf \ud835\udd41 
	jopf \ud835\udd5b  Jscr \ud835\udca5  jscr \ud835\udcbf 
	Jsercy \u408  jsercy \u458  Jukcy \u404  jukcy \u454 
	kappav \u3f0  Kcedil \u136  kcedil \u137  Kcy \u41a  kcy \u43a 
	Kfr \ud835\udd0e  kfr \ud835\udd28  kgreen \u138  KHcy \u425 
	khcy \u445  KJcy \u40c  kjcy \u45c  Kopf \ud835\udd42 
	kopf \ud835\udd5c  Kscr \ud835\udca6  kscr \ud835\udcc0 
	lAarr \u21da  Lacute \u139  lacute \u13a  laemptyv \u29b4 
	lagran \u2112  Lang \u27ea  langd \u2991  langle \u27e8 
	lap \u2a85  Laplacetrf \u2112  larrb \u21e4  larrbfs \u291f 
	Larr \u219e  larrfs \u291d  larrhk \u21a9  larrlp \u21ab 
	larrpl \u2939  larrsim \u2973  larrtl \u21a2  latail \u2919 
	lAtail \u291b  lat \u2aab  late \u2aad  lates \u2aad\ufe00 
	lbarr \u290c  lBarr \u290e  lbbrk \u2772  lbrace \u7b 
	lbrack \u5b  lbrke \u298b  lbrksld \u298f  lbrkslu \u298d 
	Lcaron \u13d  lcaron \u13e  Lcedil \u13b  lcedil \u13c  lcub \u7b 
	Lcy \u41b  lcy \u43b  ldca \u2936  ldquor \u201e  ldrdhar \u2967 
	ldrushar \u294b  ldsh \u21b2  lE \u2266  LeftAngleBracket \u27e8 
	LeftArrowBar \u21e4  leftarrow \u2190  LeftArrow \u2190 
	Leftarrow \u21d0  LeftArrowRightArrow \u21c6 
	leftarrowtail \u21a2  LeftCeiling \u2308 
	LeftDoubleBracket \u27e6  LeftDownTeeVector \u2961 
	LeftDownVectorBar \u2959  LeftDownVector \u21c3  LeftFloor \u230a 
	leftharpoondown \u21bd  leftharpoonup \u21bc 
	leftleftarrows \u21c7  leftrightarrow \u2194 
	LeftRightArrow \u2194  Leftrightarrow \u21d4 
	leftrightarrows \u21c6  leftrightharpoons \u21cb 
	leftrightsquigarrow \u21ad  LeftRightVector \u294e 
	LeftTeeArrow \u21a4  LeftTee \u22a3  LeftTeeVector \u295a 
	leftthreetimes \u22cb  LeftTriangleBar \u29cf 
	LeftTriangle \u22b2  LeftTriangleEqual \u22b4 
	LeftUpDownVector \u2951  LeftUpTeeVector \u2960 
	LeftUpVectorBar \u2958  LeftUpVector \u21bf  LeftVectorBar \u2952 
	LeftVector \u21bc  lEg \u2a8b  leg \u22da  leq \u2264 
	leqq \u2266  leqslant \u2a7d  lescc \u2aa8  les \u2a7d 
	lesdot \u2a7f  lesdoto \u2a81  lesdotor \u2a83  lesg \u22da\ufe00 
	lesges \u2a93  lessapprox \u2a85  lessdot \u22d6 
	lesseqgtr \u22da  lesseqqgtr \u2a8b  LessEqualGreater \u22da 
	LessFullEqual \u2266  LessGreater \u2276  lessgtr \u2276 
	LessLess \u2aa1  lesssim \u2272  LessSlantEqual \u2a7d 
	LessTilde \u2272  lfisht \u297c  Lfr \ud835\udd0f 
	lfr \ud835\udd29  lg \u2276  lgE \u2a91  lHar \u2962 
	lhard \u21bd  lharu \u21bc  lharul \u296a  lhblk \u2584 
	LJcy \u409  ljcy \u459  llarr \u21c7  ll \u226a  Ll \u22d8 
	llcorner \u231e  Lleftarrow \u21da  llhard \u296b  lltri \u25fa 
	Lmidot \u13f  lmidot \u140  lmoustache \u23b0  lmoust \u23b0 
	lnap \u2a89  lnapprox \u2a89  lne \u2a87  lnE \u2268  lneq \u2a87 
	lneqq \u2268  lnsim \u22e6  loang \u27ec  loarr \u21fd 
	lobrk \u27e6  longleftarrow \u27f5  LongLeftArrow \u27f5 
	Longleftarrow \u27f8  longleftrightarrow \u27f7 
	LongLeftRightArrow \u27f7  Longleftrightarrow \u27fa 
	longmapsto \u27fc  longrightarrow \u27f6  LongRightArrow \u27f6 
	Longrightarrow \u27f9  looparrowleft \u21ab 
	looparrowright \u21ac  lopar \u2985  Lopf \ud835\udd43 
	lopf \ud835\udd5d  loplus \u2a2d  lotimes \u2a34  lowbar \u5f 
	LowerLeftArrow \u2199  LowerRightArrow \u2198  lozenge \u25ca 
	lozf \u29eb  lpar \u28  lparlt \u2993  lrarr \u21c6 
	lrcorner \u231f  lrhar \u21cb  lrhard \u296d  lrtri \u22bf 
	lscr \ud835\udcc1  Lscr \u2112  lsh \u21b0  Lsh \u21b0 
	lsim \u2272  lsime \u2a8d  lsimg \u2a8f  lsqb \u5b  lsquor \u201a 
	Lstrok \u141  lstrok \u142  ltcc \u2aa6  ltcir \u2a79  LT \u3c 
	Lt \u226a  ltdot \u22d6  lthree \u22cb  ltimes \u22c9 
	ltlarr \u2976  ltquest \u2a7b  ltri \u25c3  ltrie \u22b4 
	ltrif \u25c2  ltrPar \u2996  lurdshar \u294a  luruhar \u2966 
	lvertneqq \u2268\ufe00  lvnE \u2268\ufe00  male \u2642 
	malt \u2720  maltese \u2720  Map \u2905  map \u21a6 
	mapsto \u21a6  mapstodown \u21a7  mapstoleft \u21a4 
	mapstoup \u21a5  marker \u25ae  mcomma \u2a29  Mcy \u41c 
	mcy \u43c  mDDot \u223a  measuredangle \u2221  MediumSpace \u205f 
	Mellintrf \u2133  Mfr \ud835\udd10  mfr \ud835\udd2a  mho \u2127 
	midast \u2a  midcir \u2af0  mid \u2223  minusb \u229f 
	minusd \u2238  minusdu \u2a2a  MinusPlus \u2213  mlcp \u2adb 
	mldr \u2026  mnplus \u2213  models \u22a7  Mopf \ud835\udd44 
	mopf \ud835\udd5e  mp \u2213  mscr \ud835\udcc2  Mscr \u2133 
	mstpos \u223e  multimap \u22b8  mumap \u22b8  Nacute \u143 
	nacute \u144  nang \u2220\u20d2  nap \u2249  napE \u2a70\u338 
	napid \u224b\u338  napos \u149  napprox \u2249  natural \u266e 
	naturals \u2115  natur \u266e  nbump \u224e\u338 
	nbumpe \u224f\u338  ncap \u2a43  Ncaron \u147  ncaron \u148 
	Ncedil \u145  ncedil \u146  ncong \u2247  ncongdot \u2a6d\u338 
	ncup \u2a42  Ncy \u41d  ncy \u43d  nearhk \u2924  nearr \u2197 
	neArr \u21d7  nearrow \u2197  nedot \u2250\u338 
	NegativeMediumSpace \u200b  NegativeThickSpace \u200b 
	NegativeThinSpace \u200b  NegativeVeryThinSpace \u200b 
	nequiv \u2262  nesear \u2928  nesim \u2242\u338 
	NestedGreaterGreater \u226b  NestedLessLess \u226a  NewLine \ua 
	nexist \u2204  nexists \u2204  Nfr \ud835\udd11  nfr \ud835\udd2b 
	ngE \u2267\u338  nge \u2271  ngeq \u2271  ngeqq \u2267\u338 
	ngeqslant \u2a7e\u338  nges \u2a7e\u338  nGg \u22d9\u338 
	ngsim \u2275  nGt \u226b\u20d2  ngt \u226f  ngtr \u226f 
	nGtv \u226b\u338  nharr \u21ae  nhArr \u21ce  nhpar \u2af2 
	nis \u22fc  nisd \u22fa  niv \u220b  NJcy \u40a  njcy \u45a 
	nlarr \u219a  nlArr \u21cd  nldr \u2025  nlE \u2266\u338 
	nle \u2270  nleftarrow \u219a  nLeftarrow \u21cd 
	nleftrightarrow \u21ae  nLeftrightarrow \u21ce  nleq \u2270 
	nleqq \u2266\u338  nleqslant \u2a7d\u338  nles \u2a7d\u338 
	nless \u226e  nLl \u22d8\u338  nlsim \u2274  nLt \u226a\u20d2 
	nlt \u226e  nltri \u22ea  nltrie \u22ec  nLtv \u226a\u338 
	nmid \u2224  NoBreak \u2060  NonBreakingSpace \ua0 
	nopf \ud835\udd5f  Nopf \u2115  Not \u2aec  NotCongruent \u2262 
	NotCupCap \u226d  NotDoubleVerticalBar \u2226  NotElement \u2209 
	NotEqual \u2260  NotEqualTilde \u2242\u338  NotExists \u2204 
	NotGreater \u226f  NotGreaterEqual \u2271 
	NotGreaterFullEqual \u2267\u338  NotGreaterGreater \u226b\u338 
	NotGreaterLess \u2279  NotGreaterSlantEqual \u2a7e\u338 
	NotGreaterTilde \u2275  NotHumpDownHump \u224e\u338 
	NotHumpEqual \u224f\u338  notindot \u22f5\u338 
	notinE \u22f9\u338  notinva \u2209  notinvb \u22f7 
	notinvc \u22f6  NotLeftTriangleBar \u29cf\u338 
	NotLeftTriangle \u22ea  NotLeftTriangleEqual \u22ec 
	NotLess \u226e  NotLessEqual \u2270  NotLessGreater \u2278 
	NotLessLess \u226a\u338  NotLessSlantEqual \u2a7d\u338 
	NotLessTilde \u2274  NotNestedGreaterGreater \u2aa2\u338 
	NotNestedLessLess \u2aa1\u338  notni \u220c  notniva \u220c 
	notnivb \u22fe  notnivc \u22fd  NotPrecedes \u2280 
	NotPrecedesEqual \u2aaf\u338  NotPrecedesSlantEqual \u22e0 
	NotReverseElement \u220c  NotRightTriangleBar \u29d0\u338 
	NotRightTriangle \u22eb  NotRightTriangleEqual \u22ed 
	NotSquareSubset \u228f\u338  NotSquareSubsetEqual \u22e2 
	NotSquareSuperset \u2290\u338  NotSquareSupersetEqual \u22e3 
	NotSubset \u2282\u20d2  NotSubsetEqual \u2288  NotSucceeds \u2281 
	NotSucceedsEqual \u2ab0\u338  NotSucceedsSlantEqual \u22e1 
	NotSucceedsTilde \u227f\u338  NotSuperset \u2283\u20d2 
	NotSupersetEqual \u2289  NotTilde \u2241  NotTildeEqual \u2244 
	NotTildeFullEqual \u2247  NotTildeTilde \u2249 
	NotVerticalBar \u2224  nparallel \u2226  npar \u2226 
	nparsl \u2afd\u20e5  npart \u2202\u338  npolint \u2a14 
	npr \u2280  nprcue \u22e0  nprec \u2280  npreceq \u2aaf\u338 
	npre \u2aaf\u338  nrarrc \u2933\u338  nrarr \u219b  nrArr \u21cf 
	nrarrw \u219d\u338  nrightarrow \u219b  nRightarrow \u21cf 
	nrtri \u22eb  nrtrie \u22ed  nsc \u2281  nsccue \u22e1 
	nsce \u2ab0\u338  Nscr \ud835\udca9  nscr \ud835\udcc3 
	nshortmid \u2224  nshortparallel \u2226  nsim \u2241 
	nsime \u2244  nsimeq \u2244  nsmid \u2224  nspar \u2226 
	nsqsube \u22e2  nsqsupe \u22e3  nsubE \u2ac5\u338  nsube \u2288 
	nsubset \u2282\u20d2  nsubseteq \u2288  nsubseteqq \u2ac5\u338 
	nsucc \u2281  nsucceq \u2ab0\u338  nsup \u2285  nsupE \u2ac6\u338 
	nsupe \u2289  nsupset \u2283\u20d2  nsupseteq \u2289 
	nsupseteqq \u2ac6\u338  ntgl \u2279  ntlg \u2278 
	ntriangleleft \u22ea  ntrianglelefteq \u22ec 
	ntriangleright \u22eb  ntrianglerighteq \u22ed  num \u23 
	numero \u2116  numsp \u2007  nvap \u224d\u20d2  nvdash \u22ac 
	nvDash \u22ad  nVdash \u22ae  nVDash \u22af  nvge \u2265\u20d2 
	nvgt \u3e\u20d2  nvHarr \u2904  nvinfin \u29de  nvlArr \u2902 
	nvle \u2264\u20d2  nvlt \u3c\u20d2  nvltrie \u22b4\u20d2 
	nvrArr \u2903  nvrtrie \u22b5\u20d2  nvsim \u223c\u20d2 
	nwarhk \u2923  nwarr \u2196  nwArr \u21d6  nwarrow \u2196 
	nwnear \u2927  oast \u229b  ocir \u229a  Ocy \u41e  ocy \u43e 
	odash \u229d  Odblac \u150  odblac \u151  odiv \u2a38 
	odot \u2299  odsold \u29bc  ofcir \u29bf  Ofr \ud835\udd12 
	ofr \ud835\udd2c  ogon \u2db  ogt \u29c1  ohbar \u29b5  ohm \u3a9 
	oint \u222e  olarr \u21ba  olcir \u29be  olcross \u29bb 
	olt \u29c0  Omacr \u14c  omacr \u14d  omid \u29b6  ominus \u2296 
	Oopf \ud835\udd46  oopf \ud835\udd60  opar \u29b7 
	OpenCurlyDoubleQuote \u201c  OpenCurlyQuote \u2018  operp \u29b9 
	orarr \u21bb  Or \u2a54  ord \u2a5d  order \u2134  orderof \u2134 
	origof \u22b6  oror \u2a56  orslope \u2a57  orv \u2a5b  oS \u24c8 
	Oscr \ud835\udcaa  oscr \u2134  osol \u2298  otimesas \u2a36 
	Otimes \u2a37  ovbar \u233d  OverBar \u203e  OverBrace \u23de 
	OverBracket \u23b4  OverParenthesis \u23dc  parallel \u2225 
	par \u2225  parsim \u2af3  parsl \u2afd  PartialD \u2202 
	Pcy \u41f  pcy \u43f  percnt \u25  period \u2e  pertenk \u2031 
	Pfr \ud835\udd13  pfr \ud835\udd2d  phiv \u3d5  phmmat \u2133 
	phone \u260e  pitchfork \u22d4  planck \u210f  planckh \u210e 
	plankv \u210f  plusacir \u2a23  plusb \u229e  pluscir \u2a22 
	plus \u2b  plusdo \u2214  plusdu \u2a25  pluse \u2a72 
	PlusMinus \ub1  plussim \u2a26  plustwo \u2a27  pm \ub1 
	Poincareplane \u210c  pointint \u2a15  popf \ud835\udd61 
	Popf \u2119  prap \u2ab7  Pr \u2abb  pr \u227a  prcue \u227c 
	precapprox \u2ab7  prec \u227a  preccurlyeq \u227c 
	Precedes \u227a  PrecedesEqual \u2aaf  PrecedesSlantEqual \u227c 
	PrecedesTilde \u227e  preceq \u2aaf  precnapprox \u2ab9 
	precneqq \u2ab5  precnsim \u22e8  pre \u2aaf  prE \u2ab3 
	precsim \u227e  primes \u2119  prnap \u2ab9  prnE \u2ab5 
	prnsim \u22e8  Product \u220f  profalar \u232e  profline \u2312 
	profsurf \u2313  Proportional \u221d  Proportion \u2237 
	propto \u221d  prsim \u227e  prurel \u22b0  Pscr \ud835\udcab 
	pscr \ud835\udcc5  puncsp \u2008  Qfr \ud835\udd14 
	qfr \ud835\udd2e  qint \u2a0c  qopf \ud835\udd62  Qopf \u211a 
	qprime \u2057  Qscr \ud835\udcac  qscr \ud835\udcc6 
	quaternions \u210d  quatint \u2a16  quest \u3f  questeq \u225f 
	QUOT \u22  rAarr \u21db  race \u223d\u331  Racute \u154 
	racute \u155  raemptyv \u29b3  Rang \u27eb  rangd \u2992 
	range \u29a5  rangle \u27e9  rarrap \u2975  rarrb \u21e5 
	rarrbfs \u2920  rarrc \u2933  Rarr \u21a0  rarrfs \u291e 
	rarrhk \u21aa  rarrlp \u21ac  rarrpl \u2945  rarrsim \u2974 
	Rarrtl \u2916  rarrtl \u21a3  rarrw \u219d  ratail \u291a 
	rAtail \u291c  ratio \u2236  rationals \u211a  rbarr \u290d 
	rBarr \u290f  RBarr \u2910  rbbrk \u2773  rbrace \u7d 
	rbrack \u5d  rbrke \u298c  rbrksld \u298e  rbrkslu \u2990 
	Rcaron \u158  rcaron \u159  Rcedil \u156  rcedil \u157  rcub \u7d 
	Rcy \u420  rcy \u440  rdca \u2937  rdldhar \u2969  rdquor \u201d 
	rdsh \u21b3  realine \u211b  realpart \u211c  reals \u211d 
	Re \u211c  rect \u25ad  REG \uae  ReverseElement \u220b 
	ReverseEquilibrium \u21cb  ReverseUpEquilibrium \u296f 
	rfisht \u297d  rfr \ud835\udd2f  Rfr \u211c  rHar \u2964 
	rhard \u21c1  rharu \u21c0  rharul \u296c  rhov \u3f1 
	RightAngleBracket \u27e9  RightArrowBar \u21e5  rightarrow \u2192 
	RightArrow \u2192  Rightarrow \u21d2  RightArrowLeftArrow \u21c4 
	rightarrowtail \u21a3  RightCeiling \u2309 
	RightDoubleBracket \u27e7  RightDownTeeVector \u295d 
	RightDownVectorBar \u2955  RightDownVector \u21c2 
	RightFloor \u230b  rightharpoondown \u21c1  rightharpoonup \u21c0 
	rightleftarrows \u21c4  rightleftharpoons \u21cc 
	rightrightarrows \u21c9  rightsquigarrow \u219d 
	RightTeeArrow \u21a6  RightTee \u22a2  RightTeeVector \u295b 
	rightthreetimes \u22cc  RightTriangleBar \u29d0 
	RightTriangle \u22b3  RightTriangleEqual \u22b5 
	RightUpDownVector \u294f  RightUpTeeVector \u295c 
	RightUpVectorBar \u2954  RightUpVector \u21be 
	RightVectorBar \u2953  RightVector \u21c0  ring \u2da 
	risingdotseq \u2253  rlarr \u21c4  rlhar \u21cc 
	rmoustache \u23b1  rmoust \u23b1  rnmid \u2aee  roang \u27ed 
	roarr \u21fe  robrk \u27e7  ropar \u2986  ropf \ud835\udd63 
	Ropf \u211d  roplus \u2a2e  rotimes \u2a35  RoundImplies \u2970 
	rpar \u29  rpargt \u2994  rppolint \u2a12  rrarr \u21c9 
	Rrightarrow \u21db  rscr \ud835\udcc7  Rscr \u211b  rsh \u21b1 
	Rsh \u21b1  rsqb \u5d  rsquor \u2019  rthree \u22cc 
	rtimes \u22ca  rtri \u25b9  rtrie \u22b5  rtrif \u25b8 
	rtriltri \u29ce  RuleDelayed \u29f4  ruluhar \u2968  rx \u211e 
	Sacute \u15a  sacute \u15b  scap \u2ab8  Sc \u2abc  sc \u227b 
	sccue \u227d  sce \u2ab0  scE \u2ab4  Scedil \u15e  scedil \u15f 
	Scirc \u15c  scirc \u15d  scnap \u2aba  scnE \u2ab6 
	scnsim \u22e9  scpolint \u2a13  scsim \u227f  Scy \u421 
	scy \u441  sdotb \u22a1  sdote \u2a66  searhk \u2925 
	searr \u2198  seArr \u21d8  searrow \u2198  semi \u3b 
	seswar \u2929  setminus \u2216  setmn \u2216  sext \u2736 
	Sfr \ud835\udd16  sfr \ud835\udd30  sfrown \u2322  sharp \u266f 
	SHCHcy \u429  shchcy \u449  SHcy \u428  shcy \u448 
	ShortDownArrow \u2193  ShortLeftArrow \u2190  shortmid \u2223 
	shortparallel \u2225  ShortRightArrow \u2192  ShortUpArrow \u2191 
	sigmav \u3c2  simdot \u2a6a  sime \u2243  simeq \u2243 
	simg \u2a9e  simgE \u2aa0  siml \u2a9d  simlE \u2a9f 
	simne \u2246  simplus \u2a24  simrarr \u2972  slarr \u2190 
	SmallCircle \u2218  smallsetminus \u2216  smashp \u2a33 
	smeparsl \u29e4  smid \u2223  smile \u2323  smt \u2aaa 
	smte \u2aac  smtes \u2aac\ufe00  SOFTcy \u42c  softcy \u44c 
	solbar \u233f  solb \u29c4  sol \u2f  Sopf \ud835\udd4a 
	sopf \ud835\udd64  spadesuit \u2660  spar \u2225  sqcap \u2293 
	sqcaps \u2293\ufe00  sqcup \u2294  sqcups \u2294\ufe00 
	Sqrt \u221a  sqsub \u228f  sqsube \u2291  sqsubset \u228f 
	sqsubseteq \u2291  sqsup \u2290  sqsupe \u2292  sqsupset \u2290 
	sqsupseteq \u2292  square \u25a1  Square \u25a1 
	SquareIntersection \u2293  SquareSubset \u228f 
	SquareSubsetEqual \u2291  SquareSuperset \u2290 
	SquareSupersetEqual \u2292  SquareUnion \u2294  squarf \u25aa 
	squ \u25a1  squf \u25aa  srarr \u2192  Sscr \ud835\udcae 
	sscr \ud835\udcc8  ssetmn \u2216  ssmile \u2323  sstarf \u22c6 
	Star \u22c6  star \u2606  starf \u2605  straightepsilon \u3f5 
	straightphi \u3d5  strns \uaf  Sub \u22d0  subdot \u2abd 
	subE \u2ac5  subedot \u2ac3  submult \u2ac1  subnE \u2acb 
	subne \u228a  subplus \u2abf  subrarr \u2979  subset \u2282 
	Subset \u22d0  subseteq \u2286  subseteqq \u2ac5 
	SubsetEqual \u2286  subsetneq \u228a  subsetneqq \u2acb 
	subsim \u2ac7  subsub \u2ad5  subsup \u2ad3  succapprox \u2ab8 
	succ \u227b  succcurlyeq \u227d  Succeeds \u227b 
	SucceedsEqual \u2ab0  SucceedsSlantEqual \u227d 
	SucceedsTilde \u227f  succeq \u2ab0  succnapprox \u2aba 
	succneqq \u2ab6  succnsim \u22e9  succsim \u227f  SuchThat \u220b 
	Sum \u2211  sung \u266a  Sup \u22d1  supdot \u2abe 
	supdsub \u2ad8  supE \u2ac6  supedot \u2ac4  Superset \u2283 
	SupersetEqual \u2287  suphsol \u27c9  suphsub \u2ad7 
	suplarr \u297b  supmult \u2ac2  supnE \u2acc  supne \u228b 
	supplus \u2ac0  supset \u2283  Supset \u22d1  supseteq \u2287 
	supseteqq \u2ac6  supsetneq \u228b  supsetneqq \u2acc 
	supsim \u2ac8  supsub \u2ad4  supsup \u2ad6  swarhk \u2926 
	swarr \u2199  swArr \u21d9  swarrow \u2199  swnwar \u292a 
	Tab \u9  target \u2316  tbrk \u23b4  Tcaron \u164  tcaron \u165 
	Tcedil \u162  tcedil \u163  Tcy \u422  tcy \u442  tdot \u20db 
	telrec \u2315  Tfr \ud835\udd17  tfr \ud835\udd31 
	therefore \u2234  Therefore \u2234  thetav \u3d1 
	thickapprox \u2248  thicksim \u223c  ThickSpace \u205f\u200a 
	ThinSpace \u2009  thkap \u2248  thksim \u223c  Tilde \u223c 
	TildeEqual \u2243  TildeFullEqual \u2245  TildeTilde \u2248 
	timesbar \u2a31  timesb \u22a0  timesd \u2a30  tint \u222d 
	toea \u2928  topbot \u2336  topcir \u2af1  top \u22a4 
	Topf \ud835\udd4b  topf \ud835\udd65  topfork \u2ada  tosa \u2929 
	tprime \u2034  TRADE \u2122  triangle \u25b5  triangledown \u25bf 
	triangleleft \u25c3  trianglelefteq \u22b4  triangleq \u225c 
	triangleright \u25b9  trianglerighteq \u22b5  tridot \u25ec 
	trie \u225c  triminus \u2a3a  TripleDot \u20db  triplus \u2a39 
	trisb \u29cd  tritime \u2a3b  trpezium \u23e2  Tscr \ud835\udcaf 
	tscr \ud835\udcc9  TScy \u426  tscy \u446  TSHcy \u40b 
	tshcy \u45b  Tstrok \u166  tstrok \u167  twixt \u226c 
	twoheadleftarrow \u219e  twoheadrightarrow \u21a0  Uarr \u219f 
	Uarrocir \u2949  Ubrcy \u40e  ubrcy \u45e  Ubreve \u16c 
	ubreve \u16d  Ucy \u423  ucy \u443  udarr \u21c5  Udblac \u170 
	udblac \u171  udhar \u296e  ufisht \u297e  Ufr \ud835\udd18 
	ufr \ud835\udd32  uHar \u2963  uharl \u21bf  uharr \u21be 
	uhblk \u2580  ulcorn \u231c  ulcorner \u231c  ulcrop \u230f 
	ultri \u25f8  Umacr \u16a  umacr \u16b  UnderBar \u5f 
	UnderBrace \u23df  UnderBracket \u23b5  UnderParenthesis \u23dd 
	Union \u22c3  UnionPlus \u228e  Uogon \u172  uogon \u173 
	Uopf \ud835\udd4c  uopf \ud835\udd66  UpArrowBar \u2912 
	uparrow \u2191  UpArrow \u2191  Uparrow \u21d1 
	UpArrowDownArrow \u21c5  updownarrow \u2195  UpDownArrow \u2195 
	Updownarrow \u21d5  UpEquilibrium \u296e  upharpoonleft \u21bf 
	upharpoonright \u21be  uplus \u228e  UpperLeftArrow \u2196 
	UpperRightArrow \u2197  upsi \u3c5  Upsi \u3d2  UpTeeArrow \u21a5 
	UpTee \u22a5  upuparrows \u21c8  urcorn \u231d  urcorner \u231d 
	urcrop \u230e  Uring \u16e  uring \u16f  urtri \u25f9 
	Uscr \ud835\udcb0  uscr \ud835\udcca  utdot \u22f0  Utilde \u168 
	utilde \u169  utri \u25b5  utrif \u25b4  uuarr \u21c8 
	uwangle \u29a7  vangrt \u299c  varepsilon \u3f5  varkappa \u3f0 
	varnothing \u2205  varphi \u3d5  varpi \u3d6  varpropto \u221d 
	varr \u2195  vArr \u21d5  varrho \u3f1  varsigma \u3c2 
	varsubsetneq \u228a\ufe00  varsubsetneqq \u2acb\ufe00 
	varsupsetneq \u228b\ufe00  varsupsetneqq \u2acc\ufe00 
	vartheta \u3d1  vartriangleleft \u22b2  vartriangleright \u22b3 
	vBar \u2ae8  Vbar \u2aeb  vBarv \u2ae9  Vcy \u412  vcy \u432 
	vdash \u22a2  vDash \u22a8  Vdash \u22a9  VDash \u22ab 
	Vdashl \u2ae6  veebar \u22bb  vee \u2228  Vee \u22c1 
	veeeq \u225a  vellip \u22ee  verbar \u7c  Verbar \u2016 
	vert \u7c  Vert \u2016  VerticalBar \u2223  VerticalLine \u7c 
	VerticalSeparator \u2758  VerticalTilde \u2240 
	VeryThinSpace \u200a  Vfr \ud835\udd19  vfr \ud835\udd33 
	vltri \u22b2  vnsub \u2282\u20d2  vnsup \u2283\u20d2 
	Vopf \ud835\udd4d  vopf \ud835\udd67  vprop \u221d  vrtri \u22b3 
	Vscr \ud835\udcb1  vscr \ud835\udccb  vsubnE \u2acb\ufe00 
	vsubne \u228a\ufe00  vsupnE \u2acc\ufe00  vsupne \u228b\ufe00 
	Vvdash \u22aa  vzigzag \u299a  Wcirc \u174  wcirc \u175 
	wedbar \u2a5f  wedge \u2227  Wedge \u22c0  wedgeq \u2259 
	Wfr \ud835\udd1a  wfr \ud835\udd34  Wopf \ud835\udd4e 
	wopf \ud835\udd68  wp \u2118  wr \u2240  wreath \u2240 
	Wscr \ud835\udcb2  wscr \ud835\udccc  xcap \u22c2  xcirc \u25ef 
	xcup \u22c3  xdtri \u25bd  Xfr \ud835\udd1b  xfr \ud835\udd35 
	xharr \u27f7  xhArr \u27fa  xlarr \u27f5  xlArr \u27f8 
	xmap \u27fc  xnis \u22fb  xodot \u2a00  Xopf \ud835\udd4f 
	xopf \ud835\udd69  xoplus \u2a01  xotime \u2a02  xrarr \u27f6 
	xrArr \u27f9  Xscr \ud835\udcb3  xscr \ud835\udccd  xsqcup \u2a06 
	xuplus \u2a04  xutri \u25b3  xvee \u22c1  xwedge \u22c0 
	YAcy \u42f  yacy \u44f  Ycirc \u176  ycirc \u177  Ycy \u42b 
	ycy \u44b  Yfr \ud835\udd1c  yfr \ud835\udd36  YIcy \u407 
	yicy \u457  Yopf \ud835\udd50  yopf \ud835\udd6a 
	Yscr \ud835\udcb4  yscr \ud835\udcce  YUcy \u42e  yucy \u44e 
	Zacute \u179  zacute \u17a  Zcaron \u17d  zcaron \u17e  Zcy \u417 
	zcy \u437  Zdot \u17b  zdot \u17c  zeetrf \u2128 
	ZeroWidthSpace \u200b  zfr \ud835\udd37  Zfr \u2128  ZHcy \u416 
	zhcy \u436  zigrarr \u21dd  zopf \ud835\udd6b  Zopf \u2124 
	Zscr \ud835\udcb5  zscr \ud835\udccf
    }

    # Internal cache for the foreach variable-lists and the
    # substitution strings used to split a HTML string into
    # incrementally handleable scripts. This should reduce the
    # time compute this information for repeated calls with the same
    # split-factor. The array is indexed by a combination of the
    # numerical split factor and the length of the command prefix and
    # maps this to a 2-element list containing variable- and
    # subst-string.

    variable  splitdata
    array set splitdata {}

}

# htmlparse::parse --
#
#	This command is the basic parser for HTML. It takes a HTML
#	string, parses it and invokes a command prefix for every tag
#	encountered. It is not necessary for the HTML to be valid for
#	this parser to function. It is the responsibility of the
#	command invoked for every tag to check this. Another
#	responsibility of the invoked command is the handling of tag
#	attributes and character entities (escaped characters). The
#	parser provides the un-interpreted tag attributes to the
#	invoked command to aid in the former, and the package at large
#	provides a helper command, '::htmlparse::mapEscapes', to aid
#	in the handling of the latter. The parser *does* ignore
#	leading DOCTYPE declarations and all valid HTML comments it
#	encounters.
#
#	All information beyond the HTML string itself is specified via
#	options, these are explained below.
#
#	To help understanding the options some more background
#	information about the parser.
#
#	It is capable to detect incomplete tags in the HTML string
#	given to it. Under normal circumstances this will cause the
#	parser to throw an error, but if the option '-incvar' is used
#	to specify a global (or namespace) variable the parser will
#	store the incomplete part of the input into this variable
#	instead. This will aid greatly in the handling of
#	incrementally arriving HTML as the parser will handle whatever
#	he can and defer the handling of the incomplete part until
#	more data has arrived.
#
#	Another feature of the parser are its two possible modes of
#	operation. The normal mode is activated if the option '-queue'
#	is not present on the command line invoking the parser. If it
#	is present the parser will go into the incremental mode instead.
#
#	The main difference is that a parser in normal mode will
#	immediately invoke the command prefix for each tag it
#	encounters. In incremental mode however the parser will
#	generate a number of scripts which invoke the command prefix
#	for groups of tags in the HTML string and then store these
#	scripts in the specified queue. It is then the responsibility
#	of the caller of the parser to ensure the execution of the
#	scripts in the queue.
#
#	Note: The queue objecct given to the parser has to provide the
#	same interface as the queue defined in tcllib -> struct. This
#	does for example mean that all queues created via that part of
#	tcllib can be immediately used here. Still, the queue doesn't
#	have to come from tcllib -> struct as long as the same
#	interface is provided.
#
#	In both modes the parser will return an empty string to the
#	caller.
#
#	To a parser in incremental mode the option '-split' can be
#	given and will specify the size of the groups he creates. In
#	other words, -split 5 means that each of the generated scripts
#	will invoke the command prefix for 5 consecutive tags in the
#	HTML string. A parser in normal mode will ignore this option
#	and its value.
#
#	The option '-vroot' specifies a virtual root tag. A parser in
#	normal mode will invoke the command prefix for it immediately
#	before and after he processes the tags in the HTML, thus
#	simulating that the HTML string is enclosed in a <vroot>
#	</vroot> combination. In incremental mode however the parser
#	is unable to provide the closing virtual root as he never
#	knows when the input is complete. In this case the first
#	script generated by each invocation of the parser will contain
#	an invocation of the command prefix for the virtual root as
#	its first command.
#
#	Interface to the command prefix:
#
#	In normal mode the parser will invoke the command prefix with
#	for arguments appended. See '::htmlparse::debugCallback' for a
#	description. In incremental mode however the generated scripts
#	will invoke the command prefix with five arguments
#	appended. The last four of these are the same which were
#	mentioned above. The first however is a placeholder string
#	(\win\) for a clientdata value to be supplied later during the
#	actual execution of the generated scripts. This could be a tk
#	window path, for example. This allows the user of this package
#	to preprocess HTML strings without commiting them to a
#	specific window, object, whatever during parsing. This
#	connection can be made later. This also means that it is
#	possible to cache preprocessed HTML. Of course, nothing
#	prevents the user of the parser to replace the placeholder
#	with an empty string.
#
# Arguments:
#	args	An option/value-list followed by the string to
#		parse. Available options are:
#
#		-cmd	The command prefix to invoke for every tag in
#			the HTML string. Defaults to
#			'::htmlparse::debugCallback'.
#
#		-vroot	The virtual root tag to add around the HTML in
#			normal mode. In incremental mode it is the
#			first tag in each chunk processed by the
#			parser, but there will be no closing tags.
#			Defaults to 'hmstart'.
#
#		-split	The size of the groups produced by an
#			incremental mode parser. Ignored when in
#			normal mode. Defaults to 10. Values <= 0 are
#			not allowed.
#
#		-incvar	The name of the variable where to store any
#			incomplete HTML into. Optional.
#
#		-queue
#			The handle/name of the queue objecct to store
#			the generated scripts into. Activates
#			incremental mode. Normal mode is used if this
#			option is not present.
#
#		After the options the command expects a single argument
#		containing the HTML string to parse.
#
# Side Effects:
#	In normal mode as of the invoked command. Else none.
#
# Results:
#	None.

proc ::htmlparse::parse {args} {
    # Convert the HTML string into a evaluable command sequence.

    variable splitdata

    # Option processing, start with the defaults, then run through the
    # list of arguments.

    set cmd    ::htmlparse::debugCallback
    set vroot  hmstart
    set incvar ""
    set split  10
    set queue  ""

    while {[set err [cmdline::getopt args {cmd.arg vroot.arg incvar.arg split.arg queue.arg} opt arg]]} {
	if {$err < 0} {
	    return -code error "::htmlparse::parse : $arg"
	}
	switch -exact -- $opt {
	    cmd    -
	    vroot  -
	    incvar -
	    queue  {
		if {[string length $arg] == 0} {
		    return -code error "::htmlparse::parse : -$opt illegal argument (empty)"
		}
		# Each option has an variable with the same name associated with it.
		# FRINK: nocheck
		set $opt $arg
	    }
	    split  {
		if {$arg <= 0} {
		    return -code error "::htmlparse::parse : -split illegal argument (<= 0)"
		}
		set split $arg
	    }
	    default {
		# Cannot happen
	    }
	}
    }

    if {[llength $args] > 1} {
	return -code error "::htmlparse::parse : to many arguments behind the options, expected one"
    }
    if {[llength $args] < 1} {
	return -code error "::htmlparse::parse : html string missing"
    }

    set html [PrepareHtml [lindex $args 0]]

    # Look for incomplete HTML from the last iteration and prepend it
    # to the input we just got.

    if {$incvar != {}} {
	upvar $incvar incomplete
    } else {
	set incomplete ""
    }

    if {[catch {set new $incomplete$html}]} {set new $html}
    set html $new

    # Handle incomplete HTML (Recognize incomplete tag at end, buffer
    # it up for the next call).

    set end [lindex \{$html\} end]
    if {[set idx [string last < $end]] > [string last > $end]} {

	if {$incvar == {}} {
	    return -code error "::htmlparse::parse : HTML is incomplete, option -incvar is missing"
	}

	#  upvar $incvar incomplete -- Already done, s.a.
	set incomplete [string range $end $idx end]
	incr idx -1
	set html       [string range $end 0 $idx]
	
    } else {
	set incomplete ""
    }

    # Convert the HTML string into a script. First look for tag
    # patterns and convert them into command invokations. The command
    # is actually a placeholder ((LF) NUL SOH @ NUL). See step 2 for
    # the explanation.

    regsub -all -- {<([^\s>]+)\s*([^>]*)/>} $html {<\1 \2></\1>} html

    #set sub "\}\n\0\1@\0 {\\1} {} {\\2} \{\}\n\0\1@\0 {\\1} {/} {} \{"
    #regsub -all -- {<([^\s>]+)\s*([^>]*)/>} $html $sub html

    set sub "\}\n\0\1@\0 {\\2} {\\1} {\\3} \{"
    regsub -all -- {<(/?)([^\s>]+)\s*([^>]*)>} $html $sub html

    # Step 2, replace the command placeholder with the command
    # itself. This way any characters in the command prefix which are
    # special to regsub are kept from the regsub.

    set html [string map [list \n\0\1@\0 \n$cmd] $html]

    # The value of queue now determines wether we process the HTML by
    # ourselves (queue is empty) or if we generate a list of  scripts
    # each of which processes n tags, n the argument to -split.

    if {$queue == {}} {
	# And evaluate it. This is the main parsing step.

	eval "$cmd {$vroot} {} {} \{$html\}"
	eval "$cmd {$vroot} /  {} {}"
    } else {
	# queue defined, generate list of scripts doing small chunks of tags.

	set lcmd [llength $cmd]
	set key  $split,$lcmd

	if {![info exists splitdata($key)]} {
	    for {set i 0; set group {}} {$i < $split} {incr i} {
		# Use the length of the command prefix to generate
		# additional variables before the main variable after
		# which the placeholder will be inserted.

		for {set j 1} {$j < $lcmd} {incr j} {
		    append group "b${j}_$i "
		}

		append group "a$i c$i d$i e$i f$i\n"
	    }
	    regsub -all -- {(a[0-9]+)}          $group    {{$\1} @win@} subgroup
	    regsub -all -- {([b-z_0-9]+[0-9]+)} $subgroup {{$\1}}       subgroup

	    set splitdata($key) [list $group $subgroup]
	}

	foreach {group subgroup} $splitdata($key) break ; # lassign
	foreach $group "$cmd {$vroot} {} {} \{$html\}" {
	    $queue put [string trimright [subst $subgroup]]
	}
    }
    return
}

# htmlparse::PrepareHtml --
#
#	Internal helper command of '::htmlparse::parse'. Removes
#	leading DOCTYPE declarations and comments, protects the
#	special characters of tcl from evaluation.
#
# Arguments:
#	html	The HTML string to prepare
#
# Side Effects:
#	None.
#
# Results:
#	The provided HTML string with the described modifications
#	applied to it.

proc ::htmlparse::PrepareHtml {html} {
    # Remove the following items from the text:
    # - A leading	<!DOCTYPE...> declaration.
    # - All comments	<!-- ... -->
    #
    # Also normalize the line endings (\r -> \n).

    # Tcllib SF Bug 861287 - Processing of comments.
    # Recognize EOC by RE, instead of fixed string.

    set html [string map [list \r \n] $html]

    regsub -- "^.*<!DOCTYPE\[^>\]*>"    $html {}     html
    regsub -all -- "--(\[ \t\n\]*)>"      $html "\001\\1\002" html

    # Recognize borken beginnings of a comment and convert them to PCDATA.
    regsub -all -- "<--(\[^\001\]*)\001(\[^\002\]*)\002" $html {\&lt;--\1--\2\&gt;} html

    # And now recognize true comments, remove them.
    regsub -all -- "<!--\[^\001\]*\001(\[^\002\]*)\002"  $html {}                   html

    # Protect characters special to tcl (braces, slashes) by
    # converting them to their escape sequences.

    return [string map [list \
		    "\{" "&#123;" \
		    "\}" "&#125;" \
		    "\\" "&#92;"] $html]
}



# htmlparse::debugCallback --
#
#	The standard callback used by the parser in
#	'::htmlparse::parse' if none was specified by the user. Simply
#	dumps its arguments to stdout.  This callback can be used for
#	both normal and incremental mode of the calling parser. In
#	other words, it accepts four or five arguments. The last four
#	arguments are described below. The optional fifth argument
#	contains the clientdata value given to the callback by a
#	parser in incremental mode. All callbacks have to follow the
#	signature of this command in the last four arguments, and
#	callbacks used in incremental parsing have to follow this
#	signature in the last five arguments.
#
# Arguments:
#	tag			The name of the tag currently
#				processed by the parser.
#
#	slash			Either empty or a slash. Allows us to
#				distinguish between opening (slash is
#				empty) and closing tags (slash is
#				equal to a '/').
#
#	param			The un-interpreted list of parameters
#				to the tag.
#
#	textBehindTheTag	The text found by the parser behind
#				the tag named in 'tag'.
#
# Side Effects:
#	None.
#
# Results:
#	None.

proc ::htmlparse::debugCallback {args} {
    # args = ?clientData? tag slash param textBehindTheTag
    puts "==> $args"
    return
}

# htmlparse::mapEscapes --
#
#	Takes a HTML string, substitutes all escape sequences with
#	their actual characters and returns the resulting string.
#	HTML not containing escape sequences or invalid escape
#	sequences is returned unchanged.
#
# Arguments:
#	html	The string to modify
#
# Side Effects:
#	None.
#
# Results:
#	The argument string with all escape sequences replaced with
#	their actual characters.

proc ::htmlparse::mapEscapes {html} {
    # Find HTML escape characters of the form &xxx(;|EOW)

    # Quote special Tcl chars so they pass through [subst] unharmed.
    set new [string map [list \] \\\] \[ \\\[ \$ \\\$ \\ \\\\] $html]
    regsub -all -- {&([[:alnum:]]{2,31})(;|\M)} $new {[DoNamedMap \1 {\2}]} new
    regsub -all -- {&#([[:digit:]]{1,5})(;|\M)} $new {[DoDecMap \1 {\2}]} new
    regsub -all -- {&#x([[:xdigit:]]{1,4})(;|\M)} $new {[DoHexMap \1 {\2}]} new
    return [subst $new]
}

proc ::htmlparse::DoNamedMap {name endOf} {
    variable namedEntities
    if {[info exist namedEntities($name)]} {
	return $namedEntities($name)
    } else {
	# Put it back..
	return "&$name$endOf"
    }
}

proc ::htmlparse::DoDecMap {dec endOf} {
    scan $dec %d dec
    if {$dec <= 0xFFFD} {
	return [format %c $dec]
    } else {
	# Put it back..
	return "&#$dec$endOf"
    }
}

proc ::htmlparse::DoHexMap {hex endOf} {
    scan $hex %x value
    if {$value <= 0xFFFD} {
	return [format %c $value]
    } else {
	# Put it back..
	return "&#x$hex$endOf"
    }
}

# htmlparse::2tree --
#
#	This command is a wrapper around '::htmlparse::parse' which
#	takes a HTML string and converts it into a tree containing the
#	logical structure of the parsed document. The tree object has
#	to be created by the caller. It is also expected that the tree
#	object provides the same interface as the tree object from
#	tcllib -> struct. It doesn't have to come from that module
#	though. The internal callback does some basic checking of HTML
#	validity and tries to recover from the most basic errors.
#
# Arguments:
#	html	The HTML string to parse and convert.
#	tree	The name of the tree to fill.
#
# Side Effects:
#	Creates a tree object (see tcllib -> struct)
#	and modifies it.
#
# Results:
#	The contents of 'tree'.

proc ::htmlparse::2tree {html tree} {

    # One internal datastructure is required, a stack of open
    # tags. This stack is also provided by the 'struct' module of
    # tcllib. As the operation of this command is synchronuous we
    # don't have to take care against multiple running copies at the
    # same times (Such are possible, but will be in different
    # interpreters and true concurrency is possible only if they are
    # in different threads too). IOW, no need for tricks to make the
    # internal datastructure unique.

    catch {::htmlparse::tags destroy}

    ::struct::stack ::htmlparse::tags
    ::htmlparse::tags push root
    $tree set root type root

    parse -cmd [list ::htmlparse::2treeCallback $tree] $html

    # A bit hackish, correct the ordering of nodes for the optional
    # tag types, over a larger area when was seen by the parser itself.

    $tree walk root -order post n {
	::htmlparse::Reorder $tree $n
    }

    ::htmlparse::tags destroy
    return $tree
}

# htmlparse::2treeCallback --
#
#	Internal helper command. A special callback to
#	'::htmlparse::parse' used by '::htmlparse::2tree' which takes
#	the incoming stream of tags and converts them into a tree
#	representing the inner structure of the parsed HTML
#	document. Recovers from simple HTML errors like missing
#	opening tags, missing closing tags and overlapping tags.
#
# Arguments:
#	tree			The name of the tree to manipulate.
#	tag			See '::htmlparse::debugCallback'.
#	slash			See '::htmlparse::debugCallback'.
#	param			See '::htmlparse::debugCallback'.
#	textBehindTheTag	See '::htmlparse::debugCallback'.
#
# Side Effects:
#	Manipulates the tree object whose name was given as the first
#	argument.
#
# Results:
#	None.

proc ::htmlparse::2treeCallback {tree tag slash param textBehindTheTag} {
    # This could be table-driven I think but for now the switches
    # should work fine.

    # Normalize tag information for later comparisons. Also remove
    # superfluous whitespace. Don't forget to decode the standard
    # entities.

    set  tag  [string tolower $tag]
    set  textBehindTheTag [string trim $textBehindTheTag]
    if {$textBehindTheTag != {}} {
	set text [mapEscapes $textBehindTheTag]
    }

    if {"$slash" == "/"} {
	# Handle closing tags. Standard operation is to pop the tag
	# from the stack of open tags. We don't do this for </p> and
	# </li>. As they were optional they were never pushed onto the
	# stack (Well, actually they are just popped immediately after
	# they were pusheed, see below).

	switch -exact -- $tag {
	    base - option - meta - li - p {
		# Ignore, nothing to do.		
	    }
	    default {
		# The moment we get a closing tag which does not match
		# the tag on the stack we have two possibilities on how
		# this came into existence to choose from:
		#
		# a) A tag is now closed but was never opened.
		# b) A tag requiring an end tag was opened but the end
		#    tag was omitted and we now are at a tag which was
		#    opened before the one with the omitted end tag.

		# NOTE:
		# Pages delivered from the amazon.uk site contain both
		# cases: </a> without opening, <b> & <font> without
		# closing. Another error: <a><b></a></b>, i.e. overlapping
		# tags. Fortunately this can be handled by the algorithm
		# below, in two cycles, one of which is case (b), followed
		# by case (a). It seems as if Amazon/UK believes that visual
		# markup like <b> and <font> is an option (switch-on) instead
		# of a region.

		# Algorithm used here to deal with these:
		# 1) Search whole stack for the matching opening tag.
		#    If there is one assume case (b) and pop everything
		#    until and including this opening tag.
		# 2) If no matching opening tag was found assume case
		#    (a) and ignore the tag.
		#
		# Part (1) also subsumes the normal case, i.e. the
		# matching tag is at the top of the stack.

		set nodes [::htmlparse::tags peek [::htmlparse::tags size]]
		# Note: First item is top of stack, last item is bottom of stack !
		# (This behaviour of tcllib stacks is not documented
		# -> we should update the manpage).

		#foreach n $nodes {lappend tstring [p get $n -key type]}
		#puts stderr --[join $tstring]--

		set level 1
		set found 0
		foreach n $nodes {
		    set type [$tree get $n type]
		    if {0 == [string compare $tag $type]} {
			# Found an earlier open tag -> (b).
			set found 1
			break
		    }
		    incr level
		}
		if {$found} {
		    ::htmlparse::tags pop $level
		    if {$level > 1} {
			#foreach n $nodes {lappend tstring [$tree get $n type]}
			#puts stderr "\tdesync at <$tag> ($tstring) => pop $level"
		    }
		} else {
		    #foreach n $nodes {lappend tstring [$tree get $n type]}
		    #puts stderr "\tdesync at <$tag> ($tstring) => ignore"
		}
	    }
	}

	# If there is text behind a closing tag X it belongs to the
	# parent tag of X.

	if {$textBehindTheTag != {}} {
	    # Attach the text behind the closing tag to the reopened
	    # context.

	    set        pcd  [$tree insert [::htmlparse::tags peek] end]
	    $tree set $pcd  type PCDATA
	    $tree set $pcd  data $textBehindTheTag
	}

    } else {
	# Handle opening tags. The standard operation for most is to
	# push them onto the stack and thus open a nested context.
	# This does not happen for both the optional tags (p, li) and
	# the ones which don't have closing tags (meta, br, option,
	# input, area, img).
	#
	# The text coming with the tag will be added after the tag if
	# it is a tag without a matching close, else it will be added
	# as a node below the tag (as it is the region between the
	# opening and closing tag and thus nested inside). Empty text
	# is ignored under all circcumstances.

	set        node [$tree insert [::htmlparse::tags peek] end]
	$tree set $node type $tag
	$tree set $node data $param

	if {$textBehindTheTag != {}} {
	    switch -exact -- $tag {
		input -	area - img - br {
		    set pcd  [$tree insert [::htmlparse::tags peek] end]
		}
		default {
		    set pcd  [$tree insert $node end]
		}
	    }
	    $tree set $pcd type PCDATA
	    $tree set $pcd data $textBehindTheTag
	}

	::htmlparse::tags push $node

	# Special handling: <p>, <li> may have no closing tag => pop
	#                 : them immediately.
	#
	# Special handling: <meta>, <br>, <option>, <input>, <area>,
	#                 : <img>: no closing tags for these.

	switch -exact -- $tag {
	    hr - base - meta - li - br - option - input - area - img - p - h1 - h2 - h3 - h4 - h5 - h6 {
		::htmlparse::tags pop
	    }
	    default {}
	}
    }
}

# htmlparse::removeVisualFluff --
#
#	This command walks a tree as generated by '::htmlparse::2tree'
#	and removes all the nodes which represent visual tags and not
#	structural ones. The purpose of the command is to make the
#	tree easier to navigate without getting bogged down in visual
#	information not relevant to the search.
#
# Arguments:
#	tree	The name of the tree to cut down.
#
# Side Effects:
#	Modifies the specified tree.
#
# Results:
#	None.

proc ::htmlparse::removeVisualFluff {tree} {
    $tree walk root -order post n {
	::htmlparse::RemoveVisualFluff $tree $n
    }
    return
}

# htmlparse::removeFormDefs --
#
#	Like '::htmlparse::removeVisualFluff' this command is here to
#	cut down on the size of the tree as generated by
#	'::htmlparse::2tree'. It removes all nodes representing forms
#	and form elements.
#
# Arguments:
#	tree	The name of the tree to cut down.
#
# Side Effects:
#	Modifies the specified tree.
#
# Results:
#	None.

proc ::htmlparse::removeFormDefs {tree} {
    $tree walk root -order post n {
	::htmlparse::RemoveFormDefs $tree $n
    }
    return
}

# htmlparse::RemoveVisualFluff --
#
#	Internal helper command to
#	'::htmlparse::removeVisualFluff'. Does the actual work.
#
# Arguments:
#	tree	The name of the tree currently processed
#	node	The name of the node to look at.
#
# Side Effects:
#	Modifies the specified tree.
#
# Results:
#	None.

proc ::htmlparse::RemoveVisualFluff {tree node} {
    switch -exact -- [$tree get $node type] {
	hmstart - html - font - center - div - sup - b - i {
	    # Removes the node, but does not affect the nodes below
	    # it. These are just made into chiildren of the parent of
	    # this node, in its place.

	    $tree cut $node
	}
	script - option - select - meta - map - img {
	    # Removes this node and everything below it.
	    $tree delete $node
	}
	default {
	    # Ignore tag
	}
    }
}

# htmlparse::RemoveFormDefs --
#
#	Internal helper command to
#	'::htmlparse::removeFormDefs'. Does the actual work.
#
# Arguments:
#	tree	The name of the tree currently processed
#	node	The name of the node to look at.
#
# Side Effects:
#	Modifies the specified tree.
#
# Results:
#	None.

proc ::htmlparse::RemoveFormDefs {tree node} {
    switch -exact -- [$tree get $node type] {
	form {
	    $tree delete $node
	}
	default {
	    # Ignore tag
	}
    }
}

# htmlparse::Reorder --

#	Internal helper command to '::htmlparse::2tree'. Moves the
#	nodes between p/p, li/li and h<i> sequences below the
#	paragraphs and items. IOW, corrects misconstructions for
#	the optional node types.
#
# Arguments:
#	tree	The name of the tree currently processed
#	node	The name of the node to look at.
#
# Side Effects:
#	Modifies the specified tree.
#
# Results:
#	None.

proc ::htmlparse::Reorder {tree node} {
    switch -exact -- [set tp [$tree get $node type]] {
	h1 - h2 - h3 - h4 - h5 - h6 - p - li {
	    # Look for right siblings until the next node with a
	    # similar type (or end of level) and move these below this
	    # node.

	    while {1} {
		set sibling [$tree next $node]
		if {
		    ($sibling == {}) ||
		    ([lsearch -exact {h1 h2 h3 h4 h5 h6 p li} [$tree get $sibling type]] != -1)
		} {
		    break
		}
		$tree move $node end $sibling
	    }
	}
	default {
	    # Ignore tag
	}
    }
}

# ### ######### ###########################

package provide htmlparse 1.2.2
