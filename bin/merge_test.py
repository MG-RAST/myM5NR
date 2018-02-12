#!/usr/bin/python -u

import os
import sys
import json
import copy
import plyvel
import bsddb
import argparse
from datetime import datetime

"""
Output record:

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
"""

def main(args):
    parser = argparse.ArgumentParser()
    parser.add_argument("-k", "--keys", dest="keys", default=None, help="input file with key list, optional")
    parser.add_argument("-o", "--output", dest="output", default=None, help="output file with key list, optional")
    parser.add_argument("-d", "--db", dest="db", default=None, help="DB path")
    parser.add_argument("--dbtype", dest="dbtype", default=None, help="DB type, one of: berkeleyDB or levelDB")
    args = parser.parse_args()
    
    if (args.dbtype != 'berkeleyDB') and (args.dbtype != 'levelDB'):
        parser.error("invalid DB type")
    if (args.dbtype == 'levelDB') and (not os.path.isdir(args.db)):
        parser.error("invalid dir for levelDB")
    if (args.dbtype == 'berkeleyDB') and (not args.db):
        parser.error("invalid file for berkeleyDB")
    
    IsLevelDB = True if args.dbtype == 'levelDB' else False
    
    print "loading "+args.dbtype
    try:
        if IsLevelDB:
            db = plyvel.DB(args.db)
        else:
            db = bsddb.hashopen(args.db, 'r')
    except:
        sys.stderr.write("unable to open DB at %s\n"%(args.db))
        return 1
    
    ohdl = open(args.output, 'w') if args.output else None
    
    print "start reading %s: %s"%(args.db, str(datetime.now()))
    count = 0;
    
    if args.keys and os.path.isfile(args.keys):
        ihdl = open(args.keys, 'r')
        for key in ihdl:
            if IsLevelDB:
                value = db.get(key)
                if value:
                    count += 1
            else:
                if db.has_key(key):
                    count += 1
        ihdl.close()
    else:
        if IsLevelDB:
            for key, value in db:
                if ohdl:
                    ohdl.write(key+"\n")
                count += 1
        else:
            while True:
                try:
                    (key, value) = db.next()
                    if ohdl:
                        ohdl.write(key+"\n")
                    count += 1
                except:
                    break
    
    print "done reading: "+str(datetime.now())
    print "found %d keys"%(count)
    db.close()
    if ohdl:
        ohdl.close()
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
