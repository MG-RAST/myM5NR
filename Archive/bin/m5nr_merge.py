#!/usr/bin/python -u

import os
import sys
import json
import plyvel
import argparse

"""
Files required:

--taxa Parsed/NCBI-Taxonomy/taxonomy.json
--func Parsed/M5functions/id2func.txt
--lca Parsed/M5lca/md52lca.txt

Files processed from Source dir:

md52id.txt (required)
md52func.txt or id2func.txt
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
FIDFILE  = 'id2func.txt'
TAXFILE  = 'md52taxid.txt'

def loadFunc(ffile, id_key=False):
    func = {}
    fhdl = open(ffile)
    for line in fhdl:
        parts = line.strip().split("\t")
        if len(parts) != 2:
            continue
        (fid, name) = parts
        if id_key:
            func[fid] = name
        else:
            func[name] = int(fid)
    fhdl.close()
    return func

def main(args):
    parser = argparse.ArgumentParser()
    parser.add_argument("-t", "--taxa", dest="taxa", default=None, help="json format taxonomy file for name-id mapping")
    parser.add_argument("-f", "--func", dest="func", default=None, help="tsv format function file for name-id mapping")
    parser.add_argument("-l", "--lca", dest="lca", default=None, help="tsv format lca file for md5-lca mapping")
    parser.add_argument("-r", "--rna_source", dest="rna_source", default=None, help="list of rna sources to merge")
    parser.add_argument("-p", "--protein_source", dest="protein_source", default=None, help="list of protein sources to merge")
    parser.add_argument("-d", "--db", dest="db", default=".", help="Directory to store LevelDB, default CWD")
    parser.add_argument("-b", "--batch", dest="batch", default=10000, help="Batch size (number of md5s) to store at once")
    parser.add_argument("--test", dest="test", default=0, help="Test mode, use number of batches per source given, off when 0")
    parser.add_argument("--parsedir", dest="parsedir", default="../", help="Directory containing parsed source dirs")
    args = parser.parse_args()
    
    if not (args.taxa and os.path.isfile(args.taxa)):
        parser.error("missing taxa")
    if not (args.func and os.path.isfile(args.func)):
        parser.error("missing func")
    if not os.path.isdir(args.db):
        parser.error("invalid dir for LevelDB")
    if not os.path.isdir(args.parsedir):
        parser.error("invalid dir for parsed source dirs")
    
    sources = []
    if args.rna_source:
        for rs in args.rna_source.split(","):
            sources.append((rs, False))
    if args.protein_source:
        for ps in args.protein_source.split(","):
            sources.append((ps, True))
    if len(sources) == 0:
        parser.error("missing sources")
    
    print "loading taxonomy map"
    taxaMap = json.load(open(args.taxa, 'r'))
    print "loading function map"
    funcMap = loadFunc(args.func, False)
    print "loading levelDB"
    try:
        db = plyvel.DB(args.db, create_if_missing=True)
    except:
        sys.stderr.write("unable to open LevelDB at %s\n"%(args.db))
        return 1
    
    for info in sources:
        (source, isProt) = info
        md5Count = 0
        funCount = 0
        taxCount = 0
        
        print "processing source "+source
        sourceDir = os.path.join(args.parsedir, source)
        if not os.path.isdir(sourceDir):
            sys.stderr.write("source directory %s is missing, skipping\n"%(sourceDir))
            continue
        
        idFile   = os.path.join(sourceDir, IDFILE)
        funcFile = os.path.join(sourceDir, FUNCFILE)
        fidFile  = os.path.join(sourceDir, FIDFILE)
        taxFile  = os.path.join(sourceDir, TAXFILE)
        
        if not os.path.isfile(idFile):
            sys.stderr.write("md52id file %s is missing, skipping\n"%(idFile))
            continue
        
        idFuncMap = {}
        if (not os.path.isfile(funcFile)) and os.path.isfile(fidFile):
            print "loading "+fidFile
            idFuncMap = loadFunc(fidFile, True)
        
        print "loading "+idFile
        ihdl = open(idFile)
        batchCount = 0
        testCount = 0
        wb = db.write_batch()
        
        for line in ihdl:
            parts = line.strip().split("\t")
            if len(parts) != 2:
                continue
            (md5, srcId) = parts
            data = None
            hasIdFunc = True if (srcId in idFuncMap) and (idFuncMap[srcId] in funcMap) else False
            
            if batchCount == args.batch:
                testCount += 1
                wb.write()
                batchCount = 0
                wb = db.write_batch()
            
            if (args.test > 0) and (testCount >= args.test):
                break
            
            try:
                val = db.get(md5)
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
                        if hasIdFunc:
                            if 'function' in a:
                                data['annotation'][i]['function'].append(idFuncMap[srcId])
                                data['annotation'][i]['funid'].append(funcMap[idFuncMap[srcId]])
                            else:
                                data['annotation'][i]['function'] = [idFuncMap[srcId]]
                                data['annotation'][i]['funid'] = [funcMap[idFuncMap[srcId]]]
                if not hasSource:
                    ann = { 'source': source, 'accession': [srcId] }
                    if hasIdFunc:
                        ann['function'] = [idFuncMap[srcId]]
                        ann['funid'] = [funcMap[idFuncMap[srcId]]]
                    data['annotation'].append(ann)
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
                if hasIdFunc:
                    data['annotation'][0]['function'] = [idFuncMap[srcId]]
                    data['annotation'][0]['funid'] = [funcMap[idFuncMap[srcId]]]
            
            if data:
                batchCount += 1
                md5Count += 1
                if hasIdFunc:
                    funCount += 1
                wb.put(md5, json.dumps(data))
        # end for loop through file
        ihdl.close()
        wb.write()
        
        if os.path.isfile(funcFile):
            print "loading "+funcFile
            fhdl = open(funcFile)
            batchCount = 0
            testCount = 0
            wb = db.write_batch()
            
            for line in fhdl:
                parts = line.strip().split("\t")
                if len(parts) != 2:
                    continue
                (md5, funcName) = parts
                if funcName not in funcMap:
                    continue
                data = None
                
                if batchCount == args.batch:
                    testCount += 1
                    wb.write()
                    batchCount = 0
                    wb = db.write_batch()
                
                if (args.test > 0) and (testCount >= args.test):
                    break
                
                try:
                    val = db.get(md5)
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
                    batchCount += 1
                    funCount += 1
                    wb.put(md5, json.dumps(data))
            # end for loop through file
            fhdl.close()
            wb.write()
        
        if os.path.isfile(taxFile):
            print "loading "+taxFile
            thdl = open(taxFile)
            batchCount = 0
            testCount = 0
            wb = db.write_batch()
            
            for line in thdl:
                parts = line.strip().split("\t")
                if len(parts) != 2:
                    continue
                (md5, taxId) = parts
                if taxId not in taxaMap:
                    continue
                data = None
                
                if batchCount == args.batch:
                    testCount += 1
                    wb.write()
                    batchCount = 0
                    wb = db.write_batch()
                
                if (args.test > 0) and (testCount >= args.test):
                    break
                
                try:
                    val = db.get(md5)
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
                    batchCount += 1
                    taxCount += 1
                    wb.put(md5, json.dumps(data))
            # end for loop through file
            thdl.close()
            wb.write()
        
        print "done loading %d md5s, %d funcs, %d taxa for %s"%(md5Count, funCount, taxCount, source)
    # done with source list loop
    
    if args.lca and os.path.isfile(args.lca):
        print "loading LCAs"
        md5Count = 0
        lhdl = open(args.lca)
        batchCount = 0
        testCount = 0
        wb = db.write_batch()
        
        for line in lhdl:
            parts = line.strip().split("\t")
            if len(parts) != 4:
                continue
            (md5, taxId, lcaStr, lcaLvl) = parts
            if taxId not in taxaMap:
                continue
            data = None
            
            if batchCount == args.batch:
                testCount += 1
                wb.write()
                batchCount = 0
                wb = db.write_batch()
            
            if (args.test > 0) and (testCount >= args.test):
                break
            
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
        
        wb.write()
        lhdl.close()
        print "done loading %d LCA md5s"%(md5Count)
    
    db.close()
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
