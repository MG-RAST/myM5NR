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
import pickle
import time




bin_dir = os.path.dirname(os.path.realpath(__file__))

repo_dir = os.path.normpath(os.path.join(bin_dir, "..", "sources.yaml"))
config_stream = open(repo_dir, "r")
config_sources = yaml.load(config_stream)

args = None

remote_versions_hashed=None
remote_versions_file = "remote_versions.dat"

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
    
    process.wait()    
    output = process.stdout.read()
    fixed = output.decode("utf-8").rstrip()
    if args.debug:
        print(fixed)
        
    if process.returncode:
        raise MyException("Command failed (return code %d, command: %s): %s" % (process.returncode, command, fixed[0:500]))    
        
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
                raise MyException("execute_command failed: %s" % (e))
            new_environment[key]=value_evaluated
    
    
    
    new_environment['M5NR_BIN'] = bin_dir
        
    return new_environment

def download_source(directory, source_name):
    global remote_versions_hashed
   
    
    if not source_name in config_sources:
        print("Error %s not found in config" % source_name)
        sys.exit(1)
    
    source_obj = config_sources[source_name]
    
    if "skip" in source_obj:
        if source_obj["skip"]:
            raise MyException("skipped")
    
    
    if args.debug:
        print(source_obj)
    
    version_remote = ''
    if not source_name in remote_versions_hashed: 
        raise MyException("version is missing")
        
    version_remote = remote_versions_hashed[source_name]
    
    if version_remote == "":
        raise MyException("version is empty")
    
    
        
    print("remote version: %s" % version_remote)
    
    #if 'version_local' in source_obj:    
    #    command  = source_obj['version_local']
    #    version_local = execute_command(command, new_environment)
    
    if 'download' in source_obj:    
        download_array  = source_obj['download']
        if download_array != None:
            
            try:
                new_environment = create_environment(source_obj)
            except Exception as e:
                raise MyException("create_environment failed: %s" % (e))
            
            # add VERSION to environment, often needed for download
            new_environment['VERSION'] = version_remote
            
            for url in download_array:
                if not url:
                    continue
                if args.simulate:
                    print("SIMULATION MODE: curl -O "+url)
                    continue
                blubb = execute_command("curl -O "+url, new_environment)
            
    
    
    
    with open('version.txt', 'wt') as f:
        f.write(version)
    
    with open('timestamp.txt', 'wt') as f:
        f.write(version)
        
        
    return


def parse_source(directory, source_name, source_directory):
    global remote_versions_hashed
    
    
    
    if not source_name in config_sources:
        print("Error %s not found in config" % source_name)
        sys.exit(1)
    
    source_obj = config_sources[source_name]
    
    if "skip" in source_obj:
        if source_obj["skip"]:
            raise MyException("skipped")
    
    if not os.path.exists(source_directory):
       raise MyException("source dir missing") 
    
    if 'parser' in source_obj:
        
        try:
            new_environment = create_environment(source_obj)
        except Exception as e:
            raise MyException("create_environment failed: %s" % (e))
        
        
        new_environment['SOURCE_DIR'] = source_directory
        
        
        
        command  = source_obj['parser']
        try:
            something = execute_command(command, new_environment)
            print(something)
        except Exception as e:
            raise MyException("execute_command failed: %s" % (e))
    
    else:
        raise MyException("Field \"parser\" not found in config.")    
            
    return
    

def get_remote_versions(sources):
    global remote_versions_hashed
    
    if remote_versions_hashed != None:
        return


    if os.path.exists(remote_versions_file):
        
        current_time = time.time()
        
        creation_time = os.path.getctime(remote_versions_file)
        if (current_time - creation_time) // (24 * 3600) >= 1:
            print("cached remote versions file is too old")
            os.unlink(f)
        else:        
            print("read cached remote versions from file")
            pickle_in = open(remote_versions_file,"rb")
            remote_versions_hashed = pickle.load(pickle_in)
            return


    remote_versions_hashed = {}

    for source_name in sources:
        
        source_obj = config_sources[source_name]
        
        version_remote = 'NA'
        if not 'version' in source_obj: 
            continue
        
        try:
            new_environment = create_environment(source_obj)
        except Exception as e:
            raise MyException("create_environment failed: %s" % (e))
        
        command  = source_obj['version']
        try:
            version = execute_command(command, new_environment)
        except Exception as e:
            raise MyException("execute_command failed: %s" % (e))
          
        remote_versions_hashed[source_name] = version
    
    # cache remote versions on disk
    print("save remote versions to file")
    pickle_out = open(remote_versions_file,"wb")
    pickle.dump(remote_versions_hashed, pickle_out)
    pickle_out.close()
    
    return




def parse_sources(parsings_dir , sources, sources_directory):
    
    current_dir = os.getcwd()
    
    do_stop = 0
    for source in sources:
        parse_dir_part = os.path.join(parsings_dir , source+"_part")
        if os.path.isdir(parse_dir_part):
            do_stop = 1
            print("delete directory first: %s" % parse_dir_part)
            
    if do_stop and (not args.force):
            sys.exit(1)
            
            
    for source in sources:
        print("\n")
        print("Parse %s: " % (source))
        print("---------------------")
        
        parse_dir_part = os.path.join(parsings_dir , source+"_part")
        parse_dir = os.path.join(parsings_dir , source)
        success_after_parsing = False    
            
        if os.path.isdir(parse_dir):
            print("Parse directory exists, skip it. (%s, source=%s)" % (parse_dir, source))
            
            
            success = True
        else:
            
            if args.force:
                if os.path.isdir(parse_dir_part):
                    shutil.rmtree(parse_dir_part) 
            
            os.makedirs(parse_dir_part)
            
            os.chdir(parse_dir_part)
            
            print("call parse_source")
            
            source_directory = os.path.join(sources_directory, source)
            
            try:
                parse_source(parse_dir_part, source, source_directory)
                success_after_parsing = True
            except Exception as e:
                print("parsing %s failed: %s" % (source, str(e)) , file=sys.stderr)
                error_message = str(e)
                error_file = os.path.join(parse_dir_part , 'error.txt')
                with open(error_file, 'wt') as f:
                    f.write(error_message)

            if success_after_parsing:
                print("parsing successful")
                os.rename(parse_dir_part, parse_dir)
    
           
                
            
    os.chdir(current_dir)
    
            
            

def download_sources(sources_dir , sources):
    
    # define global dict remote_versions_hashed
    get_remote_versions(all_source)
    
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
        if not args.force:
            sys.exit(1)
    
    for source in sources:
        print("\n")
        print("Download: %s" % (source))
        print("---------------------")
        success = False
        success_after_download = False
        remote_version="undef"
        current_version=""
        
        source_dir_part = os.path.join(sources_dir , source+"_part")
        source_dir = os.path.join(sources_dir , source)
        
        error_message= ""
        
        if os.path.isdir(source_dir):
            print("Source directory exists, skip it. (%s)" % source_dir)
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
                download_source(source_dir_part, source)
                success_after_download = True
            except Exception as e:
                print("download failed: %s" % (str(e)) , file=sys.stderr)
                error_message = str(e)
                error_file = os.path.join(source_dir_part , 'error.txt')
                with open(error_file, 'wt') as f:
                    f.write(error_message)
        
        if success_after_download:
            success = True
        
        if success_after_download:
            print("download success: %s" % (remote_version))
            os.rename(source_dir_part, source_dir)
        
            
            
    os.chdir(current_dir)
    
    


def status(sources_directory, parses_directory):
    
    
    # define global dict remote_versions_hashed
    get_remote_versions(all_source)
    summary_table = []
    #summary = {}
    
    for source in sources:
        
        download_success = False
        download_error_message = ""
        
        parsing_success = False
        parsing_error_message = ""
        
        source_obj = config_sources[source]
        remote_version = ""
        if source in remote_versions_hashed:
            remote_version = remote_versions_hashed[source]
        
        
        source_dir_part = os.path.join(sources_directory , source+"_part")
        source_dir = os.path.join(sources_directory , source)
       
        parse_dir = os.path.join(parses_directory , source)
        parse_dir_part = os.path.join(parses_directory , source+"_part")
        
        
        # get current version (version file inidcates success)
        current_version = ''
        version_file = os.path.join(source_dir, "version.txt")
        download_error_file = os.path.join(source_dir, "error.txt")
        parse_error_file = os.path.join(parse_dir_part, "error.txt")
        
        
        if (not os.path.isdir(source_dir)) and os.path.exists(download_error_file):
            with open(error_file) as x: 
                download_error_message = x.read()
        
        if (not os.path.isdir(parse_dir)) and os.path.exists(parse_error_file):
            with open(parse_error_file) as x: 
                parsing_error_message = x.read()
        
        
        
        if os.path.exists(version_file):
            with open(version_file) as x: 
                current_version = x.read()
        
        if current_version != "" :
            download_success = True # TODO is success possible without version number ?
            
        
        d_message = download_error_message[0:30]
        p_message = parsing_error_message[0:30]
        
        if len(d_message) == 30:
            d_message += "..."
        
        if len(p_message) == 30:
            p_message += "..."
        
        summary_table.append([source, remote_version, current_version, download_success, d_message, parsing_success, p_message ])
    
    
    
    print(tabulate(summary_table, headers=['Database', 'Remote Version', 'Local Version', 'Download Success', 'Download Error','Parsing Success', 'Parsing Error']))



################### main ######################

parser = argparse.ArgumentParser()
subparsers = parser.add_subparsers(title='subcommands', help='sub-command help', dest='commands')


parser.add_argument('--debug', '-d', action='store_true')


download_parser = subparsers.add_parser("download")
status_parser = subparsers.add_parser("status")
parse_parser = subparsers.add_parser("parse")


# download
download_parser.add_argument('--force', '-f', action='store_true')
download_parser.add_argument('--debug', '-d', action='store_true')
download_parser.add_argument('--simulate', action='store_true')

# parse
parse_parser.add_argument('--force', '-f', action='store_true')
parse_parser.add_argument('--debug', '-d', action='store_true')

# status
status_parser.add_argument('--debug', '-d', action='store_true')



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


#if args.debug:
#    for source in config_sources:
#        print("\nsource: %s" % source)
#        print(config_sources[source])
#    
#    print()
#    print("------------------------")
#    print()
    



    
all_source = config_sources.keys()
sources = all_source # TODO make this an option

sources_directory = os.path.join(os.getcwd(), "Sources")
parses_directory = os.path.join(os.getcwd(), "Parsed")


if not os.path.isdir(sources_directory):
    print("Directory %s is missing." % (sources_directory), file=sys.stderr)
    print("Directories \"Sources\" and \"Parsed\" have to be in the working directory.", file=sys.stderr)
    sys.exit(1)

if not os.path.isdir(parses_directory):
    print("directory %s is missing" % (parses_directory), file=sys.stderr)
    sys.exit(1)



if args.commands == "download":
    
    #old_list=["SEED-Annotations", "SEED-Subsystems", "PATRIC", "InterPro","UniProt","RefSeq","GenBank","PhAnToMe","CAZy","KEGG","EggNOG","IMG","SILVA-SSU", "SILVA-LSU","Greengenes","RDP","FungiDB"] 
    
        
    download_sources(sources_directory, sources)

    status(sources_directory, parses_directory)
    
    sys.exit(0)

if args.commands == "parse":
    
    parse_sources(parses_directory, sources, sources_directory)

    status(sources_directory, parses_directory)
    
    sys.exit(0)
    
if args.commands == "status":
    
    
    status(sources_directory, parses_directory)
    
    sys.exit(0)

print("this should not happen")
sys.exit(1)