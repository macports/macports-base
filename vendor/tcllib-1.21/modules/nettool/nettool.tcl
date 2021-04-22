###
# Amalgamated package for nettool
# Do not edit directly, tweak the source in src/ and rerun
# build.tcl
###
package require Tcl 8.5
package provide nettool 0.5.2
namespace eval ::nettool {}
set ::nettool::version 0.5.2

###
# START: core.tcl
###
# @mdgen OWNER: generic.tcl
# @mdgen OWNER: available_ports.tcl
# @mdgen OWNER: locateport.tcl
# @mdgen OWNER: platform_unix_linux.tcl
# @mdgen OWNER: platform_unix_macosx.tcl
# @mdgen OWNER: platform_unix.tcl
# @mdgen OWNER: platform_windows.tcl


package require platform
# Uses the "ip" package from tcllib
package require ip

if {[info commands ::ladd] eq {}} {
  proc ::ladd {varname args} {
    upvar 1 $varname var
    if ![info exists var] {
        set var {}
    }
    foreach item $args {
      if {$item in $var} continue
      lappend var $item
    }
    return $var
  }
}
if {[info commands ::get] eq {}} {
  proc ::get varname {
    upvar 1 $varname var
    if {[info exists var]} {
      return [set var]
    }
    return {}
  }
}
if {[info commands ::cat] eq {}} {
  proc ::cat filename {
    set fin [open $filename r]
    set dat [read $fin]
    close $fin
    return $dat
  }
}


set here [file dirname [file normalize [info script]]]

::namespace eval ::nettool {}

set genus [lindex [split [::platform::generic] -] 0]
dict set ::nettool::platform tcl_os  $::tcl_platform(os)
dict set ::nettool::platform odie_class   $::tcl_platform(platform)
dict set ::nettool::platform odie_genus   $genus
dict set ::nettool::platform odie_target  [::platform::generic]
dict set ::nettool::platform odie_species [::platform::identify]



###
# END: core.tcl
###
###
# START: generic.tcl
###
::namespace eval ::nettool {}

###
# topic: 825cd25953c2cc896a96006b7f454e00
# title: Return pairings of MAC numbers to IP addresses on the local network
###
proc ::nettool::arp_table {} {}

###
# topic: 92ebbfa155883ad41c37d3f843392be4
# title: Return list of broadcast addresses for local networks
###
proc ::nettool::broadcast_list {} {
  return 127.0.0.1
}

###
# topic: 15d9bc96ec6ce31d4c8f99a425a9c02c
# description: Return Processor utilization
###
proc ::nettool::busy {} {}

###
# topic: 187cfa1827097c5cdf1c40c656cedfcc
# description: Return time since booted
###
proc ::nettool::cpuinfo {} {}

###
# Clear discovered info
###
proc ::nettool::discover {} {
  unset -nocomplain ::nettool::ipinfo ::nettool::macinfo
}

###
# topic: 58295f2544f43827e855d09dc3ee625a
###
proc ::nettool::diskless_client {} {
  return 0
}

###
# topic: 57fdc331bc60c7bf2bd3f3214e9a906f
###
proc ::nettool::hwaddr_to_ipaddr {hwaddr args} {}

###
# topic: dd2e2c0810cea69909399808f2a68949
# title: Return a list of unique hardware ids
###
proc ::nettool::hwid_list {} {
  set result {}
  foreach mac [::nettool::mac_list] {
    lappend result 0x[string map {: {}} $mac]
  }
  if {[llength $result]} {
    return $result
  }
  return 0x010203040506
}

###
# topic: 4b87d977492bd10802bfc0327cd07ac2
# title: Return list of network interfaces
###
proc ::nettool::if_list {} {}

###
# topic: d2932eb0ea8cc9f6a865c1ab7cdd4572
# description:
#    Called on package load to build any static
#    structures to cache data that would be time
#    consuming to call on the fly
###
proc ::nettool::init {} {}

###
# topic: 417672d3f31b80d749588365af88baf6
# title: Return list of ip addresses for this computer (primary first)
###
proc ::nettool::ip_list {} {}

###
# topic: ac9d6815d47f60d45930f0c8c8ae8f16
# title: Return list of mac numbers for this computer (primary first)
###
proc ::nettool::mac_list {} {}

###
# topic: c42343f20e3afd2884a5dd1c219e4415
###
proc ::nettool::platform {} {
  variable platform
  return $platform
}

proc ::nettool::user_data_root {appname} {
  return [file join $::env(HOME) .$appname]
}

###
# END: generic.tcl
###
###
# START: available_ports.tcl
###
###
# topic: 868a79cedf28924191fd86aa85f6dd1d
###
namespace eval ::nettool {
  set blocks {}
}

lappend ::nettool::blocks 1028 1028
lappend ::nettool::blocks 1067 1068
lappend ::nettool::blocks 1109 1109
lappend ::nettool::blocks 1138 1138
lappend ::nettool::blocks 1313 1313
lappend ::nettool::blocks 1382 1382
lappend ::nettool::blocks 1385 1385
lappend ::nettool::blocks 1416 1416
lappend ::nettool::blocks 1454 1454
lappend ::nettool::blocks 1461 1461
lappend ::nettool::blocks 1464 1464
lappend ::nettool::blocks 1486 1486
lappend ::nettool::blocks 1491 1491
lappend ::nettool::blocks 1493 1493
lappend ::nettool::blocks 1528 1528
lappend ::nettool::blocks 1556 1556
lappend ::nettool::blocks 1587 1587
lappend ::nettool::blocks 1651 1651
lappend ::nettool::blocks 1783 1783
lappend ::nettool::blocks 1895 1895
lappend ::nettool::blocks 2083 2083
lappend ::nettool::blocks 2194 2196
lappend ::nettool::blocks 2222 2222
lappend ::nettool::blocks 2259 2259
lappend ::nettool::blocks 2340 2340
lappend ::nettool::blocks 2346 2349
lappend ::nettool::blocks 2369 2369
lappend ::nettool::blocks 2377 2378
lappend ::nettool::blocks 2395 2395
lappend ::nettool::blocks 2426 2426
lappend ::nettool::blocks 2446 2446
lappend ::nettool::blocks 2528 2528
lappend ::nettool::blocks 2640 2640
lappend ::nettool::blocks 2654 2654
lappend ::nettool::blocks 2682 2682
lappend ::nettool::blocks 2693 2693
lappend ::nettool::blocks 2794 2794
lappend ::nettool::blocks 2825 2825
lappend ::nettool::blocks 2873 2873
lappend ::nettool::blocks 2916 2917
lappend ::nettool::blocks 2925 2925
lappend ::nettool::blocks 3014 3014
lappend ::nettool::blocks 3016 3019
lappend ::nettool::blocks 3024 3024
lappend ::nettool::blocks 3027 3029
lappend ::nettool::blocks 3050 3050
lappend ::nettool::blocks 3080 3080
lappend ::nettool::blocks 3092 3092
lappend ::nettool::blocks 3126 3126
lappend ::nettool::blocks 3300 3301
lappend ::nettool::blocks 3396 3396
lappend ::nettool::blocks 3403 3404
lappend ::nettool::blocks 3546 3546
lappend ::nettool::blocks 3693 3694
lappend ::nettool::blocks 3876 3876
lappend ::nettool::blocks 3900 3900
lappend ::nettool::blocks 3938 3938
lappend ::nettool::blocks 3970 3970
lappend ::nettool::blocks 3986 3986
lappend ::nettool::blocks 3994 3994
lappend ::nettool::blocks 4000 4000
lappend ::nettool::blocks 4048 4048
lappend ::nettool::blocks 4060 4060
lappend ::nettool::blocks 4065 4065
lappend ::nettool::blocks 4120 4120
lappend ::nettool::blocks 4132 4133
lappend ::nettool::blocks 4140 4140
lappend ::nettool::blocks 4144 4144
lappend ::nettool::blocks 4151 4152
lappend ::nettool::blocks 4184 4184
lappend ::nettool::blocks 4194 4198
lappend ::nettool::blocks 4315 4315
lappend ::nettool::blocks 4317 4319
lappend ::nettool::blocks 4332 4332
lappend ::nettool::blocks 4334 4339
lappend ::nettool::blocks 4363 4367
lappend ::nettool::blocks 4370 4370
lappend ::nettool::blocks 4380 4388
lappend ::nettool::blocks 4397 4399
lappend ::nettool::blocks 4412 4424
lappend ::nettool::blocks 4434 4440
lappend ::nettool::blocks 4459 4483
lappend ::nettool::blocks 4489 4499
lappend ::nettool::blocks 4501 4501
lappend ::nettool::blocks 4503 4533
lappend ::nettool::blocks 4539 4544
lappend ::nettool::blocks 4560 4562
lappend ::nettool::blocks 4564 4565
lappend ::nettool::blocks 4569 4569
lappend ::nettool::blocks 4571 4589
lappend ::nettool::blocks 4606 4657
lappend ::nettool::blocks 4693 4699
lappend ::nettool::blocks 4705 4724
lappend ::nettool::blocks 4734 4736
lappend ::nettool::blocks 4746 4746
lappend ::nettool::blocks 4748 4748
lappend ::nettool::blocks 4754 4783
lappend ::nettool::blocks 4792 4799
lappend ::nettool::blocks 4805 4826
lappend ::nettool::blocks 4828 4836
lappend ::nettool::blocks 4846 4846
lappend ::nettool::blocks 4852 4866
lappend ::nettool::blocks 4872 4875
lappend ::nettool::blocks 4886 4893
lappend ::nettool::blocks 4895 4898
lappend ::nettool::blocks 4903 4911
lappend ::nettool::blocks 4916 4935
lappend ::nettool::blocks 4938 4939
lappend ::nettool::blocks 4943 4948
lappend ::nettool::blocks 4954 4968
lappend ::nettool::blocks 4971 4983
lappend ::nettool::blocks 4992 4998
lappend ::nettool::blocks 5016 5019
lappend ::nettool::blocks 5033 5041
lappend ::nettool::blocks 5076 5077
lappend ::nettool::blocks 5088 5089
lappend ::nettool::blocks 5095 5098
lappend ::nettool::blocks 5107 5110
lappend ::nettool::blocks 5113 5113
lappend ::nettool::blocks 5118 5119
lappend ::nettool::blocks 5121 5132
lappend ::nettool::blocks 5138 5145
lappend ::nettool::blocks 5147 5149
lappend ::nettool::blocks 5151 5151
lappend ::nettool::blocks 5158 5160
lappend ::nettool::blocks 5165 5165
lappend ::nettool::blocks 5169 5171
lappend ::nettool::blocks 5173 5189
lappend ::nettool::blocks 5197 5199
lappend ::nettool::blocks 5204 5208
lappend ::nettool::blocks 5210 5214
lappend ::nettool::blocks 5216 5220
lappend ::nettool::blocks 5238 5244
lappend ::nettool::blocks 5254 5263
lappend ::nettool::blocks 5266 5268
lappend ::nettool::blocks 5273 5279
lappend ::nettool::blocks 5283 5297
lappend ::nettool::blocks 5311 5311
lappend ::nettool::blocks 5316 5316
lappend ::nettool::blocks 5319 5319
lappend ::nettool::blocks 5322 5342
lappend ::nettool::blocks 5345 5348
lappend ::nettool::blocks 5365 5396
lappend ::nettool::blocks 5438 5442
lappend ::nettool::blocks 5444 5444
lappend ::nettool::blocks 5446 5452
lappend ::nettool::blocks 5457 5460
lappend ::nettool::blocks 5466 5499
lappend ::nettool::blocks 5507 5552
lappend ::nettool::blocks 5558 5565
lappend ::nettool::blocks 5570 5572
lappend ::nettool::blocks 5576 5578
lappend ::nettool::blocks 5587 5596
lappend ::nettool::blocks 5606 5617
lappend ::nettool::blocks 5619 5626
lappend ::nettool::blocks 5640 5645
lappend ::nettool::blocks 5647 5669
lappend ::nettool::blocks 5685 5686
lappend ::nettool::blocks 5690 5692
lappend ::nettool::blocks 5694 5695
lappend ::nettool::blocks 5697 5712
lappend ::nettool::blocks 5731 5740
lappend ::nettool::blocks 5749 5749
lappend ::nettool::blocks 5751 5754
lappend ::nettool::blocks 5756 5756
lappend ::nettool::blocks 5758 5765
lappend ::nettool::blocks 5772 5776
lappend ::nettool::blocks 5778 5779
lappend ::nettool::blocks 5788 5792
lappend ::nettool::blocks 5795 5812
lappend ::nettool::blocks 5815 5840
lappend ::nettool::blocks 5843 5858
lappend ::nettool::blocks 5860 5862
lappend ::nettool::blocks 5864 5867
lappend ::nettool::blocks 5869 5882
lappend ::nettool::blocks 5884 5899
lappend ::nettool::blocks 5901 5909
lappend ::nettool::blocks 5914 5962
lappend ::nettool::blocks 5964 5967
lappend ::nettool::blocks 5970 5983
lappend ::nettool::blocks 5993 5998
lappend ::nettool::blocks 6067 6067
lappend ::nettool::blocks 6078 6080
lappend ::nettool::blocks 6089 6098
lappend ::nettool::blocks 6119 6120
lappend ::nettool::blocks 6125 6129
lappend ::nettool::blocks 6131 6132
lappend ::nettool::blocks 6134 6139
lappend ::nettool::blocks 6150 6158
lappend ::nettool::blocks 6164 6199
lappend ::nettool::blocks 6202 6221
lappend ::nettool::blocks 6223 6240
lappend ::nettool::blocks 6245 6250
lappend ::nettool::blocks 6254 6266
lappend ::nettool::blocks 6270 6299
lappend ::nettool::blocks 6301 6305
lappend ::nettool::blocks 6307 6314
lappend ::nettool::blocks 6318 6319
lappend ::nettool::blocks 6323 6323
lappend ::nettool::blocks 6327 6342
lappend ::nettool::blocks 6345 6345
lappend ::nettool::blocks 6348 6349
lappend ::nettool::blocks 6351 6354
lappend ::nettool::blocks 6356 6359
lappend ::nettool::blocks 6361 6362
lappend ::nettool::blocks 6364 6369
lappend ::nettool::blocks 6371 6381
lappend ::nettool::blocks 6383 6388
lappend ::nettool::blocks 6391 6399
lappend ::nettool::blocks 6411 6416
lappend ::nettool::blocks 6422 6431
lappend ::nettool::blocks 6433 6441
lappend ::nettool::blocks 6444 6445
lappend ::nettool::blocks 6447 6454
lappend ::nettool::blocks 6457 6470
lappend ::nettool::blocks 6472 6479
lappend ::nettool::blocks 6490 6499
lappend ::nettool::blocks 6501 6508
lappend ::nettool::blocks 6512 6512
lappend ::nettool::blocks 6516 6542
lappend ::nettool::blocks 6545 6546
lappend ::nettool::blocks 6552 6557
lappend ::nettool::blocks 6559 6565
lappend ::nettool::blocks 6569 6578
lappend ::nettool::blocks 6584 6599
lappend ::nettool::blocks 6603 6618
lappend ::nettool::blocks 6629 6631
lappend ::nettool::blocks 6635 6639
lappend ::nettool::blocks 6641 6652
lappend ::nettool::blocks 6654 6654
lappend ::nettool::blocks 6658 6664
lappend ::nettool::blocks 6672 6677
lappend ::nettool::blocks 6680 6686
lappend ::nettool::blocks 6690 6695
lappend ::nettool::blocks 6698 6700
lappend ::nettool::blocks 6707 6713
lappend ::nettool::blocks 6717 6766
lappend ::nettool::blocks 6772 6776
lappend ::nettool::blocks 6779 6783
lappend ::nettool::blocks 6792 6800
lappend ::nettool::blocks 6802 6816
lappend ::nettool::blocks 6818 6830
lappend ::nettool::blocks 6832 6840
lappend ::nettool::blocks 6843 6849
lappend ::nettool::blocks 6851 6867
lappend ::nettool::blocks 6869 6887
lappend ::nettool::blocks 6889 6900
lappend ::nettool::blocks 6902 6934
lappend ::nettool::blocks 6937 6945
lappend ::nettool::blocks 6947 6950
lappend ::nettool::blocks 6952 6960
lappend ::nettool::blocks 6967 6968
lappend ::nettool::blocks 6971 6996
lappend ::nettool::blocks 7016 7017
lappend ::nettool::blocks 7026 7029
lappend ::nettool::blocks 7032 7039
lappend ::nettool::blocks 7041 7069
lappend ::nettool::blocks 7072 7072
lappend ::nettool::blocks 7074 7079
lappend ::nettool::blocks 7081 7094
lappend ::nettool::blocks 7096 7098
lappend ::nettool::blocks 7102 7106
lappend ::nettool::blocks 7108 7120
lappend ::nettool::blocks 7122 7127
lappend ::nettool::blocks 7130 7160
lappend ::nettool::blocks 7175 7180
lappend ::nettool::blocks 7182 7199
lappend ::nettool::blocks 7202 7226
lappend ::nettool::blocks 7230 7234
lappend ::nettool::blocks 7238 7261
lappend ::nettool::blocks 7263 7271
lappend ::nettool::blocks 7284 7299
lappend ::nettool::blocks 7360 7364
lappend ::nettool::blocks 7366 7390
lappend ::nettool::blocks 7396 7396
lappend ::nettool::blocks 7398 7399
lappend ::nettool::blocks 7403 7409
lappend ::nettool::blocks 7412 7420
lappend ::nettool::blocks 7422 7425
lappend ::nettool::blocks 7432 7436
lappend ::nettool::blocks 7438 7442
lappend ::nettool::blocks 7444 7470
lappend ::nettool::blocks 7472 7472
lappend ::nettool::blocks 7475 7490
lappend ::nettool::blocks 7492 7499
lappend ::nettool::blocks 7502 7507
lappend ::nettool::blocks 7512 7541
lappend ::nettool::blocks 7551 7559
lappend ::nettool::blocks 7561 7562
lappend ::nettool::blocks 7564 7565
lappend ::nettool::blocks 7567 7568
lappend ::nettool::blocks 7571 7573
lappend ::nettool::blocks 7575 7587
lappend ::nettool::blocks 7589 7623
lappend ::nettool::blocks 7625 7625
lappend ::nettool::blocks 7632 7632
lappend ::nettool::blocks 7634 7647
lappend ::nettool::blocks 7649 7671
lappend ::nettool::blocks 7678 7679
lappend ::nettool::blocks 7681 7688
lappend ::nettool::blocks 7690 7696
lappend ::nettool::blocks 7698 7699
lappend ::nettool::blocks 7701 7706
lappend ::nettool::blocks 7709 7719
lappend ::nettool::blocks 7721 7723
lappend ::nettool::blocks 7728 7733
lappend ::nettool::blocks 7735 7737
lappend ::nettool::blocks 7739 7740
lappend ::nettool::blocks 7745 7746
lappend ::nettool::blocks 7748 7776
lappend ::nettool::blocks 7780 7780
lappend ::nettool::blocks 7782 7785
lappend ::nettool::blocks 7788 7788
lappend ::nettool::blocks 7790 7793
lappend ::nettool::blocks 7795 7796
lappend ::nettool::blocks 7803 7809
lappend ::nettool::blocks 7811 7844
lappend ::nettool::blocks 7848 7868
lappend ::nettool::blocks 7873 7877
lappend ::nettool::blocks 7879 7879
lappend ::nettool::blocks 7881 7886
lappend ::nettool::blocks 7888 7899
lappend ::nettool::blocks 7904 7912
lappend ::nettool::blocks 7914 7931
lappend ::nettool::blocks 7934 7961
lappend ::nettool::blocks 7963 7966
lappend ::nettool::blocks 7968 7978
lappend ::nettool::blocks 7983 7996
lappend ::nettool::blocks 8004 8004
lappend ::nettool::blocks 8006 8007
lappend ::nettool::blocks 8009 8018
lappend ::nettool::blocks 8023 8024
lappend ::nettool::blocks 8027 8031
lappend ::nettool::blocks 8035 8039
lappend ::nettool::blocks 8041 8041
lappend ::nettool::blocks 8045 8050
lappend ::nettool::blocks 8061 8065
lappend ::nettool::blocks 8067 8073
lappend ::nettool::blocks 8075 8079
lappend ::nettool::blocks 8084 8085
lappend ::nettool::blocks 8089 8090
lappend ::nettool::blocks 8092 8096
lappend ::nettool::blocks 8098 8099
lappend ::nettool::blocks 8103 8114
lappend ::nettool::blocks 8119 8120
lappend ::nettool::blocks 8123 8127
lappend ::nettool::blocks 8133 8139
lappend ::nettool::blocks 8141 8147
lappend ::nettool::blocks 8150 8152
lappend ::nettool::blocks 8154 8159
lappend ::nettool::blocks 8163 8180
lappend ::nettool::blocks 8185 8190
lappend ::nettool::blocks 8193 8193
lappend ::nettool::blocks 8196 8198
lappend ::nettool::blocks 8203 8203
lappend ::nettool::blocks 8209 8229
lappend ::nettool::blocks 8231 8242
lappend ::nettool::blocks 8244 8275
lappend ::nettool::blocks 8277 8279
lappend ::nettool::blocks 8281 8291
lappend ::nettool::blocks 8295 8299
lappend ::nettool::blocks 8302 8312
lappend ::nettool::blocks 8314 8319
lappend ::nettool::blocks 8322 8350
lappend ::nettool::blocks 8352 8375
lappend ::nettool::blocks 8381 8382
lappend ::nettool::blocks 8384 8399
lappend ::nettool::blocks 8406 8414
lappend ::nettool::blocks 8418 8441
lappend ::nettool::blocks 8446 8449
lappend ::nettool::blocks 8451 8456
lappend ::nettool::blocks 8458 8469
lappend ::nettool::blocks 8475 8499
lappend ::nettool::blocks 8503 8553
lappend ::nettool::blocks 8556 8566
lappend ::nettool::blocks 8568 8599
lappend ::nettool::blocks 8601 8608
lappend ::nettool::blocks 8616 8664
lappend ::nettool::blocks 8667 8674
lappend ::nettool::blocks 8676 8685
lappend ::nettool::blocks 8687 8687
lappend ::nettool::blocks 8689 8698
lappend ::nettool::blocks 8700 8710
lappend ::nettool::blocks 8712 8731
lappend ::nettool::blocks 8734 8749
lappend ::nettool::blocks 8751 8762
lappend ::nettool::blocks 8767 8769
lappend ::nettool::blocks 8771 8777
lappend ::nettool::blocks 8779 8785
lappend ::nettool::blocks 8788 8792
lappend ::nettool::blocks 8794 8799
lappend ::nettool::blocks 8801 8803
lappend ::nettool::blocks 8805 8872
lappend ::nettool::blocks 8874 8879
lappend ::nettool::blocks 8882 8882
lappend ::nettool::blocks 8884 8887
lappend ::nettool::blocks 8895 8898
lappend ::nettool::blocks 8902 8909
lappend ::nettool::blocks 8914 8936
lappend ::nettool::blocks 8938 8952
lappend ::nettool::blocks 8955 8988
lappend ::nettool::blocks 8992 8997
lappend ::nettool::blocks 9003 9006
lappend ::nettool::blocks 9011 9019
lappend ::nettool::blocks 9027 9049
lappend ::nettool::blocks 9052 9079
lappend ::nettool::blocks 9081 9081
lappend ::nettool::blocks 9094 9099
lappend ::nettool::blocks 9108 9118
lappend ::nettool::blocks 9120 9121
lappend ::nettool::blocks 9124 9130
lappend ::nettool::blocks 9132 9159
lappend ::nettool::blocks 9165 9190
lappend ::nettool::blocks 9192 9199
lappend ::nettool::blocks 9218 9221
lappend ::nettool::blocks 9223 9254
lappend ::nettool::blocks 9256 9276
lappend ::nettool::blocks 9288 9291
lappend ::nettool::blocks 9296 9299
lappend ::nettool::blocks 9301 9305
lappend ::nettool::blocks 9307 9311
lappend ::nettool::blocks 9313 9317
lappend ::nettool::blocks 9319 9320
lappend ::nettool::blocks 9322 9342
lappend ::nettool::blocks 9345 9345
lappend ::nettool::blocks 9347 9373
lappend ::nettool::blocks 9375 9379
lappend ::nettool::blocks 9381 9386
lappend ::nettool::blocks 9391 9395
lappend ::nettool::blocks 9398 9399
lappend ::nettool::blocks 9403 9417
lappend ::nettool::blocks 9419 9442
lappend ::nettool::blocks 9446 9449
lappend ::nettool::blocks 9451 9499
lappend ::nettool::blocks 9501 9521
lappend ::nettool::blocks 9523 9534
lappend ::nettool::blocks 9537 9554
lappend ::nettool::blocks 9556 9591
lappend ::nettool::blocks 9601 9611
lappend ::nettool::blocks 9613 9613
lappend ::nettool::blocks 9615 9615
lappend ::nettool::blocks 9619 9627
lappend ::nettool::blocks 9633 9639
lappend ::nettool::blocks 9641 9665
lappend ::nettool::blocks 9669 9693
lappend ::nettool::blocks 9696 9699
lappend ::nettool::blocks 9701 9746
lappend ::nettool::blocks 9748 9749
lappend ::nettool::blocks 9751 9752
lappend ::nettool::blocks 9754 9761
lappend ::nettool::blocks 9763 9799
lappend ::nettool::blocks 9803 9874
lappend ::nettool::blocks 9877 9877
lappend ::nettool::blocks 9879 9887
lappend ::nettool::blocks 9890 9897
lappend ::nettool::blocks 9904 9908
lappend ::nettool::blocks 9910 9910
lappend ::nettool::blocks 9912 9924
lappend ::nettool::blocks 9926 9949
lappend ::nettool::blocks 9957 9965
lappend ::nettool::blocks 9967 9977
lappend ::nettool::blocks 9979 9986
lappend ::nettool::blocks 9989 9989
lappend ::nettool::blocks 10003 10003
lappend ::nettool::blocks 10011 10022
lappend ::nettool::blocks 10024 10049
lappend ::nettool::blocks 10052 10054
lappend ::nettool::blocks 10056 10079
lappend ::nettool::blocks 10082 10099
lappend ::nettool::blocks 10105 10106
lappend ::nettool::blocks 10108 10109
lappend ::nettool::blocks 10112 10112
lappend ::nettool::blocks 10118 10127
lappend ::nettool::blocks 10130 10159
lappend ::nettool::blocks 10163 10199
lappend ::nettool::blocks 10202 10251
lappend ::nettool::blocks 10253 10259
lappend ::nettool::blocks 10261 10287
lappend ::nettool::blocks 10289 10320
lappend ::nettool::blocks 10322 10438
lappend ::nettool::blocks 10440 10499
lappend ::nettool::blocks 10501 10539
lappend ::nettool::blocks 10545 10630
lappend ::nettool::blocks 10632 10799
lappend ::nettool::blocks 10801 10804
lappend ::nettool::blocks 10806 10808
lappend ::nettool::blocks 10811 10859
lappend ::nettool::blocks 10861 10879
lappend ::nettool::blocks 10881 10989
lappend ::nettool::blocks 10991 10999
lappend ::nettool::blocks 11002 11094
lappend ::nettool::blocks 11096 11102
lappend ::nettool::blocks 11107 11107
lappend ::nettool::blocks 11113 11160
lappend ::nettool::blocks 11166 11170
lappend ::nettool::blocks 11176 11200
lappend ::nettool::blocks 11203 11207
lappend ::nettool::blocks 11209 11210
lappend ::nettool::blocks 11212 11318
lappend ::nettool::blocks 11322 11366
lappend ::nettool::blocks 11368 11370
lappend ::nettool::blocks 11372 11429
lappend ::nettool::blocks 11431 11488
lappend ::nettool::blocks 11490 11599
lappend ::nettool::blocks 11601 11622
lappend ::nettool::blocks 11624 11719
lappend ::nettool::blocks 11721 11722
lappend ::nettool::blocks 11724 11750
lappend ::nettool::blocks 11752 11795
lappend ::nettool::blocks 11797 11875
lappend ::nettool::blocks 11878 11966
lappend ::nettool::blocks 11968 11996
lappend ::nettool::blocks 12011 12011
lappend ::nettool::blocks 12014 12108
lappend ::nettool::blocks 12110 12120
lappend ::nettool::blocks 12122 12167
lappend ::nettool::blocks 12169 12171
lappend ::nettool::blocks 12173 12299
lappend ::nettool::blocks 12301 12301
lappend ::nettool::blocks 12303 12320
lappend ::nettool::blocks 12323 12344
lappend ::nettool::blocks 12346 12752
lappend ::nettool::blocks 12754 12864
lappend ::nettool::blocks 12866 13159
lappend ::nettool::blocks 13161 13215
lappend ::nettool::blocks 13219 13222
lappend ::nettool::blocks 13225 13399
lappend ::nettool::blocks 13401 13719
lappend ::nettool::blocks 13723 13723
lappend ::nettool::blocks 13725 13781
lappend ::nettool::blocks 13784 13784
lappend ::nettool::blocks 13787 13817
lappend ::nettool::blocks 13824 13893
lappend ::nettool::blocks 13895 13928
lappend ::nettool::blocks 13931 13999
lappend ::nettool::blocks 14003 14032
lappend ::nettool::blocks 14035 14140
lappend ::nettool::blocks 14143 14144
lappend ::nettool::blocks 14146 14148
lappend ::nettool::blocks 14151 14153
lappend ::nettool::blocks 14155 14249
lappend ::nettool::blocks 14251 14413
lappend ::nettool::blocks 14415 14935
lappend ::nettool::blocks 14938 14999
lappend ::nettool::blocks 15001 15001
lappend ::nettool::blocks 15003 15117
lappend ::nettool::blocks 15119 15344
lappend ::nettool::blocks 15346 15362
lappend ::nettool::blocks 15364 15554
lappend ::nettool::blocks 15556 15659
lappend ::nettool::blocks 15661 15739
lappend ::nettool::blocks 15741 15997
lappend ::nettool::blocks 16004 16019
lappend ::nettool::blocks 16022 16160
lappend ::nettool::blocks 16163 16308
lappend ::nettool::blocks 16312 16359
lappend ::nettool::blocks 16362 16366
lappend ::nettool::blocks 16369 16383
lappend ::nettool::blocks 16385 16618
lappend ::nettool::blocks 16620 16664
lappend ::nettool::blocks 16667 16899
lappend ::nettool::blocks 16901 16949
lappend ::nettool::blocks 16951 16990
lappend ::nettool::blocks 16996 17006
lappend ::nettool::blocks 17008 17183
lappend ::nettool::blocks 17186 17218
lappend ::nettool::blocks 17223 17233
lappend ::nettool::blocks 17236 17499
lappend ::nettool::blocks 17501 17554
lappend ::nettool::blocks 17556 17728
lappend ::nettool::blocks 17730 17753
lappend ::nettool::blocks 17757 17776
lappend ::nettool::blocks 17778 17999
lappend ::nettool::blocks 18001 18103
lappend ::nettool::blocks 18105 18135
lappend ::nettool::blocks 18137 18180
lappend ::nettool::blocks 18188 18240
lappend ::nettool::blocks 18244 18261
lappend ::nettool::blocks 18263 18462
lappend ::nettool::blocks 18464 18633
lappend ::nettool::blocks 18636 18768
lappend ::nettool::blocks 18770 18880
lappend ::nettool::blocks 18882 18887
lappend ::nettool::blocks 18889 18999
lappend ::nettool::blocks 19001 19006
lappend ::nettool::blocks 19008 19019
lappend ::nettool::blocks 19021 19190
lappend ::nettool::blocks 19192 19193
lappend ::nettool::blocks 19195 19282
lappend ::nettool::blocks 19284 19314
lappend ::nettool::blocks 19316 19397
lappend ::nettool::blocks 19399 19409
lappend ::nettool::blocks 19413 19538
lappend ::nettool::blocks 19542 19787
lappend ::nettool::blocks 19789 19997
lappend ::nettool::blocks 20004 20004
lappend ::nettool::blocks 20006 20011
lappend ::nettool::blocks 20015 20045
lappend ::nettool::blocks 20047 20047
lappend ::nettool::blocks 20050 20166
lappend ::nettool::blocks 20168 20201
lappend ::nettool::blocks 20203 20221
lappend ::nettool::blocks 20223 20479
lappend ::nettool::blocks 20481 20669
lappend ::nettool::blocks 20671 20998
lappend ::nettool::blocks 21001 21009
lappend ::nettool::blocks 21011 21552
lappend ::nettool::blocks 21555 21589
lappend ::nettool::blocks 21591 21799
lappend ::nettool::blocks 21801 21844
lappend ::nettool::blocks 21850 21999
lappend ::nettool::blocks 22006 22124
lappend ::nettool::blocks 22126 22127
lappend ::nettool::blocks 22129 22221
lappend ::nettool::blocks 22223 22272
lappend ::nettool::blocks 22274 22304
lappend ::nettool::blocks 22306 22342
lappend ::nettool::blocks 22344 22346
lappend ::nettool::blocks 22348 22349
lappend ::nettool::blocks 22352 22536
lappend ::nettool::blocks 22538 22554
lappend ::nettool::blocks 22556 22762
lappend ::nettool::blocks 22764 22799
lappend ::nettool::blocks 22801 22950
lappend ::nettool::blocks 22952 22999
lappend ::nettool::blocks 23006 23052
lappend ::nettool::blocks 23054 23271
lappend ::nettool::blocks 23273 23332
lappend ::nettool::blocks 23334 23399
lappend ::nettool::blocks 23403 23455
lappend ::nettool::blocks 23458 23545
lappend ::nettool::blocks 23547 23999
lappend ::nettool::blocks 24007 24241
lappend ::nettool::blocks 24243 24248
lappend ::nettool::blocks 24250 24320
lappend ::nettool::blocks 24323 24464
lappend ::nettool::blocks 24466 24553
lappend ::nettool::blocks 24555 24576
lappend ::nettool::blocks 24578 24675
lappend ::nettool::blocks 24679 24679
lappend ::nettool::blocks 24681 24753
lappend ::nettool::blocks 24755 24849
lappend ::nettool::blocks 24851 24921
lappend ::nettool::blocks 24923 24999
lappend ::nettool::blocks 25010 25470
lappend ::nettool::blocks 25472 25575
lappend ::nettool::blocks 25577 25603
lappend ::nettool::blocks 25605 25792
lappend ::nettool::blocks 25794 25899
lappend ::nettool::blocks 25904 25953
lappend ::nettool::blocks 25956 25999
lappend ::nettool::blocks 26001 26132
lappend ::nettool::blocks 26134 26207
lappend ::nettool::blocks 26209 26259
lappend ::nettool::blocks 26264 26485
lappend ::nettool::blocks 26488 26488
lappend ::nettool::blocks 26490 26999
lappend ::nettool::blocks 27010 27344
lappend ::nettool::blocks 27346 27441
lappend ::nettool::blocks 27443 27503
lappend ::nettool::blocks 27505 27781
lappend ::nettool::blocks 27783 27875
lappend ::nettool::blocks 27877 27998
lappend ::nettool::blocks 28002 28118
lappend ::nettool::blocks 28120 28199
lappend ::nettool::blocks 28201 28239
lappend ::nettool::blocks 28241 29117
lappend ::nettool::blocks 29119 29166
lappend ::nettool::blocks 29170 29998
lappend ::nettool::blocks 30005 30259
lappend ::nettool::blocks 30261 30831
lappend ::nettool::blocks 30833 30998
lappend ::nettool::blocks 31000 31019
lappend ::nettool::blocks 31021 31028
lappend ::nettool::blocks 31030 31399
lappend ::nettool::blocks 31401 31415
lappend ::nettool::blocks 31417 31456
lappend ::nettool::blocks 31458 31619
lappend ::nettool::blocks 31621 31684
lappend ::nettool::blocks 31686 31764
lappend ::nettool::blocks 31766 32033
lappend ::nettool::blocks 32035 32248
lappend ::nettool::blocks 32250 32482
lappend ::nettool::blocks 32484 32634
lappend ::nettool::blocks 32637 32766
lappend ::nettool::blocks 32778 32800
lappend ::nettool::blocks 32802 32810
lappend ::nettool::blocks 32812 32895
lappend ::nettool::blocks 32897 33122
lappend ::nettool::blocks 33124 33330
lappend ::nettool::blocks 33332 33332
lappend ::nettool::blocks 33335 33433
lappend ::nettool::blocks 33435 33655
lappend ::nettool::blocks 33657 34248
lappend ::nettool::blocks 34250 34377
lappend ::nettool::blocks 34380 34566
lappend ::nettool::blocks 34568 34961
lappend ::nettool::blocks 34965 34979
lappend ::nettool::blocks 34981 34999
lappend ::nettool::blocks 35007 35353
lappend ::nettool::blocks 35358 36000
lappend ::nettool::blocks 36002 36411
lappend ::nettool::blocks 36413 36421
lappend ::nettool::blocks 36423 36442
lappend ::nettool::blocks 36445 36523
lappend ::nettool::blocks 36525 36601
lappend ::nettool::blocks 36603 36699
lappend ::nettool::blocks 36701 36864
lappend ::nettool::blocks 36866 37474
lappend ::nettool::blocks 37476 37482
lappend ::nettool::blocks 37484 37653
lappend ::nettool::blocks 37655 37999
lappend ::nettool::blocks 38002 38200
lappend ::nettool::blocks 38204 38799
lappend ::nettool::blocks 38801 38864
lappend ::nettool::blocks 38866 39680
lappend ::nettool::blocks 39682 39999
lappend ::nettool::blocks 40001 40403
lappend ::nettool::blocks 40405 40840
lappend ::nettool::blocks 40844 40852
lappend ::nettool::blocks 40854 41110
lappend ::nettool::blocks 41112 41120
lappend ::nettool::blocks 41122 41793
lappend ::nettool::blocks 41798 42507
lappend ::nettool::blocks 42511 42999
lappend ::nettool::blocks 43001 44320
lappend ::nettool::blocks 44323 44443
lappend ::nettool::blocks 44445 44543
lappend ::nettool::blocks 44545 44552
lappend ::nettool::blocks 44554 44599
lappend ::nettool::blocks 44601 44899
lappend ::nettool::blocks 44901 44999
lappend ::nettool::blocks 45002 45044
lappend ::nettool::blocks 45046 45053
lappend ::nettool::blocks 45055 45677
lappend ::nettool::blocks 45679 45823
lappend ::nettool::blocks 45826 45965
lappend ::nettool::blocks 45967 46997
lappend ::nettool::blocks 47002 47099
lappend ::nettool::blocks 47101 47556
lappend ::nettool::blocks 47558 47623
lappend ::nettool::blocks 47625 47805
lappend ::nettool::blocks 47807 47807
lappend ::nettool::blocks 47810 47999
lappend ::nettool::blocks 48006 48048
lappend ::nettool::blocks 48051 48127
lappend ::nettool::blocks 48130 48555
lappend ::nettool::blocks 48557 48618
lappend ::nettool::blocks 48620 48652
lappend ::nettool::blocks 48654 48999
lappend ::nettool::blocks 49001 65535


###
# END: available_ports.tcl
###
###
# START: locateport.tcl
###
::namespace eval ::nettool {}

###
# topic: fc6f8b9587dd5524f143f9df4be4755b63eb6cd5
###
proc ::nettool::allocate_port startingport {
  foreach {start end} $::nettool::blocks {
    if { $end <= $startingport } continue
    if { $start > $startingport } {
      set i $start
    } else {
      set i $startingport
    }
    for {} {$i <= $end} {incr i} {
      if {[string is true -strict [get ::nettool::used_ports($i)]]} continue
      if {[catch {socket -server NOOP $i} chan]} continue
      close $chan
      set ::nettool::used_ports($i) 1
      return $i
    }
  }
  error "Could not locate a port"
}

###
# topic: 3286fdbd0a3fdebbb26414475754bcf3dea67b0f
###
proc ::nettool::claim_port {port {protocol tcp}} {
  set ::nettool::used_ports($port) 1
}

###
# topic: 1d1f8a65a9aef8765c9b4f2b0ee0ebaf42e99d46
###
proc ::nettool::find_port startingport {
  foreach {start end} $::nettool::blocks {
    if { $end <= $startingport } continue
    if { $start > $startingport } {
      set i $start
    } else {
      set i $startingport
    }
    for {} {$i <= $end} {incr i} {
      if {[string is true -strict [get ::nettool::used_ports($i)]]} continue
      return $i
    }
  }
  error "Could not locate a port"
}

###
# topic: ded1c51260e009effb1f77044f8d0dec3d030b91
###
proc ::nettool::port_busy port {
  ###
  # Check our private list of used ports
  ###
  if {[string is true -strict [get ::nettool::used_ports($port)]]} {
    return 1
  }
  foreach {start end} $::nettool::blocks {
    if { $port >= $start && $port <= $end } {
      return 0
    }
  }
  return 1
}

###
# topic: b5407b084aa09f9efa4f58a337af6186418fddf2
###
proc ::nettool::release_port {port {protocol tcp}} {
  set ::nettool::used_ports($port) 0
}


###
# END: locateport.tcl
###
###
# START: platform_unix.tcl
###
###
# Generic answers that can be answered on most if not all unix platforms
###

if {$::tcl_platform(platform) eq "unix"} {
###
# topic: 825cd25953c2cc896a96006b7f454e00
# title: Return pairings of MAC numbers to IP addresses on the local network
# description: Under unix, we call the arp command for arp table resolution
###
proc ::nettool::arp_table {} {
  set result {}
  set dat [exec arp -a]
  foreach line [split $dat \n] {
    set host [lindex $line 0]
    set ip [lindex $line 1]
    set macid [lindex $line 3]
    lappend result $macid [string range $ip 1 end-1]
  }
  return $result
}
}

###
# END: platform_unix.tcl
###
###
# START: platform_unix_linux.tcl
###
if {$::tcl_platform(platform) eq "unix" && $genus eq "linux"} {

###
# topic: 92ebbfa155883ad41c37d3f843392be4
# title: Return list of broadcast addresses for local networks
###
proc ::nettool::broadcast_list {} {
  set result {}
  lappend result 127.0.0.1
  foreach {iface info} [dump] {
    if {[dict exists $info ipv4 Bcast:]} {
      lappend result [dict get $info ipv4 Bcast:]
    }
  }
  return [lsort -unique -dictionary $result]
}

###
# topic: 187cfa1827097c5cdf1c40c656cedfcc
# description: Return time since booted
###
proc ::nettool::cpuinfo args {
  variable cpuinfo
  if {![info exists cpuinfo]} {
    set cpuinfo {}
    set dat [cat /proc/meminfo]
    foreach line [split $dat \n] {
      switch [lindex $line 0] {
        MemTotal: {
          # Normalize to MB
          dict set cpuinfo memory [lindex $line 1]/1024
        }
      }
    }
    set cpus 0
    set dat [cat /proc/cpuinfo]
    foreach line [split $dat \n] {
      set idx [string first : $line]
      set field [string trim [string range $line 0 $idx-1]]
      set value [string trim [string range $line $idx+1 end]]
      switch $field {
        processor {
          incr cpus
        }
        {cpu family} {
          dict set cpuinfo family $value
        }
        model {
          dict set cpuinfo model $value
        }
        stepping {
          dict set cpuinfo stepping $value
        }
        vendor_id {
          dict set cpuinfo vendor $value
        }
        {model name} {
          dict set cpuinfo brand $value
        }
        {cpu MHz} {
          dict set cpuinfo speed $value
        }
        flags {
          dict set cpuinfo features $value
        }
      }
    }
    dict set cpuinfo cpus $cpus
  }
  if {$args eq "<list>"} {
    return [dict keys $cpuinfo]
  }
  if {[llength $args]==0} {
    return $cpuinfo
  }
  if {[llength $args]==1} {
    return [dict get $cpuinfo [lindex $args 0]]
  }
  set result {}
  foreach item $args {
    if {[dict exists $cpuinfo $item]} {
      dict set result $item [dict get $cpuinfo $item]
    } else {
      dict set result $item {}
    }
  }
  return $result
}

###
# topic: aa8eda4fb59296a1a34d8d600ca54e28
# description: Dump interfaces
###
proc ::nettool::dump {} {
  set data [exec ifconfig]
  set iface {}
  set result {}
  foreach line [split $data \n] {
    if {[string index $line 0] in {" " "\t"} } {
      # Indented line appends the prior iface
      switch [lindex $line 0] {
        inet {
          foreach tuple [lrange $line 1 end] {
	    set idx [string first : $tuple]
            set field [string trim [string range $tuple 0 $idx]]
            set value [string trim [string range $tuple $idx+1 end]]
            dict set result $iface ipv4 [string trim $field] [string trim $value]
          }
        }
        inet6 {
          dict set result $iface ipv6 addr: [lindex $line 2]
          foreach tuple [lrange $line 3 end] {
	    set idx [string first : $tuple]
            set field [string trim [string range $tuple 0 $idx]]
            set value [string trim [string range $tuple $idx+1 end]]
            dict set result $iface ipv6 [string trim $field] [string trim $value]
          }
	}
      }
    } else {
      # Non-intended line - new iface
      set iface [lindex $line 0]
      set idx [lsearch $line HWaddr]
      if {$idx >= 0 } {
        dict set result $iface ether: [lindex $line $idx+1]
      }
    }
  }
  return $result
}

###
# topic: 417672d3f31b80d749588365af88baf6
# title: Return list of ip addresses for this computer (primary first)
###
proc ::nettool::ip_list {} {
  set result {}
  foreach {iface info} [dump] {
    if {[dict exists $info ipv4 addr:]} {
      lappend result [dict get $info ipv4 addr:]
    }
  }
  ldelete result 127.0.0.1
  return $result
}

###
# topic: ac9d6815d47f60d45930f0c8c8ae8f16
# title: Return list of mac numbers for this computer (primary first)
###
proc ::nettool::mac_list {} {
  set result {}
  foreach {iface info} [dump] {
    if {[dict exists $info ether:]} {
      lappend result [dict get $info ether:]
    }
  }
  return $result
}

###
# topic: a43b6f42141820e0ba1094840d0f6fc0
###
proc ::nettool::network_list {} {
  foreach {iface info} [dump] {
    if {![dict exists $info ipv4 addr:]} continue
    if {![dict exists $info ipv4 Mask:]} continue
    #set mask [::ip::maskToInt $netmask]
    set addr [dict get $info ipv4 addr:]
    set mask [dict get $info ipv4 Mask:]
    set addri [::ip::toInteger $addr]
    lappend result [ip::nativeToPrefix [list [expr {$addri & $mask}] $mask] -ipv4]
  }
  return $result
}

###
# topic: e7db1ae1b5b98a1bb4384f0a4fe81f42
###
proc ::nettool::status {} {
  set result {}
  set dat [cat /proc/loadavg]
  dict set result load_average    [lrange $dat 0 2]
  set cpus [cpuinfo cpus].0
  dict set result load [expr {[lindex $dat 0]/$cpus}]

  set processes [split [lindex $dat 3] /]
  dict set result processes_running [lindex $processes 0]
  dict set result processes_total [lindex $processes 1]

  set dat [cat /proc/meminfo]
  foreach line [split $dat \n] {
    switch [lindex $line 0] {
      MemTotal: {
        # Normalize to MB
        dict set result memory_total [expr {[lindex $line 1]/1024}]
      }
      MemFree: {
        # Normalize to MB
        dict set result memory_free [expr {[lindex $line 1]/1024}]
      }
    }
  }
  return $result
}

###
# topic: 59bf977ad7287b4d90346fad639aed34
###
proc ::nettool::uptime_report {} {
  set result {}
  set dat [split [exec uptime] ,]
  puts $dat
  dict set result time   [lindex [lindex $dat 0] 0]
  dict set result uptime [lrange [lindex $dat 0] 1 end]
  dict set result users  [lindex [lindex $dat 2] 0]
  dict set result load_1_minute  [lindex [lindex $dat 3] end]
  dict set result load_5_minute  [lindex [lindex $dat 4] end]
  dict set result load_15_minute  [lindex [lindex $dat 5] end]
  return $result
}

unset -nocomplain ::nettool::cpuinfo
}

###
# END: platform_unix_linux.tcl
###
###
# START: platform_unix_macosx.tcl
###
if {$::tcl_platform(platform) eq "unix" && $genus eq "macosx"} {

###
# topic: 825cd25953c2cc896a96006b7f454e00
# title: Return pairings of MAC numbers to IP addresses on the local network
# description: Under macosx, we call the arp command for arp table resolution
###
proc ::nettool::arp_table {} {
  set result {}
  set dat [exec arp -a]
  foreach line [split $dat \n] {
    set host [lindex $line 0]
    set ip [lindex $line 1]
    set macid [lindex $line 3]
    lappend result $macid [string range $ip 1 end-1]
  }
  return $result
}

###
# topic: 92ebbfa155883ad41c37d3f843392be4
# title: Return list of broadcast addresses for local networks
###
proc ::nettool::broadcast_list {} {
  set result {}
  lappend result 127.0.0.1
  foreach {iface info} [dump] {
    if {[dict exists $info broadcast:]} {
      lappend result [dict get $info broadcast:]
    }
  }
  return [lsort -unique -dictionary $result]
}

###
# topic: 187cfa1827097c5cdf1c40c656cedfcc
# description: Return time since booted
###
proc ::nettool::cpuinfo args {
  variable cpuinfo
  if {![info exists cpuinfo]} {
    set cpuinfo {}
    dict set cpuinfo machine  [exec sysctl -n hw.machine]
    dict set cpuinfo cpus     [exec sysctl -n hw.ncpu]
    # Normalize to MB
    dict set cpuinfo memory   [expr {[exec sysctl -n hw.memsize] / 1048576}]

    dict set cpuinfo vendor   [exec sysctl -n machdep.cpu.vendor]
    dict set cpuinfo brand    [exec sysctl -n machdep.cpu.brand_string]

    dict set cpuinfo model    [exec sysctl -n machdep.cpu.model]
    dict set cpuinfo speed    [expr {[exec sysctl -n hw.cpufrequency]/1000000}]

    dict set cpuinfo family   [exec sysctl -n machdep.cpu.family]
    dict set cpuinfo stepping [exec sysctl -n machdep.cpu.stepping]
    dict set cpuinfo features [exec sysctl -n machdep.cpu.features]
    dict set cpuinfo diskless []
  }
  if {$args eq "<list>"} {
    return [dict keys $cpuinfo]
  }
  if {[llength $args]==0} {
    return $cpuinfo
  }
  if {[llength $args]==1} {
    return [dict get $cpuinfo [lindex $args 0]]
  }
  set result {}
  foreach item $args {
    if {[dict exists $cpuinfo $item]} {
      dict set result $item [dict get $cpuinfo $item]
    } else {
      dict set result $item {}
    }
  }
  return $result
}

###
# topic: aa8eda4fb59296a1a34d8d600ca54e28
# description: Dump interfaces
###
proc ::nettool::dump {} {
  set data [exec ifconfig]
  set iface {}
  set result {}
  foreach line [split $data \n] {
    if {[string index $line 0] in {" " "\t"} } {
      # Indented line appends the prior iface
      foreach {field value} $line {
        dict set result $iface [string trimright $field :]: $value
      }
    } else {
      # Non-intended line - new iface
      set iface [lindex $line 0]
    }
  }
  return $result
}

###
# topic: dd2e2c0810cea69909399808f2a68949
# title: Return a list of unique hardware addresses
###
proc ::nettool::hwid_list {} {
  variable cached_data
  set result {}
  if {![info exists cached_data]} {
    if {[catch {exec system_profiler SPHardwareDataType} hwlist]} {
      set cached_data {}
    } else {
      set cached_data $hwlist

    }
  }
  set serial {}
  set hwuuid {}
  set result {}
  catch {
  foreach line [split $cached_data \n] {
    if { [lindex $line 0] == "Serial" && [lindex $line 1] == "Number" } {
      set serial [lindex $line end]
    }
    if { [lindex $line 0] == "Hardware" && [lindex $line 1] == "UUID:" } {
      set hwuuid [lindex $line end]
    }
  }
  }
  if { $hwuuid != {} } {
    lappend result 0x[string map {- {}} $hwuuid]
  }
  # Blank serial number?
  if { $serial != {} } {
    set sn [binary scan $serial H* hash]
    lappend result 0x$hash
  }
  if {[llength $result]} {
    return $result
  }
  foreach mac [::nettool::mac_list] {
    lappend result 0x[string map {: {}} $mac]
  }
  if {[llength $result]} {
    return $result
  }
  return 0x010203040506
}

###
# topic: d2932eb0ea8cc9f6a865c1ab7cdd4572
# description:
#    Called on package load to build any static
#    structures to cache data that would be time
#    consuming to call on the fly
###
proc ::nettool::init {} {
  unset -nocomplain [namespace current]::cpuinfo

}

###
# topic: 417672d3f31b80d749588365af88baf6
# title: Return list of ip addresses for this computer (primary first)
###
proc ::nettool::ip_list {} {
  set result {}
  foreach {iface info} [dump] {
    if {[dict exists $info inet:]} {
      lappend result [dict get $info inet:]
    }
  }
  ldelete result 127.0.0.1
  return $result
}

###
# topic: ac9d6815d47f60d45930f0c8c8ae8f16
# title: Return list of mac numbers for this computer (primary first)
###
proc ::nettool::mac_list {} {
  set result {}
  foreach {iface info} [dump] {
    if {[dict exists $info ether:]} {
      lappend result [dict get $info ether:]
    }
  }
  return $result
}

###
# topic: a43b6f42141820e0ba1094840d0f6fc0
###
proc ::nettool::network_list {} {
  foreach {iface info} [dump] {
    if {![dict exists $info inet:]} continue
    if {![dict exists $info netmask:]} continue
    #set mask [::ip::maskToInt $netmask]
    set addr [dict get $info inet:]
    set mask [dict get $info netmask:]
    set addri [::ip::toInteger $addr]
    lappend result [ip::nativeToPrefix [list [expr {$addri & $mask}] $mask] -ipv4]
  }
  return $result
}

###
# topic: e7db1ae1b5b98a1bb4384f0a4fe81f42
###
proc ::nettool::status {} {
  set result {}
  set loaddat [lindex [exec sysctl -n vm.loadavg] 0]
  set cpus [cpuinfo cpus]
  dict set result cpus $cpus
  dict set result load [expr {[lindex $loaddat 0]*100.0/$cpus}]
  dict set result load_average_1 [lindex $loaddat 0]
  dict set result load_average_5 [lindex $loaddat 1]
  dict set result load_average_15 [lindex $loaddat 2]

  set total [exec sysctl -n hw.memsize]
  dict set result memory_total [expr {$total / 1048576}]
  set used 0
  foreach {amt} [exec sysctl -n machdep.memmap] {
    incr used $amt
  }
  dict set result memory_free [expr {($total - $used) / 1048576}]

  return $result
}

proc ::nettool::user_data_root {appname} {
  return [file join $::env(HOME) Library {Application Support} $appname]
}
}

###
# END: platform_unix_macosx.tcl
###
###
# START: platform_windows.tcl
###
if {$::tcl_platform(platform) eq "windows"} {

###
# topic: dd2e2c0810cea69909399808f2a68949
# title: Return a list of unique hardware ids
###
proc ::nettool::hwid_list {} {
  # Use the serial number on the hard drive
  catch {exec {*}[auto_execok vol] c:} voldat
  set num [lindex [lindex [split $voldat \n] end] end]
  return 0x[string map {- {}} $num]
}

###
# topic: 92ebbfa155883ad41c37d3f843392be4
# title: Return list of broadcast addresses for local networks
###
proc ::nettool::broadcast_list {} {
  set result {}
  lappend result 127.0.0.1
  foreach net [network_list] {
    if {$net in {224.0.0.0/4 127.0.0.0/8}} continue
    lappend result [::ip::broadcastAddress $net]
  }
  return [lsort -unique -dictionary $result]
}

###
# Provide a limited subset using data gleaned from exec
# These calls work in Windows NT 4 and above
###


proc ::nettool::IPINFO {} {
  if {![info exists ::nettool::ipinfo]} {
    set ::nettool::ipinfo [exec ipconfig /all]
  }
  return $::nettool::ipinfo
}

proc ::nettool::if_list {} {
  return [mac_list]
}

proc ::nettool::ip_list {} {
  set result {}
  foreach line [split [IPINFO] \n] {
    if {![regexp {IPv4 Address} $line]} continue
    set line [string range $line [string first ":" $line]+2 end]
    if {[scan $line %d.%d.%d.%d A B C D]!=4} continue
    lappend result $A.$B.$C.$D
  }
  return $result
}

proc ::nettool::mac_list {} {
  set result {}
  foreach line [split [IPINFO] \n] {
    if {![regexp {Physical Address} $line]} continue
    set line [string range $line [string first ":" $line]+2 end]
    if {[scan $line %02x-%02x-%02x-%02x-%02x-%02x A B C D E F] != 6} continue
    if {$A==0 && $B==0 && $C==0 && $D==0 && $E==0 && $F==0} continue
    lappend result [format %02x:%02x:%02x:%02x:%02x:%02x $A $B $C $D $E $F]
  }
  return $result
}

proc ::nettool::network_list {} {
  set masks {}
  foreach line [split [IPINFO] \n] {
    if {![regexp {Subnet Mask} $line]} continue
    set line [string range $line [string first ":" $line]+2 end]
    if {[scan $line %d.%d.%d.%d A B C D]!=4} continue
    lappend masks $A.$B.$C.$D
  }
  set result {}
  set idx -1
  foreach addr [ip_list] {
    set netmask [lindex $masks [incr idx]]
    set mask   [::ip::maskToInt $netmask]
    set addri [::ip::toInteger $addr]
    lappend result [ip::nativeToPrefix [list [expr {$addri & $mask}] $netmask] -ipv4]
  }
  return $result
}

proc ::nettool::status {} {
}

proc ::nettool::user_data_root {appname} {
  return [file join $::env(APPDATA) $appname]
}
}

###
# END: platform_windows.tcl
###
###
# START: platform_windows_twapi.tcl
###
if {$::tcl_platform(platform) eq "windows" && ![catch {package require twapi}]} {
# TWAPI Based implementation

::namespace eval ::nettool {}

###
# topic: 825cd25953c2cc896a96006b7f454e00
# title: Return pairings of MAC numbers to IP addresses on the local network
# description: Under macosx, we call the arp command for arp table resolution
###
proc ::nettool::arp_table {} {
  set result {}
  catch {
  foreach element [::twapi::get_arp_table] {
    foreach {ifidx macid ipaddr type} {
      lappend result [string map {- :} $macid] $ipaddr
    }
  }
  }
  return $result
}


###
# topic: 57fdc331bc60c7bf2bd3f3214e9a906f
###
proc ::nettool::hwaddr_to_ipaddr args {
  return [::twapi::hwaddr_to_ipaddr {*}$args]
}



if {[info command ::twapi::get_netif_indices] ne {}} {
###
# topic: 4b87d977492bd10802bfc0327cd07ac2
# title: Return list of network interfaces
###
proc ::nettool::if_list {} {
  return [::twapi::get_netif_indices]
}


###
# topic: ac9d6815d47f60d45930f0c8c8ae8f16
# title: Return list of mac numbers for this computer (primary first)
###
proc ::nettool::mac_list {} {
  set result {}
  foreach iface [::twapi::get_netif_indices] {
    foreach {field value} [::twapi::get_netif_info $iface -physicaladdress] {
      if { $value eq {} } continue
      lappend result [string map {- :} $value]
    }
  }
  return $result
}

###
# topic: a43b6f42141820e0ba1094840d0f6fc0
###
proc ::nettool::network_list {} {
  set result {}
  foreach iface [::twapi::get_netif_indices] {
    set dat [::twapi::GetIpAddrTable $iface]
    foreach element $dat {
      foreach {addr ifindx netmask broadcast reamsize} $element break;
      set mask [::ip::maskToInt $netmask]
      set addri [::ip::toInteger $addr]
      lappend result [ip::nativeToPrefix [list [expr {$addri & $mask}] $netmask] -ipv4]
    }
  }
  return [lsort -unique $result]
}
} else {

if {[info commands ::twapi::get_network_adapters] ne {}} {
proc ::nettool::if_list {} {
  return [::twapi::get_network_adapters]
}
}

if {[info commands ::twapi::get_network_adapter_info] ne {}} {
proc ::nettool::mac_list {} {

  set result {}
  foreach iface [if_list] {
    set dat [::twapi::get_network_adapter_info $iface -physicaladdress]
    set addr [string map {- :} [lindex $dat 1]]
    if {[string length $addr] eq 0} continue
    if {[string range $addr 0 5] eq "00:00:"} continue
    lappend result $addr
  }
  return $result
}

proc ::nettool::network_list {} {
  set result {}
  foreach iface [if_list] {
    set dat [::twapi::get_network_adapter_info $iface -prefixes]
    foreach kvlist [lindex $dat 1] {
      if {![dict exists $kvlist -address]} continue
      if {![dict exists $kvlist -prefixlength]} continue
      set length [dict get $kvlist -prefixlength]
      if {$length>31} continue
      set address [dict get $kvlist -address]
      if {[string range $address 0 1] eq "ff"} continue
      lappend result $address/$length
    }
  }
  return [lsort -unique $result]
}

}
}

###
# topic: 417672d3f31b80d749588365af88baf6
# title: Return list of ip addresses for this computer (primary first)
###
set body {}
if {[info commands ::twapi::get_ip_addresses] ne {}} {
proc ::nettool::ip_list {} {
  set result [::twapi::get_ip_addresses]
  ldelete result 127.0.0.1
  return $result
}
} elseif {[info commands ::twapi::get_system_ipaddrs] ne {}} {
# They changed commands names on me...
if {[catch {::twapi::get_system_ipaddrs -version 4}]} {
# THEY CHANGED THE API ON ME!
proc ::nettool::ip_list {} {
  set result [::twapi::get_system_ipaddrs -ipversion 4]
  ldelete result 127.0.0.1
  return $result
}
} else {
proc ::nettool::ip_list {} {
  set result [::twapi::get_system_ipaddrs -version 4]
  ldelete result 127.0.0.1
  return $result
}
}
}


proc ::nettool::status {} {
  set result {}
  #dict set result load [::twapi::]
  set cpus [::twapi::get_processor_count]
  set usage 0
  for {set p 0} {$p < $cpus} {incr p} {
    if [catch {
    set pu  [lindex [::twapi::get_processor_info $p  -processorutilization] 1]
    while {$pu eq {}} {
      after 100 {set pause 0}
      vwait pause
      set pu  [lindex [::twapi::get_processor_info $p  -processorutilization] 1]
    }
    set usage [expr {$usage+$pu}]
    } err] {
      set usage -1
    }
  }
  dict set result cpus $cpus
  dict set result load [expr {$usage/$cpus}]
  dict set result uptime [::twapi::get_system_uptime]
}
}

###
# END: platform_windows_twapi.tcl
###

namespace eval ::nettool {
    namespace export *
}
###
# Perform any one-time discovery we might need
###
::nettool::discover
::nettool::init

