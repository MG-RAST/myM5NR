#!/usr/bin/env python

import os
import sys
import json
import itertools
import argparse

def parseGreengenes(taxa):
    i = taxa.index('k__')
    return taxa[:i].strip()

def parseSILVA(taxa):
    parts = taxa.split(';')
    return parts[-1].strip()

def mapByLabel(nodes):
    lableMap = {}
    for k, v in nodes.iteritems():
        lableMap[v['label']] = k
    return lableMap

def main(args):
    global taxa, root
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input", dest="input", default=None, help="input file: md5 \\t taxa string")
    parser.add_argument("-o", "--output", dest="output", default=None, help="output file: md5 \\t taxid")
    parser.add_argument("-t", "--taxa", dest="taxa", default=None, help="json format taxonomy file")
    parser.add_argument("-f", "--format", dest="format", default=None, help="one of: Greengenes, SILVA")
    args = parser.parse_args()
    
    if not (args.input and os.path.isfile(args.input)):
        parser.error("missing input")
    if not (args.taxa and os.path.isfile(args.taxa)):
        parser.error("missing taxa")
    if not args.output:
        parser.error("missing output")
        
    if args.format == 'Greengenes':
        taxaParser = parseGreengenes
    elif args.format == 'SILVA':
        taxaParser = parseSILVA
    else:
        parser.error("missing format")
    
    taxaId = json.load(open(args.taxa, 'r'))
    taxaStr = mapByLabel(taxaId)
    ihdl = open(args.input, 'r')
    ohdl = open(args.output, 'w')
    mnum = 0
    tnum = 0
    
    for line in ihdl:
        parts = line.strip().split("\t")
        if len(parts) != 2:
            continue
        (md5, taxa) = parts
        mnum += 1
        name = taxaParser(taxa)
        tid = None
        if name in taxaStr:
            tid = taxaStr[name]
        else:
            nameParts = name.split()
            if nameParts > 1:
                # try species
                species = nameParts[0]+' '+nameParts[1]
                if species in taxaStr:
                    tid = taxaStr[species]
            if not tid:
                # try genus
                if nameParts[0] in taxaStr:
                    tid = taxaStr[nameParts[0]]
        if tid:
            tnum += 1
            ohdl.write("%s\t%s\n"%(md5, tid))
    
    print "Found %d taxIDs for %d md5sums"%(tnum, mnum)
    ihdl.close()
    ohdl.close()
    return 0
        

if __name__ == "__main__":
    sys.exit(main(sys.argv))