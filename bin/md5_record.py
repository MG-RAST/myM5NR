#!/usr/bin/env python

import os
import sys
import json
import leveldb
import argparse

def main(args):
    global taxa, root
    parser = argparse.ArgumentParser()
    parser.add_argument('md5', default=None, help='md5 to lookup in LevelDB')
    parser.add_argument("-d", "--db", dest="db", default=".", help="Directory to store LevelDB, default CWD")
    args = parser.parse_args()
    
    if not args.md5:
        parser.error("missing md5")
    if not os.path.isdir(args.db):
        parser.error("invalid dir for LevelDB")
        
    try:
        db = leveldb.LevelDB(args.db)
    except:
        sys.stderr.write("unable to open LevelDB at %s\n"%(args.db))
        return 1
    
    try:
        val = json.loads(db.Get(args.md5))
        print json.dumps(val, sort_keys=True, indent=4)
    except KeyError:
        print "md5 %s is not in %s"%(args.md5, args.db)
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))