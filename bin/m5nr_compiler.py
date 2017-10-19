#!/usr/bin/env python3

#pip3 install pyyaml

import yaml
import sys
import subprocess
from subprocess import Popen, PIPE, STDOUT
import os

debug = 0

config_stream = open("../sources.yaml", "r")
config_sources = yaml.load(config_stream)


if debug:
    for source in config_sources:
        print("\nsource: %s" % source)
        print(config_sources[source])


print()
print("------------------------")
print()



def execute_command(command):
    if debug:
       print(command)
    
    process = subprocess.Popen(command, shell=True,  stdout=PIPE, stderr=STDOUT, close_fds=True)
    output = process.stdout.read()
    fixed = output.decode("utf-8").rstrip()
    if debug:
        print(fixed)
    return fixed


def download_source(directory, source_name):
    print(source_name)
    
    
    if not source_name in config_sources:
        print("Error %s not found in config" % source_name)
        sys.exit(1)
    
    source_obj = config_sources[source_name]
    
    if debug:
        print(source_obj)
    
    
    
    version_remote = 'NA'
    if 'version_remote' in source_obj:    
        command  = source_obj['version_remote']
        version_remote = execute_command(command)
    
    
    if 'version_local' in source_obj:    
        command  = source_obj['version_local']
        version_local = execute_command(command)
    
    
    
    
    
    
    print("  remote version: %s" % version_remote)
    
    




def download_sources(sources_dir , sources):
    
    current_dir = os.getcwd()
    
    for source in sources:
        
        source_dir = os.path.join(sources_dir , source)
        if not os.path.isdir(source_dir):
            os.makedirs(source_dir)
        os.chdir(source_dir)
        download_source(source_dir, source)

    os.chdir(current_dir)



def usage():
    print("usage... TODO")
    sys.exit(1)


if len(sys.argv) > 1:
    if sys.argv[1] == "download":
        
        old_list=["SEED-Annotations", "SEED-Subsystems", "PATRIC", "InterPro","UniProt","RefSeq","GenBank","PhAnToMe","CAZy","KEGG","EggNOG","IMG","SILVA-SSU", "SILVA-SSU","Greengenes","RDP","FungiDB"] 
        # all = config_sources.keys()
        
        download_sources(os.path.join(os.getcwd(), "sources"), old_list)
       

else:
    usage()