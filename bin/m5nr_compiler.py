#!/usr/bin/env python3

#pip3 install pyyaml

import yaml
import sys
import subprocess
from subprocess import Popen, PIPE, STDOUT
import os
from tabulate import tabulate
import argparse
import shutil

script_location = os.path.dirname(os.path.realpath(__file__))

config_path = os.path.normpath(os.path.join(script_location, "..", "sources.yaml"))
config_stream = open(config_path, "r")
config_sources = yaml.load(config_stream)

args = None


class MyException(Exception):
    pass
    
    

def execute_command(command, env):
    if args.debug:
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
    if args.debug:
        print(fixed)
        
    if process.returncode:
        raise MyException("Command failed (return code %d): %s" % (process.returncode, command))    
        
    return fixed


def create_environment(source_obj):
   
    new_environment = os.environ.copy()
    if 'env' in source_obj:
        env_obj = source_obj['env']
        for key in env_obj:
            value = env_obj[key]
            try:
                value_evaluated  = execute_command(value, None)
            except Exception as e:
                print("command failed: %s" % (str(e)) , file=sys.stderr)
                sys.exit(1)
            new_environment[key]=value_evaluated
        
    return new_environment

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
    
    
    if args.debug:
        print(source_obj)
    
    
    
    
    try:
        new_environment = create_environment(source_obj)
    except Exception as e:
        print("create_environment failed: %s" % (e) , file=sys.stderr)
        raise e
    
    
    version_remote = 'NA'
    if not 'VERSION_STRING' in source_obj: 
        raise MyException("version is missing")
        
    version = source_obj['VERSION_STRING']
    
    # add VERSION to environment, often needed for download
    new_environment['VERSION'] = version

        
    
    
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
                if args.simulate:
                    print("SIMULATION MODE: curl -O "+url)
                    continue
                blubb = execute_command("curl -O "+url, new_environment)
            
    
    
    
    with open('version.txt', 'wt') as f:
        f.write(version)
    
    
    return version


def get_remote_versions(sources):

    for source_name in sources:
        
        source_obj = config_sources[source_name]
        
        version_remote = 'NA'
        if not 'version' in source_obj: 
            continue
        
        try:
            new_environment = create_environment(source_obj)
        except Exception as e:
            print("create_environment failed: %s" % (e) , file=sys.stderr)
            raise e
        
        command  = source_obj['version']
        try:
            version = execute_command(command, new_environment)
        except Exception as e:
            print("command failed: %s" % (e) , file=sys.stderr)
            sys.exit(1)
            continue
          
        config_sources[source_name]["VERSION_STRING"] = version
            
    return



def download_sources(sources_dir , sources):
    
    current_dir = os.getcwd()
    
    summary = {}
    
    get_remote_versions(sources)
    
    do_stop = 0
    for source in sources:
        source_dir_part = os.path.join(sources_dir , source+"_part")
        if os.path.isdir(source_dir_part):
            do_stop = 1
            print("delete directory first: %s" % source_dir_part)
            
    if do_stop:
        if not args.force
            sys.exit(1)
    
    for source in sources:
        success = False
        success_after_download = False
        remote_version="undef"
        current_version=""
        
        source_dir_part = os.path.join(sources_dir , source+"_part")
        source_dir = os.path.join(sources_dir , source)
        
        error_message= ""
        
        if os.path.isdir(source_dir):
            print("directory exists, skip it. (%s)" % source_dir)
            version_file = os.path.join(source_dir, "version.txt")
            with open(version_file) as x: 
                current_version = x.read()
            
            success = True
        else:
            
            if args.force:
                if os.path.isdir(source_dir_part):
                    shutil.rmtree(source_dir_part) 
            
            os.makedirs(source_dir_part)
            
            os.chdir(source_dir_part)
            print("call download_source")
            try:
                remote_version = download_source(source_dir_part, source)
                success_after_download = True
            except Exception as e:
                print("download failed: %s" % (str(e)) , file=sys.stderr)
                error_message = str(e)
        
        if success_after_download:
            success = True
        
        summary[source]=[remote_version, current_version, success, error_message]
        if success_after_download:
            print("download success: %s" % (remote_version))
            os.rename(source_dir_part, source_dir)
        
            
            
    os.chdir(current_dir)
    
    status(summary)


def status(summary):
    
    summary_table = []
    for key, value in summary.items(): 
        
        
        summary_table.append([key]+value)

    
    print(tabulate(summary_table, headers=['Database', 'Remote Version', 'Local Version', 'Download Success', 'Error Message']))



################### main ######################

parser = argparse.ArgumentParser()
subparsers = parser.add_subparsers(title='subcommands', help='sub-command help', dest='commands')


parser.add_argument('--debug', action='store_true')
#parser.add_argument("-d", ...)

download_parser = subparsers.add_parser("download")
status_parser = subparsers.add_parser("status")
#b_parser = subparsers.add_parser("help")

download_parser.add_argument('--force', action='store_true')
download_parser.add_argument('--debug', action='store_true')
status_parser.add_argument('--debug', action='store_true')

download_parser.add_argument('--simulate', action='store_true')

#print(parser.parse_args(["download"]))

#args = parser.parse_args()
try:
    args = parser.parse_args()
except Exception as e:
    print("Error: %s" % (str(e)))
    parser.print_help()
    sys.exit(0)


if not args.commands:
    print("No command provided")
    parser.print_help()
    sys.exit(0)


if args.debug:
    for source in config_sources:
        print("\nsource: %s" % source)
        print(config_sources[source])
    
    print()
    print("------------------------")
    print()
    



    
all_source = config_sources.keys()
sources = all_source # TODO make this an option

sources_directory = os.getcwd() #os.path.join(os.getcwd(), "sources")

if args.commands == "download":
    
    #old_list=["SEED-Annotations", "SEED-Subsystems", "PATRIC", "InterPro","UniProt","RefSeq","GenBank","PhAnToMe","CAZy","KEGG","EggNOG","IMG","SILVA-SSU", "SILVA-LSU","Greengenes","RDP","FungiDB"] 
    
    
    download_sources(sources_directory, sources)

    sys.exit(0)

if args.commands == "status":
    
    get_remote_versions(all_source)
    summary = {}
    
    for source in sources:
        
        source_obj = config_sources[source]
        remote_version = ""
        if "VERSION_STRING" in source_obj:
            remote_version = source_obj["VERSION_STRING"]
        
        source_dir = os.path.join(sources_directory , source)
        version_file = os.path.join(source_dir, "version.txt")
        current_version = ''
        
        success = os.path.exists(version_file)
        
        
        if success:
            with open(version_file) as x: 
                current_version = x.read()
        
        summary[source]=[remote_version, current_version, success, ""]
        
        
    
    
    
    
    status(summary)
    
    sys.exit(0)

print("this should not happen")
sys.exit(1)