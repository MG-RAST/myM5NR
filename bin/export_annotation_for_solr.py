#!/usr/bin/python -u

import os
import sys
import json
import yaml
import time
import plyvel
import argparse
from datetime import datetime

"""
------- Inputs -------

levelDB record:

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

taxonomy.tsv file:
    taxid, domain, phylum, class, order, family, genus, species, strain

id2hierarchy.txt file:
    accession, level1, level2, level3 (optional), level4 (optional)

------- Outputs: JSON format -------

<output>.source
<output>.ontology
<output>.taxonomy
<output>.annotation

"""

HIERARCHY_FILE = 'id2hierarchy.txt'
TAX_RANKS = [
    'domain',
    'phylum',
    'class',
    'order',
    'family',
    'genus',
    'species'
]

def leaf_name(taxa):
    rtaxa = reversed(taxa)
    for t in rtaxa:
        if t and (t != '-'):
            return t
    return None

def main(args):
    parser = argparse.ArgumentParser()
    parser.add_argument("--taxa", dest="taxa", default=None, help="taxonomy tabbed file")
    parser.add_argument("--sources", dest="sources", default=None, help="sources.yaml file")
    parser.add_argument("--db", dest="db", default=None, help="DB dir path")
    parser.add_argument("--output", dest="output", default=None, help="output prefix for files")
    parser.add_argument("--parsedir", dest="parsedir", default="../", help="Directory containing parsed source dirs")
    args = parser.parse_args()
    
    if not args.output:
        parser.error("missing output prefix")
    if not os.path.isfile(args.taxa):
        parser.error("missing taxonomy file")
    if not os.path.isfile(args.sources):
        parser.error("missing sources.yaml file")
    if not os.path.isdir(args.parsedir):
        parser.error("invalid dir for parsed source dirs")
    
    # get source info
    print "start reading %s: %s"%(args.sources, str(datetime.now()))
    count   = 0
    fhSrcs  = set()
    srcData = {}
    srcInfo = yaml.load(open(args.sources, 'r'))
    osHdl   = open(args.output+'.source', 'w')
    for src in srcInfo.iterkeys():
        count += 1
        stype = srcInfo[src]['category']
        if (srcInfo[src]['category'] == 'protein') and (srcInfo[src]['type'] == 'hierarchical function annotation'):
            fhSrcs.add(src)
            stype = 'ontology'
        srcData[src] = stype
        data = {
            'object': 'source',
            'id': "s_%d"%(count),
            'source': src,
            'type': stype,
            'url': srcInfo[src]['homepage'],
            'description': srcInfo[src]['description']
        }
        srcDir = os.path.join(args.parsedir, '../Sources', src)
        try:
            data['download_date'] = open(os.path.join(srcDir, 'timestamp.txt'), 'r').read().strip().split(".")[0]
        except:
            pass
        try:
            data['version'] = open(os.path.join(srcDir, 'version.txt'), 'r').read().strip()
        except:
            pass
        osHdl.write(json.dumps(data)+"\n")
    osHdl.close()
    print "done reading: "+str(datetime.now())
    print "processed %d sources"%(count)
    
    # taxonomy file
    taxaData = {}
    print "start reading %s: %s"%(args.taxa, str(datetime.now()))
    count = 0
    itHdl = open(args.taxa, 'r')
    otHdl = open(args.output+'.taxonomy', 'w')
    for line in itHdl:
        taxa = line.strip().split("\t")
        if len(taxa) != 9:
            continue
        tid  = taxa.pop(0)
        name = leaf_name(taxa)
        if name and tid:
            count += 1
            taxaData[tid] = {}
            data = {
                'object': 'taxonomy',
                'id': "t_"+tid,
                'ncbi_tax_id': int(tid),
                'organism': name
            }
            for i, t in enumerate(taxa):
                if (t != '-') and (name != t):
                    taxaData[tid][TAX_RANKS[i]] = t
                    data[TAX_RANKS[i]] = t
            otHdl.write(json.dumps(data)+"\n")
    otHdl.close()
    print "done reading: "+str(datetime.now())
    print "processed %d taxa"%(count)
    
    # ontology file
    ofHdl = open(args.output+'.ontology', 'w')
    for source in fhSrcs:
        hierfile = os.path.join(args.parsedir, source, HIERARCHY_FILE)
        print "start reading %s: %s"%(hierfile, str(datetime.now()))
        count = 0
        ifHdl = open(hierfile, 'r')
        for line in ifHdl:
            hier  = line.strip().split("\t")
            accid = hier.pop(0)
            level = len(hier)
            if accid and (level < 5):
                count += 1
                data = {
                    'object': 'ontology',
                    'id': "o_%d"%(count),
                    'source': source,
                    'accession': accid
                }
                for i in range(level):
                    if hier[i] != '-':
                        data["level%d"%(i+1)] = hier[i]
                ofHdl.write(json.dumps(data)+"\n")
        print "done reading: "+str(datetime.now())
        print "processed %d branches"%(count)
    ofHdl.close()
        
    # annotation files from levelDB (optional)
    # wait if another process using levelDB
    if args.db and os.path.isdir(args.db):
        while True:
            try:
                db = plyvel.DB(args.db)
                break
            except IOError:
                time.sleep(60)
            except:
                sys.stderr.write("unable to open DB at %s\n"%(args.db))
                return 1
        
        print "start reading %s: %s"%(args.db, str(datetime.now()))
        count = 0
        oaHdl = open(args.output+'.annotation', 'w')
        for key, value in db:
            info = json.loads(value)
            for ann in info['ann']:
                for i in range(len(ann['accession'])):
                    count += 1
                    data = {
                        'object': 'annotation',
                        'id': "a_%d"%(count),
                        'source': ann['source'],
                        'type': srcData[ann['source']],
                        'md5': key,
                        'accession': ann['accession'][i]
                    }
                    try:
                        data['function'] = ann['function'][i]
                        data['function_id'] = ann['funid'][i]
                    except:
                        pass
                    try:
                        data['organism'] = ann['organism'][i]
                        data['ncbi_tax_id'] = ann['taxid'][i]
                        data.update(taxaData[ann['taxid'][i]])
                    except:
                        pass
                    oaHdl.write(json.dumps(data)+"\n")
        oaHdl.close()
        print "done reading: "+str(datetime.now())
        print "processed %d annotations"%(count)
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
