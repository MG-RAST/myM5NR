#!/usr/bin/env python

import os
import sys
import json
import yaml
import argparse
from datetime import datetime
from nested_dict import nested_dict

FUNC_HIER_FILE = 'id2hierarchy.txt'

def buildTree(fname, skipdash=False):
    aTree = nested_dict()
    hdl  = open(fname, 'r')
    for i, line in enumerate(hdl):
        cols = line.strip().split('\t')
        cid = cols.pop(0)
        if skipdash:
            cols = filter(lambda x: x != '-', cols)
        else:
            cols = map(lambda x: 'null' if x == '-' else x, cols)
        if len(cols) == 0:
            continue
        branch = {'id': cid, 'depth': len(cols)}
        for c in reversed(cols):
            branch = {c: branch}
        aTree.update(nested_dict(branch))
    hdl.close()
    return aTree.to_dict(), i

def buildMap(fname, skipdash=False):
    aMap = {}
    hdl  = open(fname, 'r')
    for i, line in enumerate(hdl):
        cols = line.strip().split('\t')
        cid = cols.pop(0)
        if skipdash:
            cols = filter(lambda x: x != '-', cols)
        else:
            cols = map(lambda x: None if x == '-' else x, cols)
        if len(cols) == 0:
            continue
        aMap[cid] = cols
    hdl.close()
    return aMap, i
        

def main(args):
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", dest="input", default=None, help="input file, depends on type")
    parser.add_argument("--type", dest="type", default=None, help="hierarchy type to parse: taxonomy or functional")
    parser.add_argument("--output", dest="output", default=None, help="output file prefix, will create <output>.<format>.json")
    parser.add_argument("--format", dest="format", default='both', help="output format, one of: 'tree', 'map', 'both'")
    parser.add_argument("--parsedir", dest="parsedir", default="../", help="Directory containing parsed source dirs")
    args = parser.parse_args()
    
    if not (args.input and os.path.isfile(args.input)):
        parser.error("missing input")
    if not args.type:
        parser.error("missing hierarchy type")
    if not args.output:
        parser.error("missing output")
    if not os.path.isdir(args.parsedir):
        parser.error("invalid dir for parsed source dirs")
    
    hierTree = {}
    hierMap  = {}
    
    # parse just a single file
    if args.type == 'taxonomy':
        print "start reading %s: %s"%(args.input, str(datetime.now()))
        if (args.format == 'both') or (args.format == 'tree'):
            hierTree, count = buildTree(args.input, True)
        if (args.format == 'both') or (args.format == 'map'):
            hierMap, count = buildMap(args.input, True)
        print "done reading: "+str(datetime.now())
        print "processed %d taxa"%(count)
        
    # find a list of files to parse and merge
    elif args.type == 'functional':
        # parse sources
        sourceInfo = yaml.load(open(args.input, 'r'))
        fhSrcs = set()
        for src in sourceInfo.iterkeys():
            if sourceInfo[src]['type'] == 'hierarchical function annotation':
                fhSrcs.add(src)
        if len(fhSrcs) == 0:
            sys.stderr.write("missing functional hierarchies in %s\n"%(args.sources))
        
        for source in fhSrcs:
            print "start reading %s: %s"%(source, str(datetime.now()))
            fname = os.path.join(args.parsedir, source, FUNC_HIER_FILE)
            if (args.format == 'both') or (args.format == 'tree'):
                subTree, count = buildTree(fname, False)
                hierTree[source] = subTree
            if (args.format == 'both') or (args.format == 'map'):
                subMap, count = buildMap(fname, False)
                hierMap[source] = subMap
            print "done reading: "+str(datetime.now())
            print "processed %d branches for %s"%(count, source)
        
    else:
        parser.error("invalid hierarchy type")
    
    if hierTree:
        json.dump(hierTree, open(args.output+'.tree.json', 'w'))
    if hierMap:
        json.dump(hierMap, open(args.output+'.map.json', 'w'))
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
