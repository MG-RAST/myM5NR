#!/usr/bin/python -u

import os
import sys
import json
import yaml
import bsddb
import plyvel
import argparse
from datetime import datetime

"""
Input levelDB record:

md5 : {
  is_aa: bool,
  lca: [ text ],  # optional
  lcaid: int      # optional
  ann: [
    {
      source: text,
      accession: [ text ],
      function: [ text ],  # optional
      organism: [ text ],  # optional
      funid: [ int ],      # optional
      taxid: [ int ]       # optional
    }
  ]
}

Output berkelyDB record:
Note: this is backwards compatible with old bdb format used in sims_annotate.pl

md5 : {
  'lca' : [ text ],  # optional
  'ann' : {
    source_id : true
  }
},
'source' : {
  source_id : [ source_name, source_type ]
}
"""

def main(args):
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", dest="sources", default=None, help="sources.yaml file")
    parser.add_argument("--db", dest="db", default=None, help="DB dir path")
    parser.add_argument("--output", dest="output", default=None, help="output prefix for files")
    args = parser.parse_args()
    
    if not args.output:
        parser.error("missing output prefix")
    if not os.path.isfile(args.sources):
        parser.error("missing sources.yaml file")
    if not os.path.isdir(args.db):
        parser.error("invalid dir for leveldb")
    
    # get source info
    print "start reading %s: %s"%(args.sources, str(datetime.now()))
    count   = 0
    srcIDs  = {} # { src_name : src_id }
    srcData = {} # { src_id : [ src_name, src_type ] }
    srcInfo = yaml.load(open(args.sources, 'r'))
    for src in srcInfo.iterkeys():
        count += 1
        stype = srcInfo[src]['category']
        if (srcInfo[src]['category'] == 'protein') and (srcInfo[src]['type'] == 'hierarchical function annotation'):
            stype = 'ontology'
        srcData[str(count)] = [src, stype]
        srcIDs[src] = str(count)
    print "done reading: "+str(datetime.now())
    print "processed %d sources"%(count)
    
    # get bdb file, insert data
    try:
        bdb = bsddb.hashopen(args.output, 'c')
    except:
        sys.stderr.write("unable to open DB at %s\n"%(args.output))
        return 1
    bdb['source'] = json.dumps(srcData, separators=(',',':'))
    
    # lca from levelDB
    try:
        ldb = plyvel.DB(args.db)
    except:
        sys.stderr.write("unable to open DB at %s\n"%(args.db))
        return 1
    
    print "start reading %s: %s"%(args.db, str(datetime.now()))
    count = 0
    for key, value in ldb:
        count += 1
        bigdata = json.loads(value)
        smalldata = { 'lca' : [], 'ann' : {} }
        if 'lca' in bigdata:
            smalldata['lca'] = bigdata['lca']
        for ann in bigdata['ann']:
            if ann['source'] in srcIDs:
                smalldata['ann'][ srcIDs[ann['source']] ] = True
        bdb[key] = json.dumps(smalldata, separators=(',',':'))
    print "done reading: "+str(datetime.now())
    print "processed %d md5s"%(count)
    
    ldb.close()
    bdb.close()
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
