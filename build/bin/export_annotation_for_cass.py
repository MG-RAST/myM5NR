#!/usr/bin/python -u

import os
import sys
import json
import yaml
import pickle
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

------- Outputs: (binary) pickeled python array for each row to insert, multi-pickles per file -------

<output>.annotation.md5:
    text, text,   boolean,    text,     text array, text array, text array, text array
  [ md5,  source, is_protein, lca leaf, lca,        accesions,  functions,  organisms ]

<output>.annotation.midx
    text, text,   boolean,    int,       text array, int array, int array
  [ md5,  source, is_protein, lca taxid, accesions,  funcids,   taxids ]

<output>.taxonomy.all
  [ leaf name, domain, phylum, class, order, family, genus, species, taxid ]

<output>.ontology.all
  [ source, accession, level1, level2, level3, level4 ]
"""

HIERARCHY_FILE = 'id2hierarchy.txt'
ONTOLOGY_LEVEL = 4

def leaf_name(taxa):
    rtaxa = reversed(taxa)
    for t in rtaxa:
        if t and (t != '-'):
            return t
    return None

def getlist(data, key, isint=True):
    if key in data:
        if isint:
            return '['+','.join(map(str, data[key]))+']'
        else:
            return '['+','.join(map(lambda x: "'"+str(x)+"'", data[key]))+']'
    else:
        return '[]'

def getleaf(md5, data, isid=True):
    if isid:
        if ('lcaid' in data) and data['lcaid']:
            return data['lcaid']
        else:
            return 0
    else:
        if ('lca' in data) and (len(data['lca']) > 0):
            return data['lca'][-1]
        else:
            return ''

def padlist(l, n, pad=""):
    if len(l) >= n:
        return l[:n]
    return l + ([pad] * (n - len(l)))


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
    
    # parse sources
    sourceInfo = yaml.load(open(args.sources, 'r'))
    fhSrcs = set()
    for src in sourceInfo.iterkeys():
        if (sourceInfo[src]['category'] == 'protein') and (sourceInfo[src]['type'] == 'hierarchical function annotation'):
            fhSrcs.add(src)
    if len(fhSrcs) == 0:
        sys.stderr.write("missing functional hierarchies in %s\n"%(args.sources))
    
    # taxonomy files (required)
    thdl = open(args.output+'.taxonomy.all', 'w')
    touthdls = [
        open(args.output+'.taxonomy.domain', 'w'),
        open(args.output+'.taxonomy.phylum', 'w'),
        open(args.output+'.taxonomy.class', 'w'),
        open(args.output+'.taxonomy.order', 'w'),
        open(args.output+'.taxonomy.family', 'w'),
        open(args.output+'.taxonomy.genus', 'w'),
        open(args.output+'.taxonomy.species', 'w')
    ]
    # parse input
    print "start reading %s: %s"%(args.taxa, str(datetime.now()))
    count = 0
    ihdl = open(args.taxa, 'r')
    for line in ihdl:
        taxa = line.strip().split("\t")
        if len(taxa) != 9:
            continue
        tid  = taxa.pop(0)
        name = leaf_name(taxa)
        if name and tid:
            count += 1
            for i, fh in enumerate(touthdls):
                if (taxa[i] != '-') and (not taxa[i].startswith('unknown')) and (name != taxa[i]):
                    pickle.dump(fh, [taxa[i], name])
            pickle.dump(thdl, [name]+taxa[:7]+[tid])

    print "done reading: "+str(datetime.now())
    print "processed %d taxa"%(count)
    for h in touthdls:
        h.close()
    thdl.close()
    ihdl.close()
    
    # functional hierarchy files (required)
    hhdl = open(args.output+'.ontology.all', 'w')
    houthdls = [
        open(args.output+'.ontology.level1', 'w'),
        open(args.output+'.ontology.level2', 'w'),
        open(args.output+'.ontology.level3', 'w'),
        open(args.output+'.ontology.level4', 'w')
    ]
    # parse files
    for source in fhSrcs:
        print "start reading %s: %s"%(source, str(datetime.now()))
        count = 0
        ihdl = open(os.path.join(args.parsedir, source, HIERARCHY_FILE), 'r')
        for line in ihdl:
            hier  = line.strip().split("\t")
            accid = hier.pop(0)
            level = len(hier)
            if accid and (level <= ONTOLOGY_LEVEL):
                count += 1
                for i in range(level):
                    if hier[i] != '-':
                        pickle.dump(houthdls[i], [source, hier[i], accid])
                hier = padlist(hier, ONTOLOGY_LEVEL)
                pickle.dump(hhdl, [source, accid]+hier)
        print "done reading: "+str(datetime.now())
        print "processed %d brances for %s"%(count, source)
        ihdl.close()
    # done
    for h in houthdls:
        h.close()
    hhdl.close()
    
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
        
        mhdl = open(args.output+'.annotation.md5', 'w')
        ihdl = open(args.output+'.annotation.midx', 'w')
        
        print "start reading %s: %s"%(args.db, str(datetime.now()))
        count = 0
        for key, value in db:
            data = json.loads(value)
            isaa = 'true' if data['is_aa'] else 'false'
            count += 1
            for ann in data['ann']:
                md5ann = [
                    key,
                    ann['source'],
                    isaa,
                    getleaf(key, data, False),
                    getlist(data, 'lca', False),
                    getlist(ann, 'accession', False),
                    getlist(ann, 'function', False),
                    getlist(ann, 'organism', False)
                ]
                midxann = [
                    key,
                    ann['source'],
                    isaa,
                    getleaf(key, data, True),
                    getlist(ann, 'accession', False) if data['is_aa'] and ann['source'] in fhSrcs else '[]',
                    getlist(ann, 'funid', True),
                    getlist(ann, 'taxid', True)
                ]
                pickle.dump(mhdl, md5ann)
                pickle.dump(ihdl, midxann)
        
        print "done reading: "+str(datetime.now())
        print "processed %d md5s"%(count)
        db.close()
        ihdl.close()
        mhdl.close()
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
