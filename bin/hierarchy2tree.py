#!/usr/bin/env python

import os
import sys
import json
import yaml
import argparse
from nested_dict import nested_dict
from collections import defaultdict

FUNC_HIER_FILE = 'id2hierarchy.txt'

def buildTree(fname, skipdash=False):
    tree = nested_dict()
    hdl  = open(fname, 'r')
    for i, line in enumerate(hdl):
        cols = line.strip().split('\t')
        cid = cols.pop(0)
        if skipdash:
            cols = filter(lambda x: x != '-', cols)
        else:
            cols = map(lambda x: 'null' if x == '-' else x, cols)
        if cols == 0:
            continue
        branch = cid
        for c in reversed(cols):
            branch = {c: branch}
        tree.update(nested_dict(branch))
    hdl.close()
    return tree.to_dict(), i

def main(args):
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", dest="input", default=None, help="input file, depends on type")
    parser.add_argument("--type", dest="type", default=None, help="hierarchy type to parse: taxonomy or functional")
    parser.add_argument("--output", dest="output", default=None, help="output file name")
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
    
    # parse just a single file
    if args.type == 'taxonomy':
        print "start reading %s: %s"%(args.input, str(datetime.now()))
        hierTree, count = buildTree(args.input, True)
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
            subTree, count = buildTree(fname, False)
            hierTree[source] = subTree
            print "done reading: "+str(datetime.now())
            print "processed %d brances for %s"%(count, source)
        
    else:
        parser.error("invalid hierarchy type")
    
    json.dump(hierTree, open(args.output, 'w'))
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
