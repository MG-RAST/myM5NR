#!/usr/bin/python -u

import os
import sys
import json
import argparse

"""
Input files, md5 per line in each file match.
Input is sorted by md5, may have mutliple line with same md5.

md52id.sort.txt (required)
md52func.sort.txt or id2func.txt
md52taxid.sort.txt

Output line:

md5 : {
    accession: [ text ],
    function: [ text ],
    taxid: [ int ]
}

Output file:

md52annotation.txt

"""

IDFILE   = 'md52id.sort.txt'
FUNCFILE = 'md52func.sort.txt'
FIDFILE  = 'id2func.txt'
TAXFILE  = 'md52taxid.sort.txt'
OUTFILE  = 'md52annotation.txt'

def emptyData():
    return {
        'accession': [],
        'function': [],
        'taxid': []
    }

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
    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--dir", dest="dir", default=".", help="Directory containing md5 sorted files, default is CWD.")
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
        
    idFuncMap = {}
    if (not os.path.isfile(funcFile)) and os.path.isfile(fidFile):
        print "loading "+fidFile
        idFuncMap = loadFunc(fidFile)
    
    ihdl = open(idFile)
    fhdl = open(funcFile) if os.path.isfile(funcFile) else None
    thdl = open(taxFile) if os.path.isfile(taxFile) else None
    ohdl = open(os.path.join(args.dir, OUTFILE), 'w')
    curr = None
    data = emptyData()
    
    mCount = 0
    pFiles = [idFile]
    if fhdl:
        pFiles.append(funcFile)
    if thdl:
        pFiles.append(taxFile)
    print "Parsing: %s\n"%(", ".join(pFiles))
    
    for line in ihdl:
        (md5, srcId) = line.strip().split("\t")
        hasIdFunc = True if srcId in idFuncMap else False
        
        if curr is None:
            curr = md5
        if curr != md5:
            # process batch
            mCount += 1
            ohdl.write("%s\t%s\n"%(curr, json.dumps(data, separators=(',',':'), sort_keys=True)))
            curr = md5
            data = emptyData()
        
        data['accession'].append(srcId)
        if hasIdFunc:
            data['function'].append(idFuncMap[srcId])
        
        if fhdl:
            (fmd5, func) = fhdl.next().strip().split("\t")
            if fmd5 == md5:
                data['function'].append(func)
        
        if thdl:
            (tmd5, tid) = thdl.next().strip().split("\t")
            if tmd5 == md5:
                data['taxid'].append(tid)
    
    if len(data) > 0:
        mCount += 1
        ohdl.write("%s\t%s\n"%(curr, json.dumps(data, separators=(',',':'), sort_keys=True)))
    
    print "Done parsing %d md5s\n"%(mCount)
    ohdl.close()
    ihdl.close()
    if fhdl:
        fhdl.close()
    if thdl:
        thdl.close()
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
