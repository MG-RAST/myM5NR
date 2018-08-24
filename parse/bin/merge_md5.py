#!/usr/bin/python -u

import os
import sys
import json
import argparse
from collections import defaultdict

"""
Input files, md5 per line in each file match.
Input is sorted by md5, may have mutliple line with same md5.

md52id.sort.txt (required)
md52func.sort.txt or id2func.txt
md52taxid.sort.txt

Output line:

md5 : {
    accession: [ text ],
    function: [ text ],  # optional
    taxid: [ int ]       # optional
}

Output file:

md52annotation.txt

"""

IDFILE   = 'md52id.sort.txt'
FUNCFILE = 'md52func.sort.txt'
FIDFILE  = 'id2func.txt'
TAXFILE  = 'md52taxid.sort.txt'
OUTFILE  = 'md52annotation.txt'
hasFUNC  = False
hasFID   = False
hasTAXA  = False

def emptyData():
    d = {'accession': []}
    if hasFUNC or hasFID:
        d['function'] = []
    if hasTAXA:
        d['taxid'] = []
    return d

def loadFunc(fidfile):
    func = {}
    fhdl = open(fidfile)
    for line in fhdl:
        parts = line.strip().split("\t")
        if len(parts) != 2:
            continue
        (fid, name) = parts
        func[fid] = name
    fhdl.close()
    return func


def main(args):
    global hasFUNC, hasFID, hasTAXA
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", dest="dir", default=".", help="Directory containing md5 sorted files, default is CWD.")
    parser.add_argument("--idonly", dest="idonly", action="store_true", default=False, help="If true keep annotations with only IDs, default is skip them.")
    args = parser.parse_args()
    
    if not os.path.isdir(args.dir):
        parser.error("invalid dir for input files")
    
    idFile   = os.path.join(args.dir, IDFILE)
    funcFile = os.path.join(args.dir, FUNCFILE)
    fidFile  = os.path.join(args.dir, FIDFILE)
    taxFile  = os.path.join(args.dir, TAXFILE)
    
    if not os.path.isfile(idFile):
        sys.stderr.write("missing required file: %s\n"%(idFile))
        return 1
    if os.path.isfile(funcFile):
        hasFUNC = True
    if os.path.isfile(fidFile):
        hasFID = True
    if os.path.isfile(taxFile):
        hasTAXA = True
        
    idFuncMap = {}
    if (not hasFUNC) and hasFID:
        print "loading "+fidFile
        idFuncMap = loadFunc(fidFile)
    
    ihdl = open(idFile)
    fhdl = open(funcFile) if hasFUNC else None
    thdl = open(taxFile) if hasTAXA else None
    ohdl = open(os.path.join(args.dir, OUTFILE), 'w')
    curr = None
    data = defaultdict(list)
    
    mCount = 0
    pFiles = [idFile]
    if hasFUNC:
        pFiles.append(funcFile)
    if hasTAXA:
        pFiles.append(taxFile)
    print "Parsing: %s"%(", ".join(pFiles))
    
    for line in ihdl:
        (md5, srcId) = line.strip().split("\t")
        if curr is None:
            curr = md5
        
        if curr != md5:
            # process batch
            if args.idonly or (len(data) > 1):
                mCount += 1
                ohdl.write("%s\t%s\n"%(curr, json.dumps(data, separators=(',',':'), sort_keys=True)))
            curr = md5
            data = defaultdict(list)
        
        data['accession'].append(srcId)
        
        if hasFUNC:
            (fmd5, func) = fhdl.next().strip().split("\t")
            if fmd5 == md5:
                data['function'].append(func)
        
        if hasFID and (srcId in idFuncMap):
            data['function'].append(idFuncMap[srcId])
        
        if hasTAXA:
            (tmd5, tid) = thdl.next().strip().split("\t")
            if tmd5 == md5:
                data['taxid'].append(int(tid))
    
    if (args.idonly and (len(data) > 0)) or (len(data) > 1):
        mCount += 1
        ohdl.write("%s\t%s\n"%(curr, json.dumps(data, separators=(',',':'), sort_keys=True)))
    
    print "Done parsing %d md5s"%(mCount)
    ohdl.close()
    ihdl.close()
    if hasFUNC:
        fhdl.close()
    if hasTAXA:
        thdl.close()
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
