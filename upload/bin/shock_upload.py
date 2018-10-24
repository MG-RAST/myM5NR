#!/usr/bin/python -u

import os
import sys
import json
import yaml
import argparse
import requests
import cStringIO
from datetime import datetime
from requests_toolbelt import MultipartEncoder

URL  = ''
AUTH = ''
DATE = datetime.now().date().isoformat()
TEMPLATE = "An exception of type {0} occured. Arguments:\n{1!r}"

def upload(filename, filepath, attr):
    data = {
        'upload': (filename, open(filepath)),
        'attributes': ('unknown', cStringIO.StringIO(attr))
    }
    mdata = MultipartEncoder(fields=data)
    headers = {'Content-Type': mdata.content_type}
    if AUTH:
        headers['Authorization'] = AUTH
    try:
        req = requests.post(URL+'/node', headers=headers, data=mdata, allow_redirects=True)
        rj  = req.json()
    except Exception as ex:
        message = TEMPLATE.format(type(ex).__name__, ex.args)
        raise Exception(u'Unable to connect to Shock server %s\n%s' %(URL, message))
    if not (req.ok):
        raise Exception(u'Unable to connect to Shock server %s: %s' %(URL, req.raise_for_status()))
    if rj['error']:
        raise Exception(u'Shock error %s: %s'%(rj['status'], rj['error'][0]))
    return rj['data']

def public(nid):
    headers = {}
    if AUTH:
        headers['Authorization'] = AUTH
    try:
        req = requests.put("%s/node/%s/acl/public_read"%(URL, nid), headers=headers)
        rj  = req.json()
    except Exception as ex:
        message = TEMPLATE.format(type(ex).__name__, ex.args)
        raise Exception(u'Unable to connect to Shock server %s\n%s' %(URL, message))
    if not (req.ok):
        raise Exception(u'Unable to connect to Shock server %s: %s' %(URL, req.raise_for_status()))
    if rj['error']:
        raise Exception(u'Shock error %s: %s'%(rj['status'], rj['error'][0]))

def main(args):
    global URL, AUTH
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", dest="name", default=None, help="specific name in --type to upload, default is all")
    parser.add_argument("--type", dest="type", default=None, help="upload type: one of source, parsed, build")
    parser.add_argument("--dir", dest="dir", default=None, help="base dir to search through")
    parser.add_argument("--token", dest="token", default=None, help="auth token")
    parser.add_argument("--config", dest="config", default=None, help="upload.yaml file")
    parser.add_argument("--version", dest="version", default=None, help="version to apply to attributes")
    args = parser.parse_args()
    
    if not os.path.isfile(args.config):
        parser.error("missing config file (upload.yaml)")
    if not args.type:
        parser.error("missing upload type")
    if not os.path.isdir(args.dir):
        parser.error("invalid base dir")
    
    configInfo = yaml.load(open(args.config, 'r'))
    if args.type not in configInfo:
        parser.error("invalid upload type: "+args.type)
    
    static = configInfo['static']
    upInfo = configInfo['upload-info']
    toUpload = configInfo[args.type]
    
    URL = upInfo['shock-url']
    if args.token:
        AUTH = upInfo['bearer']+' '+args.token
    
    for name in toUpload.keys():
        path = os.path.join(args.dir, name)
        if not os.path.isdir(path):
            print "[warning] "+path+" does not exist, skipping"
            continue
        for data in toUpload[name]:
            # if using --name option
            if args.name and (args.name != data['name']):
                continue
            # extract filepath
            if 'file' not in data:
                continue
            filename = data['file']
            filepath = os.path.join(path, filename)
            del data['file']
            # get optional stats
            if 'stats' in data:
                statsfile = os.path.join(path, data['stats'])
                data['stats'] = json.load(open(statsfile, 'r'))
            # add variable info
            data.update(static)
            data['created'] = DATE
            data['version'] = args.version
            # upload and make public
            node = upload(filename, filepath, json.dumps(data))
            public(node['id'])
            print "%s\t%s\t%d\t%s"%(name, filename, node['file']['size'], node['id'])
    return 0
    

if __name__ == "__main__":
    sys.exit(main(sys.argv))
