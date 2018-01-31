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
Files required:

--taxa Parsed/NCBI-Taxonomy/taxonomy.json
--func Parsed/M5functions/id2func.txt
--lca Parsed/M5lca/md52lca.txt

File processed from Source dir:

md52annotation.txt

Output record:

md5 : {
  is_aa: bool,
  lca: [ text ],
  lcaid: int
  ann: [
    {
      source: text,
      accession: [ text ],
      function: [ text ],
      organism: [ text ],
      funid: [ int ],
      taxid: [ int ]
    }
  ]
}
"""

ANNFILE = 'md52annotation.txt'
TaxaMap = {}
FuncMap = {}
Sources = [] # name, filehdl
SrcSize = 0
IsProtein = True
IsLevelDB = True

def loadFunc(ffile):
    func = {}
    fhdl = open(ffile)
    for line in fhdl:
        parts = line.strip().split("\t")
        if len(parts) != 2:
            continue
        (fid, name) = parts
        func[name] = int(fid)
    fhdl.close()
    return func

def mergeAnn(md5, info, lca):
    data = {
        'is_aa' : IsProtein,
        'ann' : []
    }
    if lca[0] == md5:
        data['lcaid'] = lca[1]
        data['lca'] = lca[2]
    for i in range(SrcSize):
        if info[i][0] == md5:
            d = copy.deepcopy(info[i][1])
            d['source'] = Sources[i][0]
            if 'function' in d:
                d['funid'] = map(lambda f: FuncMap[f], d['function'])
            if 'taxid' in d:
                d['organism'] = map(lambda t: TaxaMap[str(t)]['label'], d['taxid'])
            data['ann'].append(d)
    return data

def nextLCA(fhdl):
    try:
        line = fhdl.next()
        parts = line.strip().split("\t")
        annData = json.loads(ann)
        return [ parts[0], parts[1], filter(lambda x: x != '-', parts[2].split(";")) ]
    except StopIteration:
        return [ None, None, None ]

def nextSet(fhdl):
    try:
        line = fhdl.next()
        (md5, ann) = line.strip().split("\t")
        return [ md5, json.loads(ann) ]
    except StopIteration:
        return [ None, None ]

def getMinMd5(info):
    md5s = map(lambda x: x[0], info)
    md5sort = sorted(filter(lambda x: x is not None, md5s))
    return md5sort[0]

def moreSets(info):
    hasSet = False
    for i in info:
        if i[0] is not None:
            hasSet = True
    return hasSet

def main(args):
    global TaxaMap, FuncMap, Sources, SrcSize, IsProtein, IsLevelDB
    parser = argparse.ArgumentParser()
    parser.add_argument("-t", "--taxa", dest="taxa", default=None, help="json format taxonomy file for name-id mapping")
    parser.add_argument("-f", "--func", dest="func", default=None, help="tsv format function file for name-id mapping")
    parser.add_argument("-l", "--lca", dest="lca", default=None, help="tsv format lca file for md5-lca mapping")
    parser.add_argument("-s", "--source", dest="source", default=None, help="list of sources to merge")
    parser.add_argument("--srctype", dest="srctype", default=None, help="source type, one of: rna or protein")
    parser.add_argument("-d", "--db", dest="db", default=None, help="DB path")
    parser.add_argument("--dbtype", dest="dbtype", default="berkeleyDB", help="DB type, one of: berkeleyDB or levelDB")
    parser.add_argument("--parsedir", dest="parsedir", default="../", help="Directory containing parsed source dirs")
    args = parser.parse_args()
    
    if not (args.taxa and os.path.isfile(args.taxa)):
        parser.error("missing taxa")
    if not (args.func and os.path.isfile(args.func)):
        parser.error("missing func")
    if not (args.lca and os.path.isfile(args.lca)):
        parser.error("missing lca")
    if not args.source:
        parser.error("missing source")
    if (args.srctype != 'rna') and (args.srctype != 'protein'):
        parser.error("invalid source type")
    if (args.dbtype != 'berkeleyDB') and (args.dbtype != 'levelDB'):
        parser.error("invalid DB type")
    if (args.dbtype == 'levelDB') and (not os.path.isdir(args.db)):
        parser.error("invalid dir for levelDB")
    if (args.dbtype == 'berkeleyDB') and (not os.path.isfile(args.db)):
        parser.error("invalid file for berkeleyDB")
    if not os.path.isdir(args.parsedir):
        parser.error("invalid dir for parsed source dirs")
    
    IsProtein = True if args.dbtype == 'protein' else False
    IsLevelDB = True if args.dbtype == 'levelDB' else False
    
    print "start opening files: "+str(datetime.now())
    for src in args.source.split(","):
        annFile = os.path.join(args.parsedir, src, ANNFILE)
        if os.path.isfile(annFile):
            print "opening "+annFile
            Sources.append([src, open(annFile, 'r')])
    SrcSize = len(Sources)
    
    print "loading taxonomy map"
    TaxaMap = json.load(open(args.taxa, 'r'))
    print "loading function map"
    FuncMap = loadFunc(args.func)
    
    print "loading "+args.dbtype
    try:
        if isLevelDB:
            db = plyvel.DB(args.db, create_if_missing=True)
        else:
            db = bsddb.hashopen(args.db, 'c')
    except:
        sys.stderr.write("unable to open DB at %s\n"%(args.db))
        return 1
    
    mCount  = 0
    lcaHdl  = open(args.lca, 'r')
    lcaSet  = nextLCA(lcaHdl)
    allSets = map(lambda x: nextSet(x[1]), Sources)
    
    print "start parsing source files / load DB: "+str(datetime.now())
    while moreSets(allSets):
        # get minimal md5
        minMd5 = getMinMd5(allSets)
        mCount += 1
        # insert the data
        annData = mergeAnn(minMd5, allSets, lcaSet)
        if IsLevelDB:
            db.put(minMd5, json.dumps(annData))
        else:
            db[minMd5] = json.dumps(annData)
        # iterate files that had minimal
        if lcaSet[0] == minMd5:
            lcaSet = nextLCA(lcaHdl)
        for i in range(SrcSize):
            if allSets[i][0] == minMd5:
                allSets[i] = nextSet(Sources[i][1])
    
    db.close()
    lcaHdl.close()
    for src in Sources:
        src[1].close()
    
    print "done parsing / loading: "+str(datetime.now())
    print "%d md5 annotations loaded to %s"%(mCount, args.db)
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
