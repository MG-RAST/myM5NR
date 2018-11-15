#!/usr/bin/python -u

import os
import sys
import json
import yaml
import pickle
import tarfile
import argparse
from httplib2 import Http
from urllib import urlencode

URL   = ''
AUTH  = ''
VERB  = False
BATCH = 50 * 1024

def apiPost(fullurl, pdata):
    if VERB and ('data' in pdata):
        print "table: %s, version: %s, data: len %d size %d"%(pdata['table'], pdata['version'], len(pdata['data']), len(json.dumps(pdata['data']).encode('utf-8')))
    headers = {'Content-Type': 'application/json'}
    if AUTH:
        headers['Authorization'] = AUTH
    h = Http()
    resp, content = h.request(fullurl, "POST", body=json.dumps(pdata), headers=headers)
    rj = json.loads(content)
    # error check
    if ('ERROR' in rj) or (('error' in rj) and (rj['error'] != "")) or (('status' in rj) and (rj['status'] != 'success')):
        # maybe data issue, try and split first
        if ('data' in pdata) and (len(pdata['data']) > 1):
            splitPost(fullurl, pdata)
        else:
            sys.stderr.write("error POSTing data:\n%s\n"%(json.dumps(rj, sort_keys=True, indent=4, separators=(',', ': '))))
            sys.exit(1)

def splitPost(fullurl, pdata):
    if VERB:
        print "splitting: table %s, data %d"%(pdata['table'], len(pdata['data']))
    half = len(pdata['data']) / 2
    apiPost(fullurl, {
        'version': pdata['version'],
        'table': pdata['table'],
        'data': pdata['data'][:half]
    })
    apiPost(fullurl, {
        'version': pdata['version'],
        'table': pdata['table'],
        'data': pdata['data'][half:]
    })

def createM5nr(version):
    apiPost(URL+'/m5nr/cassandra/create', {'version': int(version)})

def uploadData(version, table, data):
    apiPost(URL+'/m5nr/cassandra/insert', {
        'version': int(version),
        'table': table,
        'data': data
    })

def pickleIter(fname):
    with open(fname, "rb") as f:
        while True:
            try:
                yield pickle.load(f)
            except EOFError:
                break

def uploadFile(fname, version):
    table = os.path.basename(fname)
    if table.startswith('m5nr.'):
        table = table[5:]
    
    data = []
    for row in pickleIter(fname):
        data.append(row)
        if len(json.dumps(data).encode('utf-8')) > BATCH:
            if len(data) == 1:
                uploadData(version, table, data)
                data = []
            else:
                data.pop()
                uploadData(version, table, data)
                data = [row]
    if len(data) > 0:
        uploadData(version, table, data)

def main(args):
    global URL, AUTH, VERB
    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--dir", dest="dir", default=None, help="base dir to upload / download in")
    parser.add_argument("-i", "--input", dest="input", default=None, help="input file path or shock url")
    parser.add_argument("-n", "--is_node", dest="is_node", default=False, action="store_true", help="input is shock node")
    parser.add_argument("-t", "--token", dest="token", default=None, help="auth token")
    parser.add_argument("-c", "--config", dest="config", default="/myM5NR/upload.yaml", help="upload.yaml file")
    parser.add_argument("-v", "--version", dest="version", default=None, help="version to apply to attributes")
    parser.add_argument("--verbose", dest="verbose", default=False, action="store_true", help="lots of text")
    args = parser.parse_args()
    
    if not os.path.isfile(args.config):
        parser.error("missing config file (upload.yaml)")
    
    configInfo = yaml.load(open(args.config, 'r'))
    upInfo = configInfo['upload-info']
    URL = upInfo['api-url']
    
    if args.verbose:
        VERB = True
    
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
    
    print "creating schema for m5nr_v"+args.version
    createM5nr(args.version)
    
    # extract and upload file rows
    for f in reversed(os.listdir(extractDir)):
        fname = os.path.join(extractDir, f)
        if not os.path.isfile(fname):
            continue
        print "uploading "+fname
        uploadFile(fname, args.version)
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
