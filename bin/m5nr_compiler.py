#!/usr/bin/env python3

#pip3 install pyyaml

import yaml
import sys
import subprocess
from subprocess import Popen, PIPE, STDOUT
import os

debug = 1

config_stream = open("../sources.yaml", "r")
config_sources = yaml.load(config_stream)


if debug:
    for source in config_sources:
        print("\nsource: %s" % source)
        print(config_sources[source])


print()
print("------------------------")
print()



def execute_command(command, env):
    if debug:
       print("exec: %s" % (command))
    
    if env:
        #for key in env:
        #    print("using environment: %s=%s" % (key, env[key]))
            
        process = subprocess.Popen(command, shell=True,  stdout=PIPE, stderr=STDOUT, close_fds=True, env=env)
    else:
        #print("no special environment")
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
    
    new_environment = None
    if 'env' in source_obj:
        new_environment = os.environ.copy()
        env_obj = source_obj['env']
        for key in env_obj:
            value = env_obj[key]
            value_evaluated  = execute_command(value, None)
            new_environment[key]=value_evaluated
            #print("%s=%s" % (key , value_evaluated))
            
        
    
    
    
    version_remote = 'NA'
    if 'version_remote' in source_obj:    
        command  = source_obj['version_remote']
        version_remote = execute_command(command, new_environment)
    
    
    if 'version_local' in source_obj:    
        command  = source_obj['version_local']
        version_local = execute_command(command, new_environment)
    
    if 'download' in source_obj:    
        download_array  = source_obj['download']
        for url in download_array:
            if not url:
                continue
            blubb = execute_command("curl -O "+url, new_environment)
    
    
    
    
    print("  remote version: %s" % version_remote)
    
    return 1




def download_sources(sources_dir , sources):
    
    current_dir = os.getcwd()
    
    do_stop = 0
    for source in sources:
        source_dir_part = os.path.join(sources_dir , source+"_part")
        if os.path.isdir(source_dir_part):
            do_stop = 1
            print("delete directory first: %s" % source_dir_part)
            
    if do_stop:
        sys.exit(1)
    
    for source in sources:
        source_dir_part = os.path.join(sources_dir , source+"_part")
        source_dir = os.path.join(sources_dir , source)
        
        
        if os.path.isdir(source_dir):
            print("directory exists, skip it. (%s)" % source_dir)
            continue
        else:
            os.makedirs(source_dir_part)
            
        os.chdir(source_dir_part)
        success = download_source(source_dir_part, source)
        if success:
            os.rename(source_dir_part, source_dir)

    os.chdir(current_dir)



def usage():
    print("usage... TODO")
    sys.exit(1)


if len(sys.argv) > 1:
    if sys.argv[1] == "download":
        
        old_list=["SEED-Annotations", "SEED-Subsystems", "PATRIC", "InterPro","UniProt","RefSeq","GenBank","PhAnToMe","CAZy","KEGG","EggNOG","IMG","SILVA-SSU", "SILVA-LSU","Greengenes","RDP","FungiDB"] 
        # all = config_sources.keys()
        
        download_sources(os.path.join(os.getcwd(), "sources"), old_list)
       

else:
    usage()