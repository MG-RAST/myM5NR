#!/usr/bin/python -u

import os
import sys
import csv
import json
import copy
import plyvel
import argparse
import itertools
from datetime import datetime

"""
Input levelDB record:

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

Input taxonomy.tsv file:
    taxid, domain, phylum, class, order, family, genus, species, strain

Input id2hierarchy.txt file:
    accession, level1, level2, level3 (optional), level4 (optional)

Output files, CSV format:

<output>.annotation.md5:
    text, text,   boolean,    text,     text array, text array, text array, text array
    md5,  source, is_protein, lca leaf, lca,        accesions,  functions,  organisms

<output>.annotation.midx
    text, text,   boolean,    int,       text array, int array, int array
    md5,  source, is_protein, lca taxid, accesions,  funcids,   taxids

<output>.taxonomy.all
    leaf name, domain, phylum, class, order, family, genus, species, taxid

<output>.ontology.all
    source, accession, level1, level2, level3, level4
"""

HIERARCHY_FILE = 'id2hierarchy.txt'

def leaf_name(taxa):
    rtaxa = reversed(taxa)
    for t in rtaxa:
        if t and (t != '-'):
            return t
    return None

def getlist(data, key, isint=True):
    if key in data:
        if isint:
            return '['+','.join(data['lca'])+']'
        else:
            return '['+','.join(map(lambda x: "'"+x+"'", data['lca']))+']'
    else:
        return '[]'

def getleaf(data, isid=True):
    if isid:
        if 'lcaid' in data:
            return data['lcaid']
        else:
            return 0
    else:
        if 'lca' in data:
            return data['lca'][-1]
        else:
            return ''

def main(args):
    parser = argparse.ArgumentParser()
    parser.add_argument("--taxonomy", dest="taxonomy", default=None, help="taxonomy tabbed file")
    parser.add_argument("--hierarchy", dest="hierarchy", default=None, help="list of functional hierarchy source names")
    parser.add_argument("--db", dest="db", default=None, help="DB dir path")
    parser.add_argument("--output", dest="output", default=None, help="output prefix for files")
    parser.add_argument("--parsedir", dest="parsedir", default="../", help="Directory containing parsed source dirs")
    args = parser.parse_args()
    
    if not args.output:
        parser.error("missing output prefix")
    if not os.path.isfile(args.taxonomy):
        parser.error("missing taxonomy file")
    if not os.path.isdir(args.parsedir):
        parser.error("invalid dir for parsed source dirs")
    if not args.hierarchy):
        parser.error("missing functional hierarchy source names")
    fhSrcs = set(args.hierarchy.split(","))
    for s in fhSrcs:
        f = os.path.join(args.parsedir, s, HIERARCHY_FILE)
        if not os.path.isfile(f):
            sys.stderr.write("%s has no valid functional hierarchy file %s\n"%(s, f))
            return 1
    
    # annotation files from levelDB (optional)
    if args.db and os.path.isdir(args.db):
        try:
            db = plyvel.DB(args.db)
        except:
            sys.stderr.write("unable to open DB at %s\n"%(args.db))
            return 1
    
        mhdl = open(args.output+'.annotation.md5', 'w')
        mcvs = csv.writer(mhdl, delimiter=',', quotechar='"', quoting=csv.QUOTE_ALL)
        ihdl = open(args.output+'.annotation.midx', 'w')
        icvs = csv.writer(ihdl, delimiter=',', quotechar='"', quoting=csv.QUOTE_ALL)
    
        print "start reading %s: %s"%(args.db, str(datetime.now()))
        count = 0;
        for key, value in db:
            data = json.load(value)
            isaa = 'true' if data['is_aa'] else 'false'
            count += 1
            for ann in data['ann']:                
                md5ann = [
                    key,
                    ann['source'],
                    isaa,
                    getleaf(data, False),
                    getlist(data, 'lca', False),
                    getlist(ann, 'accession', False),
                    getlist(ann, 'function', False),
                    getlist(ann, 'organism', False)
                ]
                midxann = [
                    key,
                    ann['source'],
                    isaa,
                    getleaf(data, True),
                    getlist(ann, 'accession', False) if data['is_aa'] and ann['source'] in fhSrcs else '[]',
                    getlist(ann, 'funid', True),
                    getlist(ann, 'taxid', True)
                ]
                mcvs.writerow(md5ann)
                icvs.writerow(midxann)
        
        print "done reading: "+str(datetime.now())
        print "processed %d md5s"%(count)
        db.close()
        ihdl.close()
        mhdl.close()
    
    # taxonomy files (required)
    thdl = open(args.output+'.taxonomy.all', 'w')
    tcvs = csv.writer(thdl, delimiter=',', quotechar='"', quoting=csv.QUOTE_ALL)
    touthdls = [
        open(args.output+'.taxonomy.domain', 'w'),
        open(args.output+'.taxonomy.phylum', 'w'),
        open(args.output+'.taxonomy.class', 'w'),
        open(args.output+'.taxonomy.order', 'w'),
        open(args.output+'.taxonomy.family', 'w'),
        open(args.output+'.taxonomy.genus', 'w'),
        open(args.output+'.taxonomy.species', 'w')
    ]
    tcvswriters = map(lambda h: csv.writer(h, delimiter=',', quotechar='"', quoting=csv.QUOTE_ALL), touthdls)
    # parse input
    print "start reading %s: %s"%(args.taxonomy, str(datetime.now()))
    count = 0;
    ihdl = open(args.taxonomy, 'r')
    for line in ihdl:
        taxa = line.strip().split("\t")
        if len(taxa) != 9:
            continue
        tid  = taxa.pop(0)
        name = leaf_name(taxa)
        if name and tid:
            count += 1
            for i, cw in enumerate(tcvswriters):
                if (taxa[i] != '-') and (name != taxa[i]):
                    cw.writerow([taxa[i], name])
            tcvs.writerow([name]+taxa[:7]+[tid])

    print "done reading: "+str(datetime.now())
    print "processed %d taxa"%(count)
    for h in touthdls:
        h.close()
    thdl.close()
    ihdl.close()
    
    # functional hierarchy files (required)
    hhdl = open(args.output+'.ontology.all', 'w')
    hcvs = csv.writer(thdl, delimiter=',', quotechar='"', quoting=csv.QUOTE_ALL)
    houthdls = [
        open(args.output+'.ontology.level1', 'w'),
        open(args.output+'.ontology.level2', 'w'),
        open(args.output+'.ontology.level3', 'w'),
        open(args.output+'.ontology.level4', 'w')
    ]
    hcvswriters = map(lambda h: csv.writer(h, delimiter=',', quotechar='"', quoting=csv.QUOTE_ALL), houthdls)
    # parse files
    for source in fhSrcs:
        print "start reading %s: %s"%(source, str(datetime.now()))
        count = 0;
        ihdl = open(os.path.join(args.parsedir, h, HIERARCHY_FILE), 'r')
        for line in ihdl:
            hier  = line.strip().split("\t")
            accid = hier.pop(0)
            level = len(hier)
            if accid and (level < 5):
                count += 1
                for i in range(level):
                    if hier[i] != '-':
                        hcvswriters[i].writerow([source, hier[i], accid])
                hcvs.writerow([source, accid]+hier)
        print "done reading: "+str(datetime.now())
        print "processed %d brances for %s"%(count, source)
        ihdl.close()
    # done
    for h in houthdls:
        h.close()
    hhdl.close()
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
