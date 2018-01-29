#!/usr/bin/python -u

import os
import sys
import json
import argparse

"""
Input files, md5 per line in each file match.
Input is sorted by md5, may have mutliple line with same md5.

md52id.txt (required)
md52func.txt or id2func.txt
md52taxid.txt

Output line:

md5 : {
    accession: [ text ],
    function: [ text ],
    taxid: [ int ]
}

Output file:

md52annotation.txt

"""

IDFILE   = 'md52id.txt'
FUNCFILE = 'md52func.txt'
FIDFILE  = 'id2func.txt'
TAXFILE  = 'md52taxid.txt'
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
    args = parser.parse_args()
    
    if not os.path.isfile(IDFILE):
        sys.stderr.write("missing required file: %s\n"%(IDFILE))
        return 1
        
    idFuncMap = {}
    if (not os.path.isfile(FUNCFILE)) and os.path.isfile(FIDFILE):
        print "loading "+FIDFILE
        idFuncMap = loadFunc(FIDFILE)
    
    ihdl = open(IDFILE)
    fhdl = open(FUNCFILE) if os.path.isfile(FUNCFILE) else None
    thdl = open(TAXFILE) if os.path.isfile(TAXFILE) else None
    ohdl = open(OUTFILE, 'w')
    curr = None
    data = emptyData()
    
    for line in ihdl:
        (md5, srcId) = line.strip().split("\t")
        hasIdFunc = True if srcId in idFuncMap else False
        
        if curr is None:
            curr = md5
        if curr != md5:
            # process batch
            ohdl.write("%s\t%s\n"%(curr, json.dumps(data, separators=(',',':'), sort_keys=True)))
            curr = md5
            data = emptyData()
        
        data['accession'].append(srcId)
        if hasIdFunc:
            data['function'].append(idFuncMap[srcId])
        
        if fhdl:
            (fmd5, func) = fhdl.next().strip().split("\t")
            if fmd5 == md5:
                data[fmd5]['function'].append(func)
        
        if thdl:
            (tmd5, tid) = thdl.next().strip().split("\t")
            if tmd5 == md5:
                data[tmd5]['taxid'].append(tid)
    
    if len(data) > 0:
        ohdl.write("%s\t%s\n"%(curr, json.dumps(data, separators=(',',':'), sort_keys=True)))
    
    ohdl.close()
    ihdl.close()
    if fhdl:
        fhdl.close()
    if thdl:
        thdl.close()
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
