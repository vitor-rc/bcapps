#!/usr/local/bin/python

# cloud testing (you must have a picloud.com account AND set
# cloudconf.py correctly for any of this to work)

# from __future__ import print_function
import cloud
import os;

def mirror(x): return x
def readfile(f): return open(f, 'r').read()
def sysop(cmd): return os.popen(cmd).read()

# jid = sysop("ls")
# print jid

# os.system("ls")

# jid = cloud.call(mirror, "hello")
# jid = cloud.call(mirror, "`date`")
# jid = cloud.call(os.system, "date"); # doesnt work
# jid = cloud.call(readfile, "/etc/passwd")
# jid = cloud.call(os.system, "cat /etc/passwd")
# jid = cloud.call(os.popen, "ls")
jid = cloud.call(sysop, "date")

# jid = cloud.call(os.system, "ls", _env="barryenv1", _profile=True)
# jid = cloud.call(os.system, "rsync /usr/local/bin/bc-temperature-voronoi.pl root\@data.barrycarter.info:/sites/TEST/", _env="barryenv1", _profile=True)
# jid = cloud.call(os.system, "bc-voronoi-temperature.pl --nodaemon", _env="barryenv1")

print cloud.result(jid)


exit();

# cloud.files.put("sample-data/testfile.txt")

print cloud.files.getf("testfile.txt").read()

# print cloud.files.put("playground.svg")
# print cloud.files.getf("playground.svg").read()

# print cloud.files.list()

# jid = cloud.call(readfile, "/usr/share/")
# print cloud.result(jid)

# print cloud.rest.publish(readfile, "readfile", out_encoding='raw')
# print cloud.rest.publish(os.system, "mysys", out_encoding='raw')
# print cloud.rest.publish(mirror, "mirror", out_encoding='raw')

# https://api.picloud.com/r/2957/mysys
# https://api.picloud.com/r/2957/readfile

# def mirror(x): return x

# jid = cloud.call(mirror, "`date`")
# print cloud.result(jid)

# for x in range(1,100):
#    cloud.call(os.system,"curl picloudips.barrycarter.info")

# jid = cloud.call(os.system, "curl `perl -le 'print time()'`.barrycarter.info")
# jid = cloud.call(os.system, "curl `whoami`.barrycarter.info")
# jid = cloud.call(os.system, "curl '`sudo whoami`.barrycarter.info'")
# jid = cloud.call(os.system, "curl \"`date`.barrycarter.info\"")
# print cloud.result(jid)

# in my logs:

# 184.73.142.136 pi.barrycarter.info - [25/Oct/2011:11:44:35 -0600] "GET / HTTP/1.1" 200 94 "-" "curl/7.21.0 (x86_64-pc-linux-gnu) libcurl/7.21.0 OpenSSL/0.9.8o zlib/1.2.3.4 libidn/1.18"
