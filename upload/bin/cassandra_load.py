#!/usr/bin/python -u

import os
import sys
import yaml
import pickle
import tarfile
import argparse
import requests

URL  = ''
AUTH = ''
CHUNK = 5000

def apiPost(fullurl, data):
    headers = {}
    if AUTH:
        headers['Authorization'] = AUTH
    res = requests.post(fullurl, headers=headers, data=data, allow_redirects=True)
    rj  = res.json()
    msg = None
    if 'ERROR' in rj:
        msg = rj['ERROR']
    if ('error' in rj) and (rj['error'] != ""):
        msg = rj['error']
    if ('status' in rj) and (rj['status'] != 'success'):
        msg = "unknown problem, status is "+rj['status']
    if msg:
        sys.stderr.write("error POSTing data: %s\n"%(msg))
        sys.exit(1)

def createM5nr(version):
    apiPost(URL+'/m5nr/cassandra/create', {'version': int(version)})

def uploadData(version, table, data):
    pdata = {
        'version': int(version),
        'table': table,
        'data': data
    }
    apiPost(URL+'/m5nr/cassandra/insert', pdata)

def pickleIter(fname):
    with open(fname, "rb") as f:
        while True:
            try:
                yield pickle.load(f)
            except EOFError:
                break

def uploadFile(fname, version):
    table = fname
    if fname.startswith('m5nr.'):
        table = fname[5:]
    
    data = []
    for row in pickleIter(fname):
        if len(data) == CHUNK:
            uploadData(version, table, data)
            data = []
        data.append(row)
    if len(data) > 0:
        uploadData(version, table, data)

def main(args):
    global URL, AUTH
    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--dir", dest="dir", default=None, help="base dir to upload / download in")
    parser.add_argument("-i", "--input", dest="input", default=None, help="input file path or shock url")
    parser.add_argument("-n", "--is_node", dest="is_node", default=False, action="store_true", help="input is shock node")
    parser.add_argument("-t", "--token", dest="token", default=None, help="auth token")
    parser.add_argument("-c", "--config", dest="config", default="/myM5NR/upload.yaml", help="upload.yaml file")
    parser.add_argument("-v", "--version", dest="version", default=None, help="version to apply to attributes")
    args = parser.parse_args()
    
    if not os.path.isfile(args.config):
        parser.error("missing config file (upload.yaml)")
    
    configInfo = yaml.load(open(args.config, 'r'))
    upInfo = configInfo['upload-info']
    URL = upInfo['api-url']
    
    if not args.dir:
        args.dir = upInfo['upload-dir']
    if args.token:
        AUTH = upInfo['bearer']+' '+args.token
    
    if not os.path.isdir(args.dir):
        os.makedirs(args.dir)
    
    filePath = os.path.join(args.dir, 'm5nr.cass.tgz')
    # optional download
    if args.is_node:
        if not os.path.isfile(filePath):
            print "Downloading "+args.input+" from shock"
            res = requests.get(args.input, stream=True)
            res.raise_for_status()
            with open(filePath, 'wb') as handle:
                for block in res.iter_content(1024):
                    handle.write(block)
        else:
            print args.input+" is already downloaded from shock"
    else:
        filePath = args.input
    
    # unpack
    extractDir = os.path.join(args.dir, 'Cassandra')
    if os.path.isdir(extractDir):
        print filePath+" is already extracted into "+extractDir
    else:
        print "extracting "+filePath+" into "+extractDir
        os.makedir(extractDir)
        tar = tarfile.open(filePath, 'r:gz')
        tar.extractall(extractDir)
        tar.close()
    
    createM5nr(args.version)
    
    # extract and upload file rows
    for f in os.listdir(extractDir):
        fname = os.path.join(extractDir, f)
        if not os.isfile(fname):
            continue
        print "uploading "+fname
        uploadFile(fname, args.version)
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
