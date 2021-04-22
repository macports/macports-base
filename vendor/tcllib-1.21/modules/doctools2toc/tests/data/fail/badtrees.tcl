package require struct::tree
package require fileutil

struct::tree T
fileutil::writeFile in-vt/0_root_label [T serialize]
T set root label L
fileutil::writeFile in-vt/1_root_title [T serialize]
T set root title T
T insert root end K
fileutil::writeFile in-vt/2_keyword_label [T serialize]
T set K label L
T insert K end R
fileutil::writeFile in-vt/3_ref_type [T serialize]
T set R type foo
fileutil::writeFile in-vt/4_ref_label [T serialize]
T set R label L
fileutil::writeFile in-vt/5_ref_ref [T serialize]
T set R ref X
fileutil::writeFile in-vt/6_ref_tag [T serialize]
T set R type url
T insert R end OVER
fileutil::writeFile in-vt/7_depth [T serialize]
exit
