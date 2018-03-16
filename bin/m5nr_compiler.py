#!/usr/bin/python3 -u

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

# variable for use in config file: --location (-L) = follow redirect
CURL_OPTS = '--silent --show-error --connect-timeout 10 --location'

bin_dir = os.path.dirname(os.path.realpath(__file__))
repo_dir = os.path.normpath(os.path.join(bin_dir, ".."))
sources_file = os.path.join(repo_dir, "sources.yaml")
config_sources = yaml.load(open(sources_file, "r"))
config_build = yaml.load(open(os.path.join(repo_dir, "build.yaml"), "r"))

args = None

remote_versions_hashed=None
remote_versions_file = "remote_versions.dat"

class MyException(Exception):
    pass
    
class DependencyMissingException(Exception):
    pass

def execute_command(command, env):
    global args
    
    if env:
        for key in env:
            search_string = "${"+key+"}"
            value = env[key]
            command = command.replace(search_string, value)
        
        if args.debug:
           print("exec: %s" % (command), flush=True)
        process = subprocess.Popen(command, shell=True,  stdout=PIPE, stderr=STDOUT, close_fds=True, executable='/bin/bash', env=env)
    else:
        if args.debug:
           print("exec: %s" % (command), flush=True)
        process = subprocess.Popen(command, shell=True,  stdout=PIPE, stderr=STDOUT, close_fds=True, executable='/bin/bash')
  
    last_line = ''
    while True:
        output = process.stdout.readline()
        rc = process.poll()
        if (not output) and (process.poll() is not None):
            break
        if output:
            last_line = output.decode("utf-8").rstrip()
        if rc==0:
            break
    
    if args.debug:
        print(last_line)
    
    if process.returncode:
        raise MyException("Command failed (return code %d, command: %s): %s" % (process.returncode, command, last_line[0:500]))
        
    return last_line


def create_environment(source_obj, ignore_error=False):
    global args
    global sources_file
    global parses_directory
   
    new_environment = os.environ.copy()
    new_environment['TODAY'] = datetime.date.today().isoformat()
    new_environment['M5NR_BIN'] = bin_dir
    new_environment['CURL_OPTS'] = CURL_OPTS
    new_environment['SOURCE_FILE'] = sources_file
    new_environment['PARSED_DIR'] = parses_directory
    
    if hasattr(args, 'version') and args.version:
        new_environment['M5NR_VERSION'] = args.version
    
    if 'env' in source_obj:
        env_obj = source_obj['env']
        for key in env_obj:
            value = env_obj[key]
            try:
                value_evaluated  = execute_command(value, new_environment)
            except Exception as e:
                if ignore_error:
                    sys.stderr.write("warning: execute_command for key %s failed: %s\n"%(key, str(e)))
                    continue
                else:
                    raise MyException("execute_command for key %s failed: %s" %(key, str(e)))
            
            if args.debug:
                print("%s=%s" % (key, value_evaluated))
            new_environment[key]=value_evaluated
    
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
    
    no_download = False
    if 'no-download' in source_obj:
        if  source_obj['no-download']:
            no_download = True
     
    if args.debug:
        print(source_obj)
    
    version_remote = ''
    
    if source_name in remote_versions_hashed:
        version_remote = str(remote_versions_hashed[source_name])
    
    else:
        if no_download:
            version_remote = "-"
        else:
            raise MyException("version is missing")
    
    if version_remote == "":
        raise MyException("version is empty")
    
    print("remote version: %s" % version_remote)
    
    #if 'version_local' in source_obj:    
    #    command  = source_obj['version_local']
    #    version_local = execute_command(command, new_environment)
    
    download_instruction = False
    
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
                
                # curl: --speed-time 15 --speed-limit 1000 : stop transfer if less than 1000 bytes per second during 15 seconds
                # --continue-at - (try to resume download)
                download_command = "curl %s --retry 5 --retry-delay 10 --speed-time 15 --speed-limit 1000 --remote-name-all --continue-at - %s" % (CURL_OPTS, url)
                
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
    
    if (not download_instruction) and (not no_download):
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
    
    depends = []
    if 'depends' in source_obj:
        depends =  source_obj["depends"]
    
    for dep in depends:
        dep_dir = os.path.normpath(os.path.join(directory, "..", dep))
        dep_version_file = os.path.join(dep_dir, "version.txt")
        if not os.path.exists(dep_version_file):
            raise DependencyMissingException("dependency %s missing" % (dep))
    
    version_file = os.path.join(source_directory, "version.txt")
    version = 'NA'
    with open(version_file, 'r') as myfile:
        version=myfile.read()
    
    if not os.path.exists(source_directory):
       raise MyException("source dir missing") 
    
    if 'parser' in source_obj:
        
        new_environment = create_environment(source_obj, True)
        new_environment['SOURCE_DIR'] = source_directory
        new_environment['VERSION'] = version
        
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
        
        with open(os.path.join(directory, 'timestamp.txt'), 'wt') as f:
            f.write(datetime.datetime.now().isoformat())
        
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
        
        new_environment = create_environment(source_obj, True)
        command = source_obj['version']
        
        try:
            version = execute_command(command, new_environment)
        except Exception as e:
            version = '-'
            print("execute_command failed: %s" % (str(e)))
            print("skipping %s" % (source_name))
          
        remote_versions_hashed[source_name] = version
    
    # cache remote versions on disk
    print("save remote versions to file")
    pickle_out = open(remote_versions_file,"wb")
    pickle.dump(remote_versions_hashed, pickle_out)
    pickle_out.close()
    
    return


def parse_sources(parsings_dir, sources, sources_directory):
    global args
    current_dir = os.getcwd()
    
    if not args.force:
        do_stop = 0
        for source in sources:
            parse_dir_part = os.path.join(parsings_dir , source+"_part")
            if os.path.isdir(parse_dir_part):
                do_stop = 1
                print("delete directory first: %s" % parse_dir_part)
            
        if do_stop:
            sys.exit(1)
    
    success_status = 0
    
    for source in sources:
        print("\n")
        print("Parse %s: " % (source))
        print("---------------------")
        
        parse_dir_part = os.path.join(parsings_dir , source+"_part")
        parse_dir = os.path.join(parsings_dir , source)
        success_after_parsing = False
        error_message = ""
            
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
            except DependencyMissingException as e:
                success_status = 42
                error_message = str(e)
            except Exception as e:
                success_status = 1
                error_message = str(e)

            if success_after_parsing:
                print("parsing successful")
                os.rename(parse_dir_part, parse_dir)
            else:
                print("parsing %s failed: %s" % (source, error_message) , file=sys.stderr)
                error_file = os.path.join(parse_dir_part , 'error.txt')
                with open(error_file, 'wt') as f:
                    f.write(error_message)
    
    os.chdir(current_dir)
    return success_status


def download_sources(sources_dir , sources):
    global args
    # define global dict remote_versions_hashed
    get_remote_versions(all_source)
    
    current_dir = os.getcwd()
    
    summary = {}
    
    get_remote_versions(sources)
    
    do_stop = 0
    if not args.force:
        for source in sources:
            resume = False
            source_obj = config_sources[source]
            if 'resume-download' in source_obj:
                if source_obj['resume-download']:
                    resume=True
            if not resume:
                source_dir_part = os.path.join(sources_dir , source+"_part")
                if os.path.isdir(source_dir_part):
                    do_stop = 1
                    print("delete directory first: %s" % source_dir_part)
            
        if do_stop:
            sys.exit(1)
    
    success_status = 0
    
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
            source_obj = config_sources[source]
            
            resume = False
            if 'resume-download' in source_obj:
                if source_obj['resume-download']:
                    resume=True
            
            if resume:
                if not os.path.isdir(source_dir_part):
                    os.makedirs(source_dir_part)
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
                success_status = 1
                error_message = str(e)
                print("download failed: %s" % (error_message) , file=sys.stderr)
                error_file = os.path.join(source_dir_part , 'error.txt')
                with open(error_file, 'wt') as f:
                    f.write(error_message)
        
        if success_after_download:
            success = True
        
        if success_after_download:
            print("download success.")
            os.rename(source_dir_part, source_dir)
    
    os.chdir(current_dir)
    return success_status
    

def get_dir_size(start_path):
    total_size = 0
    for dirpath, dirnames, filenames in os.walk(start_path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            total_size += os.path.getsize(fp)
    return total_size


def build_m5nr(build_directory, build_actions):
    global args
    global config_build
    
    current_dir = os.getcwd()
    
    if not args.force:
        do_stop = 0
        for build in config_build:
            build_dir_part = os.path.join(build_directory, build['name']+"_part")
            if os.path.isdir(build_dir_part):
                do_stop = 1
                print("delete directory first: %s"%(build_dir_part))
        
        if do_stop:
            sys.exit(1)
    
    success_status = 0
    
    for build in config_build:
        if build['name'] not in build_actions:
            continue
        
        print("\n")
        print("Build %s: " % (build['name']))
        print("---------------------")
        
        build_dir = os.path.join(build_directory, build['name'])
        build_dir_part = build_dir+"_part"
        success_after_building = False
        error_message = ""
        
        if os.path.isdir(build_dir):
            print("Build directory exists, skip it. (%s, build=%s)" %(build_dir, build['name']))
            success = True
        else:
            if args.force:
                if os.path.isdir(build_dir_part):
                    shutil.rmtree(build_dir_part) 
            
            os.makedirs(build_dir_part)
            os.chdir(build_dir_part)
            
            try:
                build_action(build_dir_part, build)
                success_after_building = True
            except DependencyMissingException as e:
                success_status = 42
                error_message = str(e)
            except Exception as e:
                success_status = 1
                error_message = str(e)
            
            if success_after_building:
                print("build successful")
                os.rename(build_dir_part, build_dir)
            else:
                print("building %s failed: %s" % (build['name'], error_message) , file=sys.stderr)
                error_file = os.path.join(build_dir_part , 'error.txt')
                with open(error_file, 'wt') as f:
                    f.write(error_message)
    
    os.chdir(current_dir)
    return success_status


def build_action(directory, build_obj):
    global remote_versions_hashed
    
    depends = []
    if 'depends' in build_obj:
        depends = build_obj["depends"]
    
    for dep in depends:
        dep_dir = os.path.normpath(os.path.join(directory, "..", dep))
        dep_version_file = os.path.join(dep_dir, "version.txt")
        if not os.path.exists(dep_version_file):
            raise DependencyMissingException("dependency %s missing" % (dep))
    
    if 'parser' in build_obj:
        
        new_environment = create_environment(build_obj, True)
        if 'M5NR_VERSION' not in new_environment:
            raise MyException("missing required m5nr version: %s" % str(e))
        
        command_array = []
        something  = build_obj['parser']
        if isinstance(something, list):
            command_array = something
        else:
            command_array = [something]
        
        for command in command_array:
            try:
                something = execute_command(command, new_environment)
            except Exception as e:
                print(something)
                raise MyException("execute_command failed: %s" % str(e))
        
        # success
        with open(os.path.join(directory, 'version.txt'), 'wt') as f:
            f.write(new_environment['M5NR_VERSION'])
        
        with open(os.path.join(directory, 'timestamp.txt'), 'wt') as f:
            f.write(datetime.datetime.now().isoformat())
        
    else:
        raise MyException("Field \"parser\" not found in config.")    
            
    return


def status(sources_directory, parses_directory, build_directory):
    
    # define global dict remote_versions_hashed
    get_remote_versions(all_source)
    
    # table for download / parse
    summary_table = PrettyTable()
    
    for source in sources:
        download_success = False
        download_error_message = ""
        parsing_success = False
        parsing_error_message = ""
        
        source_obj = config_sources[source]
        if ('skip' in source_obj) and source_obj['skip']:
            summary_table.add_row([source, "", "", "Skip", "", "", "", "Skip", "", "" ])
            continue
        
        remote_version = ""
        if source in remote_versions_hashed:
            remote_version = str(remote_versions_hashed[source])
        
        source_dir = os.path.join(sources_directory , source)
        source_dir_part = source_dir+"_part"
       
        parse_dir = os.path.join(parses_directory , source)
        parse_dir_part = parse_dir+"_part"
        
        source_dir_size_mb_int = 0
        
        # get current version (version file indicates success)
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
        
        if current_version != "":
            download_success = True # TODO is success possible without version number ?
            source_dir_size = get_dir_size(source_dir)
            source_dir_size_mb = source_dir_size/(1014*1024*1.0)
            if source_dir_size_mb > 1:
                source_dir_size_mb_int = int(source_dir_size_mb)
            else:
                source_dir_size_mb_int = "%.3f"%(source_dir_size_mb)
        
        if not download_success:
            source_dir_size_mb_int = ''
        
        d_message = download_error_message[0:30]
        p_message = parsing_error_message[0:30]
        
        if len(d_message) == 30:
            d_message += "..."
        
        if len(p_message) == 30:
            p_message += "..."
        
        if os.path.exists(parsing_version_file):
            parsing_success = True
        
        # get current timestamps
        download_timestamp = ""
        parsing_timestamp = ""
        download_timestamp_file = os.path.join(source_dir, "timestamp.txt")
        parsing_timestamp_file = os.path.join(parse_dir, "timestamp.txt")
        
        if os.path.exists(download_timestamp_file):
            with open(download_timestamp_file) as x:
                download_timestamp = x.read().strip().split(".")[0]
        
        if os.path.exists(parsing_timestamp_file):
            with open(parsing_timestamp_file) as x:
                parsing_timestamp = x.read().strip().split(".")[0]
        
        summary_table.add_row([source, remote_version, current_version, download_success, download_timestamp, source_dir_size_mb_int, d_message, parsing_success, parsing_timestamp, p_message ])
    # done for loop
    
    summary_table.field_names = ['Database', 'Remote Version', 'Local Version', 'Download Success', 'Download Timestamp', 'Size (MB)', 'Download Error','Parsing Success', 'Parsing Timestamp', 'Parsing Error']
    summary_table.align = "l"
    print(summary_table.get_string(sortby="Database"))
    
    if build_directory:
        # table for build
        build_table = PrettyTable()
        
        for build in config_build:
            build_success = False
            build_error_message = ""
            
            build_dir = os.path.join(build_directory , build['name'])
            build_dir_part = build_dir+"_part"
            
            current_version = ''
            error_message = ''
            build_timestamp = ''
            
            version_file = os.path.join(build_dir, "version.txt")
            error_file = os.path.join(build_dir_part, "error.txt")
            timestamp_file = os.path.join(build_dir, "timestamp.txt")
            
            if (not os.path.isdir(build_dir)) and os.path.exists(error_file):
                with open(error_file) as x:
                    error_message = x.read()
            
            if os.path.exists(version_file):
                with open(version_file) as x:
                    current_version = x.read()
            
            if current_version != "":
                build_success = True # TODO is success possible without version number ?
            
            emessage = error_message[0:30]
            
            if len(emessage) == 30:
                emessage += "..."
            
            if os.path.exists(timestamp_file):
                with open(timestamp_file) as x:
                    build_timestamp = x.read().strip().split(".")[0]
            
            build_table.add_row([build['name'], current_version, build_success, build_timestamp, emessage])
        # done for loop
        
        build_table.field_names = ['Build Step', 'M5NR version', 'Success', 'Timestamp', 'Error']
        build_table.align = "l"
        print(build_table.get_string())


# only use this with complete source list, so no broken / missing dependencies
def sources_sorted_by_dependency(display=False):
    sorted_sources = []
    sources = sorted(config_sources.keys())
    
    # seed with non-dependants
    for src in sources:
        if 'depends' not in config_sources[src]:
            sorted_sources.append(src)
            if display:
                print(src)
    
    # add dependencies
    while len(sorted_sources) != len(sources):
        for src in sources:
            if src in sorted_sources:
                continue
            has_dependants = 0
            for dep in config_sources[src]['depends']:
                if dep in sorted_sources:
                    has_dependants += 1
            if len(config_sources[src]['depends']) == has_dependants:
                sorted_sources.append(src)
                if display:
                    print(src)
                    for dep in config_sources[src]['depends']:
                        print("\t"+dep)
    return sorted_sources


################### main ######################

parser = argparse.ArgumentParser()
subparsers = parser.add_subparsers(title='subcommands', help='sub-command help', dest='commands')

parser.add_argument('--debug', '-d', action='store_true')

status_parser = subparsers.add_parser("dependancy")
status_parser = subparsers.add_parser("status")
download_parser = subparsers.add_parser("download")
parse_parser = subparsers.add_parser("parse")
build_parser = subparsers.add_parser("build")

# status
status_parser.add_argument('--sources', '-s', action='store')
status_parser.add_argument('--action', '-a', action='store')
status_parser.add_argument('--debug', '-d', action='store_true')

# download
download_parser.add_argument('--sources', '-s', action='store')
download_parser.add_argument('--force', '-f', action='store_true')
download_parser.add_argument('--debug', '-d', action='store_true')
download_parser.add_argument('--simulate', action='store_true')

# parse
parse_parser.add_argument('--sources', '-s', action='store')
parse_parser.add_argument('--force', '-f', action='store_true')
parse_parser.add_argument('--debug', '-d', action='store_true')

# build
build_parser.add_argument('--version', action='store')
build_parser.add_argument('--action', '-a', action='store')
build_parser.add_argument('--force', '-f', action='store_true')
build_parser.add_argument('--debug', '-d', action='store_true')

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

# get source list
if args.commands == "dependancy":
    sources_sorted_by_dependency(True)
    sys.exit(0)
else:
    all_source = sources_sorted_by_dependency()

sources = None
if hasattr(args, 'sources') and args.sources:
    sources = args.sources.split(" ")
    if len(sources) == 1:
        sources = args.sources.split(",")
else:
    sources = all_source

# get build list
all_build = map(lambda x: x['name'], config_build)
build_actions = None
if hasattr(args, 'action') and args.action:
    build_actions = args.action.split(" ")
    if len(build_actions) == 1:
        build_actions = args.action.split(",")
else:
    build_actions = all_build

sources_directory = os.path.join(os.getcwd(), "Sources")
parses_directory = os.path.join(os.getcwd(), "Parsed")
build_directory = os.path.join(os.getcwd(), "Build")

if not os.path.isdir(sources_directory):
    print("Directory %s is missing." % (sources_directory), file=sys.stderr)
    sys.exit(1)

if not os.path.isdir(parses_directory):
    print("directory %s is missing" % (parses_directory), file=sys.stderr)
    sys.exit(1)

if not os.path.isdir(build_directory):
    print("directory %s is missing" % (build_directory), file=sys.stderr)
    sys.exit(1)

if args.commands == "status":
    status(sources_directory, parses_directory, build_directory)
    sys.exit(0)

if args.commands == "download":
    success_status = download_sources(sources_directory, sources)
    status(sources_directory, parses_directory, None)
    sys.exit(success_status)
    
if args.commands == "parse":
    success_status = parse_sources(parses_directory, sources, sources_directory)
    status(sources_directory, parses_directory, None)
    sys.exit(success_status)
    
if args.commands == "build":
    if not args.version:
        print("m5nr version is missing", file=sys.stderr)
        sys.exit(1)
    success_status = build_m5nr(build_directory, build_actions)
    status(sources_directory, parses_directory, build_directory)
    sys.exit(success_status)

print("this should not happen")
sys.exit(1)
