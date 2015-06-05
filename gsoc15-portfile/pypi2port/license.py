#! /bin/sh
""":"
exec python $0 ${1+"$@"}
"""

import argparse
import sys
import os
import urllib2
import hashlib
import zipfile
from progressbar import *
try:
    import xmlrpclib
except ImportError:
    import xmlrpc.client as xmlrpclib
import textwrap
import string
import shutil
import re
import csv
#import pdb
#from datetime import datetime

#startTime = datetime.now()
client = xmlrpclib.ServerProxy('http://pypi.python.org/pypi')

list_packages = client.list_packages()
count = 0
if len(sys.argv) > 1:
    end = int(sys.argv[1])
else:
    end = 5000

with open('license_list.csv', 'wb') as csvfile:
    licensewriter = csv.writer(csvfile, delimiter=',',
                                quotechar='"', quoting=csv.QUOTE_MINIMAL)
    licensewriter.writerow(['license', 'license_mapped', 'package'])
    for package_name in list_packages:
        license_mapped = ''
        vers = client.package_releases(package_name)
        if vers:
            data = client.release_data(package_name,vers[0])
            if data:
    #            pdb.set_trace()
                license = data['license']
                try:
                    license = license.decode('utf-8','ignore')
                    license = license.encode('utf-8','ignore')
                except:
                    license = 'UNMAPPED-ENCODE-ERROR'
                license = filter(lambda x: x in string.printable, license)
                license = re.sub(r'[\[\]\{\}\;\:\$\t\"\'\`\=(--)]+', ' ', license)
                license = re.sub(r'\s(\s)+', ' ', license)
                license = re.sub(r'([A-Z]*)([a-z]*)([\s]*v*)([0-9]\.*[0-9]*)',
                                 r'\1\2-\4', license)
                license = re.sub(r'v(-*)([0-9])', r'\1\2', license)
                if re.search('.*MIT.*', license):
                    license_mapped = license_mapped+' MIT'
                if re.search('.*apache.*2.*', license):
                    license_mapped = license_mapped+' Apache-2'
                if re.search('.*GPL.?3.*', license):
                    license_mapped = license_mapped+' GPL-3'
                if license.count('\n') > 0 or license.count('\r') > 0:
                    license = 'UNMAPPED-MULTI-LINE'
            else:
                license = 'UNMAPPED-NO-DATA'
        else:
            license = 'UNMAPPED-NO-VERSIONS'
        print license,',',license_mapped,',',package_name
        licensewriter.writerow([license, license_mapped, package_name])
        count = count + 1
        if count == end:
            break;


#print "TIME TAKEN =",datetime.now()-startTime
