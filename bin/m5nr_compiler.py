#!/usr/bin/env python3

#pip3 install pyyaml

import yaml
import sys
import subprocess
from subprocess import Popen, PIPE, STDOUT
import os
import argparse
import shutil
import pickle
import time
from shutil import copyfile
import pprint
from prettytable import PrettyTable
import datetime

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
    global args
    

    
    if env:
        for key in env:
            print("key: %s" % (key))
            search_string = "${"+key+"}"
            print("search_string: %s" % (search_string))
            value = new_environment[key]
            command = command.replace(search_string, value)
        
        if args.debug:
           print("exec: %s" % (command), flush=True)
            
        process = subprocess.Popen(command, shell=True,  stdout=PIPE, stderr=STDOUT, close_fds=True, executable='/bin/bash', env=env)
    else:
        if args.debug:
           print("exec: %s" % (command), flush=True)
        #print("no special environment")
        process = subprocess.Popen(command, shell=True,  stdout=PIPE, stderr=STDOUT, close_fds=True, executable='/bin/bash')
    
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
            
            if args.debug:
                print("%s=%s" % (key, value_evaluated))    
            new_environment[key]=value_evaluated
    
    
    
    new_environment['M5NR_BIN'] = bin_dir
    
    
        
    return new_environment

def download_source(directory, source_name):
    global remote_versions_hashed
    global args
    
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
        
    version_remote = str(remote_versions_hashed[source_name])
    
    if version_remote == "":
        raise MyException("version is empty")
    
    
        
    print("remote version: %s" % version_remote)
    
    #if 'version_local' in source_obj:    
    #    command  = source_obj['version_local']
    #    version_local = execute_command(command, new_environment)
    
    download_instruction = False
    if 'no-download' in source_obj:
        if  source_obj['no-download']:
            raise MyException("no-download") # TODO not sure if I should declare success here.
    
    if 'download' in source_obj:    
        something  = source_obj['download']
        
        if isinstance(something, list):
            download_array = something
        else:
            download_array = [something]
        
        if download_array != None:
            download_instruction = True
            try:
                new_environment = create_environment(source_obj)
            except Exception as e:
                raise MyException("create_environment failed: %s" % (e))
            
            # add VERSION to environment, often needed for download
            new_environment['VERSION'] = version_remote
            
            for url in download_array:
                if not url:
                    continue
                
                silent="--silent "
                if args.debug:
                    silent = ""
                # curl: --speed-time 15 --speed-limit 1000 : stop transfer if less than 1000 bytes per second during 15 seconds
                download_command = "curl %s--connect-timeout 10 --retry 5 --retry-delay 10 --speed-time 15 --speed-limit 1000 --remote-name-all  %s" % (silent, url)
                
                    
                some_text=""    
                if args.simulate:
                    print("SIMULATION MODE: "+download_command)
                    continue
                try:
                    some_text = execute_command(download_command, new_environment)
                except Exception as e:
                    
                    if args.debug:
                        if some_text:
                            print(some_text)
                    
                    raise MyException("(download) execute_command failed: %s" % (e))
                    
    if 'download-command' in source_obj:
        
        something  = source_obj['download-command']
        if isinstance(something, list):
            command_array = something
        else:
            command_array = [something]
            
        
        download_instruction = True
        
        
        try:
            new_environment = create_environment(source_obj)
        except Exception as e:
            raise MyException("create_environment failed: %s" % (e))
        
        # add VERSION to environment, often needed for download
        new_environment['VERSION'] = version_remote
        
        
        for download_command in command_array:
            try:
                value_evaluated  = execute_command(download_command, new_environment)
            except Exception as e:
                raise MyException("(download_command) execute_command failed: %s" % (e))
        
    
    
    if not download_instruction:
        raise MyException("download instruction mising")
    
    
    with open('version.txt', 'wt') as f:
        f.write(version_remote)
    
    
    
    with open('timestamp.txt', 'wt') as f:
        f.write(datetime.datetime.now().isoformat())
        
        
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
        
        
        
        
        command_array = []
        something  = source_obj['parser']
        if isinstance(something, list):
            command_array = something
        else:
            command_array = [something]
        
        
        
        for command in command_array:
            try:
                something = execute_command(command, new_environment)
            except Exception as e:
                print(something)
                raise MyException("execute_command failed: %s" % (e))
    
        
        # success, copy verison file
        source_version_file = os.path.join(source_directory, "version.txt")
        copyfile(source_version_file, os.path.join(directory, "version.txt"))
        
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
            os.unlink(remote_versions_file)
        else:        
            print("read cached remote versions from file")
            pickle_in = open(remote_versions_file,"rb")
            remote_versions_hashed = pickle.load(pickle_in)
            
            #pp = pprint.PrettyPrinter(indent=4)
            #pp.pprint(remote_versions_hashed)
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
    global args
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
    global args
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
            print("download success.")
            os.rename(source_dir_part, source_dir)
        
            
            
    os.chdir(current_dir)
    
    


def status(sources_directory, parses_directory):
    
    
    # define global dict remote_versions_hashed
    get_remote_versions(all_source)
    summary_table= PrettyTable()
    #summary_table = []
    #summary = {}
    
    for source in sources:
        
        download_success = False
        download_error_message = ""
        
        parsing_success = False
        parsing_error_message = ""
        
        source_obj = config_sources[source]
        remote_version = ""
        if source in remote_versions_hashed:
            remote_version = str(remote_versions_hashed[source])
            
        
        source_dir_part = os.path.join(sources_directory , source+"_part")
        source_dir = os.path.join(sources_directory , source)
       
        parse_dir = os.path.join(parses_directory , source)
        parse_dir_part = os.path.join(parses_directory , source+"_part")
        
        
        # get current version (version file inidcates success)
        current_version = ''
        version_file = os.path.join(source_dir, "version.txt")
        parsing_version_file = os.path.join(parse_dir, "version.txt")
        download_error_file = os.path.join(source_dir_part, "error.txt")
        parse_error_file = os.path.join(parse_dir_part, "error.txt")
        
        
        if (not os.path.isdir(source_dir)) and os.path.exists(download_error_file):
            with open(download_error_file) as x: 
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
        
        
        if os.path.exists(parsing_version_file):
            parsing_success = True
        
        
        
        summary_table.add_row([source, remote_version, current_version, download_success, d_message, parsing_success, p_message ])
    
    
    summary_table.field_names = ['Database', 'Remote Version', 'Local Version', 'Download Success', 'Download Error','Parsing Success', 'Parsing Error']
    summary_table.align = "l"
    
    
    print(summary_table.get_string())
    #print(tabulate(summary_table, headers=['Database', 'Remote Version', 'Local Version', 'Download Success', 'Download Error','Parsing Success', 'Parsing Error']))



################### main ######################

parser = argparse.ArgumentParser()
subparsers = parser.add_subparsers(title='subcommands', help='sub-command help', dest='commands')


parser.add_argument('--debug', '-d', action='store_true')


download_parser = subparsers.add_parser("download")
status_parser = subparsers.add_parser("status")
parse_parser = subparsers.add_parser("parse")


# download
download_parser.add_argument('--sources', '-s', action='store')
download_parser.add_argument('--force', '-f', action='store_true')
download_parser.add_argument('--debug', '-d', action='store_true')
download_parser.add_argument('--simulate', action='store_true')

# parse
parse_parser.add_argument('--sources', '-s', action='store')
parse_parser.add_argument('--force', '-f', action='store_true')
parse_parser.add_argument('--debug', '-d', action='store_true')

# status
status_parser.add_argument('--sources', '-s', action='store')
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

sources = None

if args.sources:
    sources = args.sources.split(" ")
    if len(sources) == 1:
        sources = args.sources.split(",")
else:
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