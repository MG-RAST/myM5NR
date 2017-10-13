#!/usr/bin/env python3

# apt-get install -y python3 python3-pip
# pip3 install tabulate
# pip3 install --upgrade pip

import os.path
from tabulate import tabulate
import os

sources_dir = '/m5nr_data/Sources/'
dirs = [d for d in os.listdir(sources_dir) if os.path.isdir(os.path.join(sources_dir, d)) ]


sources_str = os.environ['SOURCES']
sources = sources_str.split(" ")

if not sources:
    print("Please set variable SOURCES first, ie. source sources.cfg") 
    sys.exit(1)

data = []
for dir in sources:
    #print(dir)
    timestamp="NA"
    version="NA"
    state = "NA"
    if os.path.isdir(sources_dir+dir+"_part"):
        state="incomplete"
    if os.path.isdir(sources_dir+dir):
        state="complete"
        
    time_file = sources_dir+dir+"/timestamp.txt"
    if os.path.isfile(time_file):
        with open(time_file, 'r') as myfile:
            timestamp=myfile.read().replace('\n', '')
            #print("timestamp: "+timestamp)
    version_file = sources_dir+dir+"/version.txt"
    if os.path.isfile(version_file):
        with open(version_file, 'r') as myfile:
            version=myfile.read().replace('\n', '')
            #print("version: "+version)
    
    data.append([dir, state, version, timestamp])

print(tabulate(data, headers=['Source', 'state', 'version', 'timestamp']))
