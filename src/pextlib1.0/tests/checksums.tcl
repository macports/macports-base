# Test file for Pextlib's md5 and sha1 commands.
# Requires r/w access to /tmp/
# Syntax:
# tclsh checksums.tcl <Pextlib name>

proc main {pextlibname} {
	load $pextlibname
	
	encoding system utf-8
	
	set testfile "/tmp/macports-pextlib-testchecksums"
	file delete -force $testfile

	# create a dummy file.
	set chan [open $testfile w]
	puts $chan "Article premier"
	puts $chan "  Tous les �tres humains naissent libres et �gaux en dignit� "
	puts $chan " et en droits. Ils sont dou�s de raison et de conscience et "
	puts $chan " doivent agir les uns envers les autres dans un esprit de "
	puts $chan " fraternit�."
	puts $chan "Article 2"
	puts $chan "  Chacun peut se pr�valoir de tous les droits et de toutes les "
	puts $chan " libert�s proclam�s dans la pr�sente D�claration, sans "
	puts $chan " distinction aucune, notamment de race, de couleur, de sexe, "
	puts $chan " de langue, de religion, d'opinion politique ou de toute autre "
	puts $chan " opinion, d'origine nationale ou sociale, de fortune, de "
	puts $chan " naissance ou de toute autre situation."
	puts $chan "  De plus, il ne sera fait aucune distinction fond�e sur le "
	puts $chan " statut politique, juridique ou international du pays ou du "
	puts $chan " territoire dont une personne est ressortissante, que ce pays "
	puts $chan " ou territoire soit ind�pendant, sous tutelle, non autonome ou "
	puts $chan " soumis � une limitation quelconque de souverainet�."
	close $chan
	
	# checksum the file.
	if {[md5 file $testfile] != "91d3ef5cd86741957b0b5d8f8911166d"} {
		puts {[md5 file $testfile] != "91d3ef5cd86741957b0b5d8f8911166d"}
		exit 1
	}
	if {[sha1 file $testfile] != "a40f8539f217a0032d194c3a8c42cc832b6379cf"} {
		puts {[sha1 file $testfile] != "a40f8539f217a0032d194c3a8c42cc832b6379cf"}
		exit 1
	}
	if {[rmd160 file $testfile] != "b654ecbdced69aba8a4ea8d6824dd1ac103b3116"} {
		puts {[rmd160 file $testfile] != "b654ecbdced69aba8a4ea8d6824dd1ac103b3116"}
		exit 1
	}
	if {[sha256 file $testfile] != "424359e1002a1d117f12f95346a81987037b3fde60a564a7aacb48c65a518fe5"} {
		puts {[sha256 file $testfile] != "424359e1002a1d117f12f95346a81987037b3fde60a564a7aacb48c65a518fe5"}
		exit 1
	}

	# delete the file.
	file delete -force $testfile
}

main $argv