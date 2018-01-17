#!/usr/bin/env python

import os
import sys
import json
import leveldb
import argparse

"""
Files required:

--taxa Parsed/NCBI-Taxonomy/taxonomy.json
--func Parsed/M5functions/id2func.txt
--lca Parsed/M5lca/md52lca.txt

Files processed from Source dir:

md52id.txt (required)
md52func.txt
md52taxid.txt

Output record:

md5 : {
  is_aa: bool,
  lca: [ text ],
  single: int
  annotation: [
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

IDFILE   = 'md52id.txt'
FUNCFILE = 'md52func.txt'
TAXFILE  = 'md52taxid.txt'

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

def main(args):
    global taxa, root
    parser = argparse.ArgumentParser()
    parser.add_argument("-t", "--taxa", dest="taxa", default=None, help="json format taxonomy file for name-id mapping")
    parser.add_argument("-f", "--func", dest="func", default=None, help="tsv format function file for name-id mapping")
    parser.add_argument("-l", "--lca", dest="lca", default=None, help="tsv format lca file for md5-lca mapping")
    parser.add_argument("-r", "--rna_source", dest="rna_source", default=None, help="list of rna sources to merge")
    parser.add_argument("-p", "--protein_source", dest="protein_source", default=None, help="list of protein sources to merge")
    parser.add_argument("-d", "--db", dest="db", default=".", help="Directory to store LevelDB, default CWD")
    args = parser.parse_args()
    
    if not (args.taxa and os.path.isfile(args.taxa)):
        parser.error("missing taxa")
    if not (args.func and os.path.isfile(args.func)):
        parser.error("missing func")
    if not os.path.isdir(args.db):
        parser.error("invalid dir for LevelDB")
    
    sources = []
    if args.rna_source:
        for rs in args.rna_source.split(","):
            sources.append((rs, False))
    if args.protein_source:
        for ps in args.protein_source.split(","):
            sources.append((ps, True))
    if len(sources) == 0:
        parser.error("missing sources")
    
    parseDir = os.path.join(os.getcwd(), "Parsed")
    if not os.path.isdir(parseDir):
        sys.stderr.write("directory %s is missing\n"%(parseDir))
        sys.exit(1)
    
    print "loading taxonomy map"
    taxaMap = json.load(open(args.taxa, 'r'))
    print "loading function map"
    funcMap = loadFunc(args.func)
    print "loading levelDB"
    db = leveldb.LevelDB(args.db)
    
    for info in sources:
        (source, isProt) = info
        md5Count = 0
        print "processing source "+source
        sourceDir = os.path.join(parseDir, source)
        if not os.path.isdir(sourceDir):
            sys.stderr.write("source directory %s is missing, skipping\n"%(sourceDir))
            continue
        
        idFile   = os.path.join(sourceDir, IDFILE)
        funcFile = os.path.join(sourceDir, FUNCFILE)
        taxFile  = os.path.join(sourceDir, TAXFILE)
        
        if not os.path.isfile(idFile):
            sys.stderr.write("md52id file %s is missing, skipping\n"%(idFile))
            continue
        
        print "loading "+idFile
        ihdl = open(idFile)
        for line in ihdl:
            parts = line.strip().split("\t")
            if len(parts) != 2:
                continue
            (md5, srcId) = parts
            data = None
            try:
                val = db.Get(md5)
            except KeyError:
    	        val = None
            # test if md5 exists
            if val:
                # modify entry
                data = json.loads(val)
                hasSource = False
                # test if source exists
                for i, a in enumerate(data['annotation']):
                    if a['source'] == source:
                        hasSource = True
                        data['annotation'][i]['accession'].append(srcId)
                if not hasSource:
                    data['annotation'].append({
                        'source': source,
                        'accession': [srcId]
                    })
                data['is_aa'] = isProt
            else:
                # create new entry
                data = {
                    'is_aa': isProt,
                    'annotation': [{
                        'source': source,
                        'accession': [srcId]
                    }]
                }
            if data:
                md5Count += 1
                db.Put(md5, json.dumps(data))
        ihdl.close()
        
        if os.path.isfile(funcFile):
            print "loading "+funcFile
            fhdl = open(funcFile)
            for line in fhdl:
                parts = line.strip().split("\t")
                if len(parts) != 2:
                    continue
                (md5, funcName) = parts
                if funcName not in funcMap:
                    continue
                data = None
                try:
                    val = db.Get(md5)
                except KeyError:
        	        val = None
                # test if md5 exists
                if val:
                    # modify entry
                    data = json.loads(val)
                    for i, a in enumerate(data['annotation']):
                        if a['source'] == source:
                            if 'function' in a:
                                data['annotation'][i]['function'].append(funcName)
                                data['annotation'][i]['funid'].append(funcMap[funcName])
                            else:
                                data['annotation'][i]['function'] = [funcName]
                                data['annotation'][i]['funid'] = [funcMap[funcName]]
                if data:
                    db.Put(md5, json.dumps(data))
            fhdl.close()
        
        if os.path.isfile(taxFile):
            print "loading "+taxFile
            thdl = open(taxFile)
            for line in thdl:
                parts = line.strip().split("\t")
                if len(parts) != 2:
                    continue
                (md5, taxId) = parts
                if taxId not in taxaMap:
                    continue
                data = None
                try:
                    val = db.Get(md5)
                except KeyError:
        	        val = None
                # test if md5 exists
                if val:
                    # modify entry
                    data = json.loads(val)
                    for i, a in enumerate(data['annotation']):
                        if a['source'] == source:
                            if 'organism' in a:
                                data['annotation'][i]['organism'].append(taxaMap[taxId]['label'])
                                data['annotation'][i]['taxid'].append(int(taxId))
                            else:
                                data['annotation'][i]['organism'] = [taxaMap[taxId]['label']]
                                data['annotation'][i]['taxid'] = [int(taxId)]
                if data:
                    db.Put(md5, json.dumps(data))
            thdl.close()
        print "done loading %d md5s for %s"%(md5Count, source)
    
    if args.lca and os.path.isfile(args.lca):
        print "loading LCAs"
        md5Count = 0
        lhdl = open(args.lca)
        for line in lhdl:
            parts = line.strip().split("\t")
            if len(parts) != 4:
                continue
            (md5, taxId, lcaStr, lcaLvl) = parts
            if taxId not in taxaMap:
                continue
            data = None
            try:
                val = db.Get(md5)
            except KeyError:
	            val = None
            # test if md5 exists
            if val:
                # modify entry
                data = json.loads(val)
                data['lca'] = lcaStr.split(';')
                data['single'] = taxId
            if data:
                md5Count += 1
                db.Put(md5, json.dumps(data))
        lhdl.close()
        print "done loading %d LCA md5s"%(md5Count)
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
