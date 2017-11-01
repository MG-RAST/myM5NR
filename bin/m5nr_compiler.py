#!/usr/bin/env python3

#pip3 install pyyaml

import yaml
import sys
import subprocess
from subprocess import Popen, PIPE, STDOUT
import os
from tabulate import tabulate


debug = 1
simulate = 1


script_location = os.path.dirname(os.path.realpath(__file__))

config_path = os.path.normpath(os.path.join(script_location, "..", "sources.yaml"))
config_stream = open(config_path, "r")
config_sources = yaml.load(config_stream)


if debug:
    for source in config_sources:
        print("\nsource: %s" % source)
        print(config_sources[source])


print()
print("------------------------")
print()

class MyException(Exception):
    pass
    
    

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
        
    if process.returncode:
        raise MyException("Command failed (return code %d): %s" % (process.returncode, command))    
        
    return fixed


def download_source(directory, source_name):
    print("\n")
    print(source_name)
    print("---------------------")
    
    if not source_name in config_sources:
        print("Error %s not found in config" % source_name)
        sys.exit(1)
    
    source_obj = config_sources[source_name]
    
    if "skip" in source_obj:
        if source_obj["skip"]:
            print("skip")
            return "skipped"
    
    
    if debug:
        print(source_obj)
    
    
    
    
    new_environment = None
    if 'env' in source_obj:
        new_environment = os.environ.copy()
        env_obj = source_obj['env']
        for key in env_obj:
            value = env_obj[key]
            try:
                value_evaluated  = execute_command(value, None)
            except Exception as e:
                print("command failed: %s" % (str(e)) , file=sys.stderr)
                sys.exit(1)
            new_environment[key]=value_evaluated
            #print("%s=%s" % (key , value_evaluated))
            
        
    
    
    
    version_remote = 'NA'
    if not 'version' in source_obj: 
        raise MyException("version is missing")
        
    command  = source_obj['version']
    try:
        version = execute_command(command, new_environment)
    except Exception as e:
        print("command failed: %s" % (e) , file=sys.stderr)
        sys.exit(1)
    
    if version == "":
        raise MyException("version is empty")
        
    print("remote version: %s" % version)
    
    #if 'version_local' in source_obj:    
    #    command  = source_obj['version_local']
    #    version_local = execute_command(command, new_environment)
    
    if 'download' in source_obj:    
        download_array  = source_obj['download']
        if download_array != None:
            for url in download_array:
                if not url:
                    continue
                if simulate:
                    print("SIMULATION MODE: curl -O "+url)
                    continue
                blubb = execute_command("curl -O "+url, new_environment)
            
    
    
    
    with open('version.txt', 'wt') as f:
        f.write(version)
    
    
    return version




def download_sources(sources_dir , sources):
    
    current_dir = os.getcwd()
    
    summary = {}
    
    
    do_stop = 0
    for source in sources:
        source_dir_part = os.path.join(sources_dir , source+"_part")
        if os.path.isdir(source_dir_part):
            do_stop = 1
            print("delete directory first: %s" % source_dir_part)
            
    if do_stop:
        sys.exit(1)
    
    for source in sources:
        success = False
        success_after_download = False
        version="undef"
        source_dir_part = os.path.join(sources_dir , source+"_part")
        source_dir = os.path.join(sources_dir , source)
        
        error_message= ""
        
        if os.path.isdir(source_dir):
            print("directory exists, skip it. (%s)" % source_dir)
            version_file = os.path.join(source_dir, "version.txt")
            with open(version_file) as x: 
                version = x.read()
            
            success = True
        else:
            os.makedirs(source_dir_part)
            
            os.chdir(source_dir_part)
            print("call download_source")
            try:
                version = download_source(source_dir_part, source)
                success_after_download = True
            except Exception as e:
                print("download failed: %s" % (str(e)) , file=sys.stderr)
                error_message = str(e)
        
        if success_after_download:
            success = True
        
        summary[source]=[version, success, error_message]
        if success_after_download:
            print("download success: %s" % (version))
            os.rename(source_dir_part, source_dir)
        
            
            
    os.chdir(current_dir)
    
    summary_table = []
    for key, value in summary.items(): 
        
        
        summary_table.append([key]+value)

    
    print(tabulate(summary_table, headers=['Database', 'Remote Version', 'Success', 'Error Message']))

def usage():
    print("usage... TODO")
    sys.exit(1)


if len(sys.argv) > 1:
    if sys.argv[1] == "download":
        
        #old_list=["SEED-Annotations", "SEED-Subsystems", "PATRIC", "InterPro","UniProt","RefSeq","GenBank","PhAnToMe","CAZy","KEGG","EggNOG","IMG","SILVA-SSU", "SILVA-LSU","Greengenes","RDP","FungiDB"] 
        all_source = config_sources.keys()
        
        download_sources(os.path.join(os.getcwd(), "sources"), all_source)
       

else:
    usage()