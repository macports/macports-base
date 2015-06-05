"""
Copyright (c) 2015, Gaurav Bansal
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer 
in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT 
NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""

#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
import sys
import os
import hashlib
import zipfile
import requests
try:
	import xmlrpclib
except ImportError:
	import xmlrpc.client as xmlrpclib
import textwrap
import string
import shutil
import re
import difflib
import subprocess
import time


client = xmlrpclib.ServerProxy('http://pypi.python.org/pypi')


def list_all():
	""" Lists all packages available in pypi database """
	list_packages = client.list_packages()
	for package in list_packages:
		print(package)


class Package_Search:
	def __init__(self, name, summary, version):
		self.name = name
		self.version = version
		self.summary = ""
		for i in range(0, len(summary), 62):
			self.summary += summary[i:62+i] + '\n\t\t'

	def __str__(self):
		return "Name\t\t" + self.name + "\nVersion\t\t" + self.version + "\nSummary\t\t" + self.summary + "\n"
		

def search(pkg_name):
	""" Searches for a particular package by the name classifier """
	values = client.search({'name': pkg_name})
	for value in values:
		package = Package_Search(value['name'], value['summary'], value['version'])
		print(package)

class Package_release_data:
	def __init__(self, attributes):
		variables = list(attributes.keys())
		for v in variables:
			setattr(self, v, attributes[v])

	def __str__(self):
		output = "Name\t\t" + self.name + "\nVersion\t\t" + self.version
		if self.maintainer and self.maintainer != 'UNKNOWN':
			output += "\nMaintainter\t" + self.maintainer
		output += "\nHome_page\t" + self.home_page
		output += "\nPackage_url\t" + self.package_url
		if self.download_url and self.download_url != 'UNKNOWN':
			output += "\nDownload_url\t" + self.download_url
		output += "\nRelease_url\t" + self.release_url
		if self.docs_url and self.docs_url != 'UNKNOWN':
			output += "\nDocs_url\t" + self.docs_url
		output += "\nDescription\t" + self.description
		return output

def release_data(pkg_name, pkg_version):
	""" Fetches the release data for a paticular package based on
	the package_name and package_version """
	values = client.release_data(pkg_name, pkg_version)
	if values:
		package = Package_release_data(values)
		print(package)
	else:
		print("No such package found.")
		print("Please specify the exact package name.")
	return


def fetch(pkg_name, dict):
	""" Fetches the distfile for a particular package name and release_url """
	print("Fetching distfiles...")
	checksum_md5 = dict['md5_digest']
	parent_dir = './sources'
	home_dir = parent_dir + '/' + 'python'
	src_dir = home_dir + '/py-' + pkg_name
	if not os.path.exists(parent_dir):
		os.makedirs(parent_dir)
	if not os.path.exists(home_dir):
		os.makedirs(home_dir)
	if not os.path.exists(src_dir):
		os.makedirs(src_dir)

	url = dict['url']
	file_name = src_dir + '/' + dict['filename']

	r = requests.get(url)
	if r.status_code == 200	:
		with open(file_name, 'wb') as f:
			meta = r.headers['content-length']
			file_size = int(meta)

			pattern = ["-","\\", "|", "/"]
			patternIndex = 0
			file_size_dl = 0
			block_sz = 1024
			# toolbar_width = int(file_size/block_sz)+1
			toolbar_width = 30
			# sys.stdout.write("["+"-"*int(file_size_dl/block_sz)+pattern[patternIndex]+" "*int((file_size-file_size_dl)/block_sz-1)+"] "+" "+"(%5d Kb of %5d Kb)"% (file_size_dl, file_size))
			print file_size
			incr = int(file_size/50)
			print incr
			count = 0
			left = 49
			sys.stdout.write("["+"-"*int(count)+pattern[patternIndex]+" "*int(left)+"]"+"(%5d Kb of %5d Kb)"% (file_size_dl, file_size))
			sys.stdout.flush()
			buff = 0
			for chunk in r.iter_content(block_sz):
				if file_size_dl+block_sz > file_size:
					file_size_dl = file_size
					count += 1
					left -= 1						
					sys.stdout.write("\r")
					sys.stdout.write("["+"-"*int(count+1)+"]"+"(%5d Kb of %5d Kb)"% (file_size_dl, file_size))
					time.sleep(0.1)
					sys.stdout.flush()
					buff = 0
					patternIndex = (patternIndex + 1)%4
				else:
					file_size_dl += block_sz
				buff += block_sz
				if(buff >= incr):
					count += 1
					left -= 1						
					sys.stdout.write("\r")
					time.sleep(0.1)
					sys.stdout.flush()
					buff = 0
					patternIndex = (patternIndex + 1)%4
				patternIndex = (patternIndex + 1)%4
				sys.stdout.write("\r")
				if(file_size_dl+block_sz >= file_size):
						sys.stdout.write("["+"-"*int(count+1)+"]"+"(%5d Kb of %5d Kb)"% (file_size_dl, file_size))
				else:
					sys.stdout.write("["+"-"*int(count)+pattern[patternIndex]+" "*int(left)+"]"+"(%5d Kb of %5d Kb)"% (file_size_dl, file_size))
		sys.stdout.write(" OK\n")
		sys.stdout.flush()

	checksum_md5_calc = hashlib.md5(open(file_name,'rb').read()).hexdigest()

	if str(checksum_md5) == str(checksum_md5_calc):
		print('Successfully fetched')
		ext = file_name.split('.')[-1]
		if ext == 'egg':
			zip = zipfile.ZipFile(file_name)
			for name in zip.namelist():
				if name.split("/")[0] == "EGG-INFO":
					zip.extract(name, src_dir)
		return file_name
	else:
		print('Aborting due to inconsistency on checksums\n')
		try:
			os.remove(file_name)
		except OSError as e:
			print(("Error: {0} - {1}.".format(e.filename, e.strerror)))
		return False


def fetch_url(pkg_name, pkg_version, checksum=False, deps=False):
	""" Checks for the checksums and dependecies for a particular python package
	on the basis of package_name and package_version """
	values = client.release_urls(pkg_name, pkg_version)
	if checksum:
		for value in values:
			if value['filename'].split('.')[-1] in ('gz', 'zip'):
				return fetch(pkg_name, value)
	else:
		for value in values:
			return fetch(pkg_name, value)


def dependencies(pkg_name, pkg_version, deps=False):
	""" Finds dependencies for a particular package on the basis of
	package_name and package_version """
	flag = False
	if not deps:
		return
	values = client.release_urls(pkg_name, pkg_version)
	for value in values:
		if value['filename'].split('.')[-1] in ('gz', 'zip'):
			fetch(pkg_name, value)
	try:
		with open('./sources/python/py-'
				  + pkg_name + '/EGG-INFO/requires.txt') as f:
			list = f.readlines()
			list = [x.strip('\n') for x in list]
		f.close()
		try:
			if flag:
				shutil.rmtree('./sources/python/py-' + pkg_name + '/EGG-INFO',
							  ignore_errors=True)
				items = os.listdir('./sources/python/py-' + pkg_name)
				for item in items[:]:
					if item.split('.')[-1] not in ('gz', 'zip'):
						os.remove('./sources/python/py-'
								  + pkg_name + '/' + item)
						items.remove(item)
				if not items:
					os.rmdir('./sources/python/py-' + pkg_name)
		except:
			pass
		return list
	except:
		try:
			if flag:
				shutil.rmtree('./sources/python/py-'+pkg_name+'/EGG-INFO',
							  ignore_errors=True)
				items = os.listdir('./sources/python/py-'+pkg_name)
				for item in items[:]:
					if item.split('.')[-1] not in ('gz', 'zip'):
						os.remove('./sources/python/py-'+pkg_name+'/'+item)
						items.remove(item)
				if not items:
					os.rmdir('./sources/python/py-'+pkg_name)
		except:
			pass
		return False


def create_diff(old_file, new_file, diff_file):
	""" Creates a diff file for an existent port """
	with open(old_file) as f:
		a = f.readlines()

	with open(new_file) as f:
		b = f.readlines()

	diff_string = difflib.unified_diff(a, b, "Portfile.orig", "Portfile")
	with open(diff_file, 'w') as d:
		d.writelines(diff_string)


def search_port(name):
	""" Searches for an existent port by its name """
	try:
		command = "port file name:^py-" + name + "$"
		command = command.split()
		existing_portfile = \
			subprocess.check_output(command, stderr=subprocess.STDOUT).strip()
		return existing_portfile
	except Exception:
		return False


def checksums(pkg_name, pkg_version):
	""" Generates checksums for a package on the basis of the distfile fetched by
	its package_name and package_version """
	flag = False
	print("Attempting to fetch distfiles...")
	file_name = fetch_url(pkg_name, pkg_version, True)
	if file_name:
		checksums = []
		try:
			print("Generating checksums...")
			command = "openssl rmd160 "+file_name
			command = command.split()
			rmd160 = str(subprocess.check_output(command, stderr=subprocess.STDOUT))
			rmd160 = rmd160.split('=')[1][1:-3]
			checksums.insert(0, rmd160)

			command = "openssl sha256 "+file_name
			command = command.split()
			sha256 = str(subprocess.check_output(command, stderr=subprocess.STDOUT))
			sha256 = sha256.split('=')[1][1:-3]
			checksums.insert(1, sha256)

			dir = '/'.join(file_name.split('/')[0:-1])
			if flag:
				os.remove(file_name)
			try:
				if flag:
					os.rmdir(dir)
			except OSError:
				pass
			return checksums
		except:
			print("Error\n")
			return


def search_distfile(name, version):
	""" Searches if the distfile listed is present or not """
	try:
		url = client.release_urls(name, version)[0]['url']
		r = requests.get(url)
		if not r.status_code == 200:
			raise Exception('No distfile')
	except:
		print("No distfile found")
		print("Please set a DISTFILE env var before generating the portfile")
		sys.exit(0)


def search_license(license):
	""" Maps the license passed to the already present list of
	licences available in Macports """
	license = license.lower()
	patterns = ['.*mit.*', '.*apache.*2', '.*apache.*', '.*bsd.*', '.*agpl.*3',
				'.*agpl.*2', '.*agpl.*', '.*affero.*3', '.*affero.*2',
				'.*affero.*', '.*lgpl.*3', '.*lgpl.*2', '.*lgpl.*', '.*gpl.*3',
				'.*gpl.*2', '.*gpl.*', '.*general.*public.*license.*3',
				'.*general.*public.*license.*2',
				'.*general.*public.*license.*', '.*mpl.*3', '.*mpl.*2',
				'.*mpl.*', '.*python.*license.*', '^python$', '.*']
	licenses = ['MIT', 'Apache-2', 'Apache', 'BSD', 'AGPL-3', 'AGPL-2', 'AGPL',
				'AGPL-3', 'AGPL-2', 'AGPL', 'LGPL-3', 'LGPL-2', 'LGPL',
				'GPL-3', 'GPL-2', 'GPL', 'GPL-3', 'GPL-2', 'GPL', 'MPL-3',
				'MPL-2', 'MPL', 'Python', 'Python', 'NULL']
	for i in range(len(patterns)):
		match = re.search(patterns[i], license)
		if match:
			return licenses[i]


def port_testing(name, portv='27'):
	""" Port Testing function for various phase implementations """
	euid = os.geteuid()
	if euid:
		args = ['sudo', sys.executable] + sys.argv + [os.environ]
		os.execlpe('sudo', *args)

	for phase in [port_fetch, port_checksum, port_extract, port_configure,
				  port_build, port_destroot, port_clean]:
		print((phase.__name__))
		phase_output = phase(name, portv)
		if phase_output:
			print((phase.__name__ + " - SUCCESS"))
		else:
			print((phase.__name__ + " FAILED"))
			port_clean(name, portv)
			print("Exiting")
			sys.exit(1)

		euid = os.geteuid()
		if euid:
			args = ['sudo', sys.executable] + sys.argv + [os.environ]
			os.execlpe('sudo', *args)


def port_fetch(name, portv='27'):
	""" Fetch phase implementation """
	try:
		command = "sudo port -t fetch dports/python/py-" + \
				  name + " subport=py" + portv + "-" + name
		command = command.split()
		subprocess.check_call(command, stderr=subprocess.STDOUT)
		return True
	except:
		return False


def port_checksum(name, portv='27'):
	""" Checksum phase implementation """
	try:
		command = "sudo port -t checksum dports/python/py-" + \
				  name + " subport=py" + portv + "-" + name
		command = command.split()
		subprocess.check_call(command, stderr=subprocess.STDOUT)
		return True
	except:
		return False


def port_extract(name, portv='27'):
	""" Checksum phase implementation """
	try:
		command = "sudo port -t extract dports/python/py-" + \
				  name + " subport=py" + portv + "-" + name
		command = command.split()
		subprocess.check_call(command, stderr=subprocess.STDOUT)
		return True
	except:
		return False


def port_patch(name, portv='27'):
	""" Patch phase implementation """
	try:
		command = "sudo port -t patch dports/python/py-" + \
				  name + " subport=py" + portv + "-" + name
		command = command.split()
		subprocess.check_call(command, stderr=subprocess.STDOUT)
		return True
	except:
		return False


def port_configure(name, portv='27'):
	""" Configure phase implementation """
	try:
		command = "sudo port -t configure dports/python/py-" + \
				  name + " subport=py" + portv + "-" + name
		command = command.split()
		subprocess.check_call(command, stderr=subprocess.STDOUT)
		return True
	except:
		return False


def port_build(name, portv='27'):
	""" Build phase implementation """
	try:
		command = "sudo port -t build dports/python/py-" + \
				  name + " subport=py" + portv + "-" + name
		command = command.split()
		subprocess.check_call(command, stderr=subprocess.STDOUT)
		return True
	except:
		return False


def port_destroot(name, portv='27'):
	""" Destroot phase implementation """
	try:
		command = "sudo port -t destroot dports/python/py-" + \
				  name + " subport=py" + portv + "-" + name
		command = command.split()
		subprocess.check_call(command, stderr=subprocess.STDOUT)
		return True
	except:
		return False


def port_clean(name, portv='27'):
	""" Clean phase implementation """
	try:
		command = "sudo port -t clean dports/python/py-" + \
				  name + " subport=py" + portv + "-" + name
		command = command.split()
		subprocess.check_call(command, stderr=subprocess.STDOUT)
		return True
	except:
		return False

def create_portfile(dict, file_name, dict2):
	""" Creates a portfile on the basis of the release_data and release_url fetched
	on the basis of package_name and package_version """
	search_distfile(dict['name'], dict['version'])
	print(("Creating Portfile for pypi package " + dict['name'] + "..."))
	with open(file_name, 'w') as file:
		file.write('# -*- coding: utf-8; mode: tcl; tab-width: 4; ')
		file.write('indent-tabs-mode: nil; c-basic-offset: 4 ')
		file.write('-*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4\n')
		file.write('# $Id$\n\n')
		file.write('PortSystem          1.0\n')
		file.write('PortGroup           python 1.0\n\n')

		file.write('name                py-{0}\n'.format(dict['name']))
		file.write('version             {0}\n'.format(dict['version']))

		file.write('platforms           darwin\n')
		license = dict['license']
		license = search_license(license)
		file.write('license             {0}\n'.format(license))

		if dict['maintainer']:
			maintainers = ' '.join(dict['maintainer'])
			if not maintainers == "UNKNOWN":
				file.write('maintainers         {0}\n\n'.format(maintainers))
			else:
				file.write('maintainers         {0}\n\n'.format(
						   os.getenv('maintainer', 'nomaintainer')))
		else:
			print("No maintainers found...")
			print("Looking for maintainers in environment variables...")
			file.write('maintainers         {0}\n\n'.format(
					   os.getenv('maintainer', 'nomaintainer')))

		summary = dict['summary']
		if summary:
			summary = re.sub(r'[\[\]\{\}\;\:\$\t\"\'\`\=(--)]+',
							 ' ', summary)
			summary = re.sub(r'\s(\s)+', ' ', summary)
			summary = str(summary.encode('utf-8'))
			# print(summary)
			# print(type(summary))
			summary = ''.join([x for x in summary if x in string.printable])
			# print(type(summary))
			sum_lines = textwrap.wrap(summary)
			file.write('description         ')
			for sum_line in sum_lines:
				if sum_line:
					if not sum_lines.index(sum_line) == 0:
						file.write('                    ')
					if sum_line == sum_lines[-1]:
						file.write("{0}\n".format(sum_line))
					else:
						file.write("{0} \\\n".format(sum_line))
		else:
			file.write('description         None\n\n')

		file.write('long_description    ${description}\n\n')
		home_page = dict['home_page']

		if home_page and not home_page == 'UNKNOWN':
			file.write('homepage            {0}\n'.format(home_page))
		else:
			print("No homepage found...")
			print("Looking for homepage in environment variables...")
			file.write('homepage            {0}\n'.format(
					   os.getenv('home_page', '')))

		try:
			for item in dict2:
				if item['python_version'] == 'source':
					master_var = item['url']
					break

			if master_var:
				master_site = '/'.join(master_var.split('/')[0:-1])
				ext = master_var.split('/')[-1].split('.')[-1]
				if ext == 'zip':
					zip_set = True
				else:
					zip_set = False
		except:
			if dict['release_url']:
				master_site = dict['release_url']
				zip_set = False
			else:
				print("No master site found...")
				print("Looking for master site in environment variables...")
				master_site = os.getenv('master_site', '')
				zip_set = False

		if master_site:
			file.write('master_sites        {0}\n'.format(master_site))
			master_site_exists = True
		else:
			master_site_exists = False

		if zip_set:
			file.write('use_zip             yes\n')
			file.write('extract.mkdir       yes\n')

		file.write('distname            {0}-{1}\n\n'.format(
				   dict['name'], dict['version']))

		print(("Attempting to generate checksums for " + dict['name'] + "..."))
		checksums_values = checksums(dict['name'], dict['version'])
		if checksums_values:
			file.write('checksums           rmd160  {0} \\\n'.format(
					   checksums_values[0]))
			file.write('                    sha256  {0}\n\n'.format(
					   checksums_values[1]))

		python_vers = dict['requires_python']
		if python_vers:
			file.write('python.versions     27 {0}\n\n'.format(
					   dict['requires_python']))
		else:
			file.write('python.versions     27 34\n\n')

		print("Finding dependencies...")
		file.write('if {${name} ne ${subport}} {\n')
		file.write('    depends_build-append \\\n')
		file.write('                        ' +
				   'port:py${python.version}-setuptools\n')
		deps = dependencies(dict['name'], dict['version'], True)
		if deps:
			for i, dep in enumerate(deps):
				dep = dep.split('>')[0].split('=')[0]
				dep = dep.replace('[', '').replace(']', '')
				deps[i] = dep
			for dep in deps:
				if dep in ['setuptools', '', '\n']:
					while deps.count(dep) > 0:
						deps.remove(dep)

			if len(deps) > 0:
				file.write('    depends_run-append \\\n')

				for dep in deps[:-1]:
					file.write('                        ' +
							   'port:py${python.version}-' +
							   dep + ' \\\n')
				else:
					file.write('                        ' +
							   'port:py${python.version}-' +
							   deps[-1] + '\n')
			else:
				file.write("\n")
		file.write('\n')
		file.write('    livecheck.type      none\n')
		if master_site_exists:
			file.write('} else {\n')
			file.write('    livecheck.type      regex\n')
			file.write('    livecheck.url       ${master_sites}\n')
			file.write('}\n')
		else:
			file.write('}\n')
	print("Searching for existent port...")
	port_exists = search_port(dict['name'])
	if port_exists:
		print("Creating diff...")
		old_file = port_exists
		new_file = './dports/python/py-'+dict['name']+'/Portfile'
		diff_file = './dports/python/py-'+dict['name']+'/patch.Portfile.diff'
		create_diff(old_file, new_file, diff_file)
		print((str(os.path.abspath(diff_file))+"\n"))
		print("\nIf you want to open a new ticket. Please visit")
		print("https://trac.macports.org/auth/login/?next=/newticket")
		print("to open a new ticket after logging in with your credentials.")
	else:
		print("No port found.")


def print_portfile(pkg_name, pkg_version=None):
	""" Creates the directories and other commands necessary
	for a development environment """
	root_dir = os.path.abspath("./dports")
	port_dir = os.path.join(root_dir, 'python')
	home_dir = os.path.join(port_dir, 'py-'+pkg_name)
	if not os.path.exists(root_dir):
		os.makedirs(root_dir)
		try:
			command = 'portindex dports/'
			command = command.split()
			subprocess.call(command, stderr=subprocess.STDOUT)
		except:
			pass
	if not os.path.exists(port_dir):
		os.makedirs(port_dir)
	if not os.path.exists(home_dir):
		os.makedirs(home_dir)

	print("Attempting to fetch data from pypi...")

	dict = client.release_data(pkg_name, pkg_version)
	dict2 = client.release_urls(pkg_name, pkg_version)
	if dict and dict2:
		print("Data fetched successfully.")
	elif dict:
		print("Release Data fetched successfully.")
	elif dict2:
		print("Release url fetched successfully.")
	else:
		print("No data found.")

	file_name = os.path.join(home_dir, "Portfile")
	create_portfile(dict, file_name, dict2)
	print("SUCCESS\n")


def main(argv):
	""" Main function - Argument Parser """
	parser = argparse.ArgumentParser(description="Pypi2Port Tester")
# Calls list_all() which lists al available python packages
	parser.add_argument('-l', '--list', action='store_true', dest='list',
						default=False, required=False,
						help='List all packages')
# Calls search with the package_name
	parser.add_argument('-s', '--search', action='store', type=str,
						dest='packages_search', nargs='*', required=False,
						help='Search for a package')
# Calls release_data with package_name and package_version
	parser.add_argument('-d', '--data', action='store',
						dest='packages_data', nargs='*', type=str,
						help='Releases data for a package')
# Calls fetch_url with the various package_releases
	parser.add_argument('-f', '--fetch', action='store', type=str,
						dest='package_fetch', nargs='*', required=False,
						help='Fetches distfiles for a package')
# Calls print_portfile with the release data available
	parser.add_argument('-p', '--portfile', action='store', type=str,
						dest='package_portfile', nargs='*', required=False,
						help='Prints the portfile for a package')
# Calls port_testing
	parser.add_argument('-t', '--test', action='store', type=str,
						dest='package_test', nargs='*', required=False,
						help='Tests the portfile for various phase tests')
	options = parser.parse_args()

	if options.list:
		list_all()
		return

	if options.packages_search:
		for pkg_name in options.packages_search:
			search(pkg_name)
		return

	if options.packages_data:
		pkg_name = options.packages_data[0]
		if len(options.packages_data) > 1:
			pkg_version = options.packages_data[1]
			release_data(pkg_name, pkg_version)
		else:
			if client.package_releases(pkg_name):
				pkg_version = client.package_releases(pkg_name)[0]
				release_data(pkg_name, pkg_version)
			else:
				print("No release found\n")
		return

	if options.package_fetch:
		pkg_name = options.package_fetch[0]
		if len(options.package_fetch) > 1:
			pkg_version = options.package_fetch[1]
			fetch_url(pkg_name, pkg_version)
		else:
			releases = client.package_releases(pkg_name)
			if releases:
				pkg_version = releases[0]
				fetch_url(pkg_name, pkg_version)
			else:
				print("No release found\n")
		return

	if options.package_portfile:
		pkg_name = options.package_portfile[0]
		if len(options.package_portfile) > 1:
			pkg_version = options.package_portfile[1]
			print_portfile(pkg_name, pkg_version)
		else:
			vers = client.package_releases(pkg_name)
			if vers:
				pkg_version = vers[0]
				print_portfile(pkg_name, pkg_version)
			else:
				print("No release found\n")
		return

	if options.package_test:
		if len(options.package_test) > 0:
			pkg_name = options.package_test[0]
			port_testing(pkg_name)
		else:
			print("No package name specified\n")
		return

	parser.print_help()
	parser.error("No input specified")

if __name__ == "__main__":
	main(sys.argv[1:])
