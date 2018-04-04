#!/usr/bin/python -u

import os
import sys
import json
import yaml
import copy
import plyvel
import argparse
from datetime import datetime

"""
------- Inputs -------

Files required:

--taxa Parsed/NCBI-Taxonomy/taxonomy.json
--func Parsed/M5functions/id2func.txt
--lca Parsed/M5lca/md52lca.txt

File processed from Source dir:

md52annotation.txt

------- Outputs: levelDB records -------

Full:

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

Minimal:

md5 : {
  lca : [ text ],  # optional
  sources : [ text ]
}
"""

BATCHSIZE = 10000
ANNFILE = 'md52annotation.txt'
TaxaMap = {}
FuncMap = {}
Sources = [] # name, filehdl, is_prot bool
SrcSize = 0

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
    data = { 'ann' : [] }
    if (lca[0] == md5) and (len(lca[2]) > 0):
        data['lcaid'] = lca[1]
        data['lca'] = lca[2]
    for i in range(SrcSize):
        if info[i][0] == md5:
            d = copy.deepcopy(info[i][1])
            d['source'] = Sources[i][0]
            data['is_aa'] = Sources[i][2]
            if ('function' in d) and FuncMap:
                if 'funid' not in d:
                    d['funid'] = []
                for f in d['function']:
                    if f not in FuncMap:
                        print "[warning] function %s missing for %s %s"%(f, Sources[i][0], md5)
                    else:
                        d['funid'].append(FuncMap[f])
            if ('taxid' in d) and TaxaMap:
                if 'organism' not in d:
                    d['organism'] = []
                for t in d['taxid']:
                    if str(t) not in TaxaMap:
                        print "[warning] taxonomy %d missing for %s %s"%(t, Sources[i][0], md5)
                    else:
                        d['organism'].append(TaxaMap[str(t)]['label'])
            data['ann'].append(d)
    return data

def minFromFull(fullData):
    minData = {}
    minData['sources'] = map(lambda x: x['source'], fullData['ann'])
    if 'lca' in fullData:
        minData['lca'] = fullData['lca']
    return minData

def mergeMd5Sources(oldAnn, annData):
    newData = copy.deepcopy(oldAnn)
    currSources = map(lambda x: x['source'], newData['ann'])
    for ann in annData['ann']:
        if ann['source'] not in currSources:
            newData['ann'].append(ann)
    return newData

def mergeMd5SourcesMin(oldMin, minData):
    newMin = copy.deepcopy(oldMin)
    sources = set(newMin['sources'])
    sources.union(set(minData['sources']))
    newMin['sources'] = list(sources)
    return newMin

def nextLCA(fhdl):
    if not fhdl:
        return [ None, None, None ]
    try:
        line = fhdl.next()
        parts = line.strip().split("\t")
        return [ parts[0], parts[1], filter(lambda x: x != '-', parts[2].split(";")) ]
    except StopIteration:
        return [ None, None, None ]

def nextSet(fhdl):
    if not fhdl:
        return [ None, None ]
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
    global TaxaMap, FuncMap, Sources, SrcSize
    parser = argparse.ArgumentParser()
    parser.add_argument("--taxa", dest="taxa", default=None, help="json format taxonomy file for name-id mapping")
    parser.add_argument("--func", dest="func", default=None, help="tsv format function file for name-id mapping")
    parser.add_argument("--lca", dest="lca", default=None, help="tsv format lca file for md5-lca mapping")
    parser.add_argument("--sources", dest="sources", default=None, help="sources.yaml file")
    parser.add_argument("--db_full", dest="dbfull", default='m5nr-full.ldb', help="DB path")
    parser.add_argument("--db_min", dest="dbmin", default='m5nr-min.ldb', help="DB path")
    parser.add_argument("--parsedir", dest="parsedir", default="../", help="Directory containing parsed source dirs")
    parser.add_argument("--append", dest="append", action="store_true", default=False, help="add new sources to existing md5s in DB, default is to overwrite")
    args = parser.parse_args()
    
    if not os.path.isfile(args.sources):
        parser.error("missing sources.yaml file")
    if not os.path.isdir(args.dbfull):
        parser.error("invalid dir for full M5NR levelDB")
    if not os.path.isdir(args.dbmin):
        parser.error("invalid dir for minimal M5NR levelDB")
    if not os.path.isdir(args.parsedir):
        parser.error("invalid dir for parsed source dirs")
    
    print "start opening files: "+str(datetime.now())
    sourceInfo = yaml.load(open(args.sources, 'r'))
    for src in sourceInfo.iterkeys():
        if sourceInfo[src]['category'] == 'protein':
            isProt = True
        elif sourceInfo[src]['category'] == 'rna':
            isProt = False
        else:
            continue
        annFile = os.path.join(args.parsedir, src, ANNFILE)
        if os.path.isfile(annFile):
            print "opening "+annFile
            Sources.append([src, open(annFile, 'r'), isProt])
    SrcSize = len(Sources)
    
    print "loading taxonomy map"
    TaxaMap = json.load(open(args.taxa, 'r')) if args.taxa else {}
    print "loading function map"
    FuncMap = loadFunc(args.func) if args.func else {}
    
    try:
        dbfull = plyvel.DB(args.dbfull, create_if_missing=True)
    except:
        sys.stderr.write("unable to open DB at %s\n"%(args.dbfull))
        return 1
    try:
        dbmin = plyvel.DB(args.dbmin, create_if_missing=True)
    except:
        sys.stderr.write("unable to open DB at %s\n"%(args.dbmin))
        return 1
    
    mCount  = 0
    lcaHdl  = open(args.lca, 'r') if args.lca else None
    lcaSet  = nextLCA(lcaHdl)
    allSets = map(lambda x: nextSet(x[1]), Sources)
    wbfull  = dbfull.write_batch()
    wbmin   = dbmin.write_batch()
    
    print "start parsing source files / load DB: "+str(datetime.now())
    while moreSets(allSets):
        # get minimal md5
        minMd5 = getMinMd5(allSets)
        mCount += 1
        # merge across sources
        annData = mergeAnn(minMd5, allSets, lcaSet)
        minData = minFromFull(annData)
        if args.append:
            # merge source data with DB data
            oldAnn = dbfull.get(minMd5)
            if oldAnn:
                annData = mergeMd5Sources(oldAnn, annData)
            oldMin = dbmin.get(minMd5)
            if oldMin:
                minData = mergeMd5SourcesMin(oldMin, minData)
        # insert the data
        wbfull.put(minMd5, json.dumps(annData, separators=(',',':')))
        wbmin.put(minMd5, json.dumps(minData, separators=(',',':')))
        if (mCount % BATCHSIZE) == 0:
            wbfull.write()
            wbmin.write()
            wbfull = dbfull.write_batch()
            wbmin  = dbmin.write_batch()
        if (mCount % (BATCHSIZE * 100)) == 0:
            sys.stdout.write(".")
        # iterate files that had minimal
        if lcaSet[0] == minMd5:
            lcaSet = nextLCA(lcaHdl)
        for i in range(SrcSize):
            if allSets[i][0] == minMd5:
                allSets[i] = nextSet(Sources[i][1])
    
    wbfull.write()
    wbmin.write()
    sys.stdout.write(".\n")
    dbfull.close()
    dbmin.close()
    lcaHdl.close()
    for src in Sources:
        src[1].close()
    
    print "done parsing / loading: "+str(datetime.now())
    print "%d md5 annotations loaded to %s / %s"%(mCount, args.dbfull, args.dbmin)
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
