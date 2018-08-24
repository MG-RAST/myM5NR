#!/usr/bin/python -u

import os
import sys
import md5
import json
import argparse

def leaf_name(taxa):
    rtaxa = reversed(taxa)
    for t in rtaxa:
        if t and (t != '-'):
            return t
    return None

def main(args):
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", dest="dir", default=None, help="dir path")
    parser.add_argument("--taxa", dest="taxa", default=None, help="taxonomy tabbed file")
    args = parser.parse_args()
    
    if not os.path.isdir(args.dir):
        parser.error("invalid dir for source data")
    if not os.path.isfile(args.taxa):
        parser.error("missing taxonomy file")
    
    # get NCBI taxa map
    taxamap = {}
    thdl = open(args.taxa, 'r')
    for line in thdl:
        taxa = line.strip().split("\t")
        tid  = int(taxa.pop(0))
        taxamap[tid] = leaf_name(taxa)
    thdl.close()
    
    # output file handles
    md52id    = open('md52id.txt', 'w')
    md52seq   = open('md52seq.txt', 'w')
    md52func  = open('md52func.txt', 'w')
    md52taxid = open('md52taxid.txt', 'w')
    
    count = 0
    # for each sub-dir in main dir
    for subdir in os.listdir(args.dir):
        path = os.path.join(args.dir, subdir)
        if not os.path.isdir(path):
            continue
        # subdir name should be digits only
        try:
            int(subdir)
        except ValueError:
            continue
        # for each .json file in sub-dir
        for fname in os.listdir(path):
            data = []
            try:
                content = json.load(open(os.path.join(path, fname), 'r'))
                data = content['response']['docs']
            except:
                # some problem with this genome, give warning and move on
                print "[warning] invalid file: "+fname
                continue
            for feature in data:
                if ('feature_type' not in feature) or (feature['feature_type'] != 'CDS'):
                    # only save protein coding features
                    continue
                try:
                    sequence = "".join(feature['aa_sequence'].split()).upper()
                    md5sum   = md5.new(sequence).hexdigest()
                    featid   = feature['patric_id']
                    function = feature['product'].encode('ascii', 'ignore').strip().strip("'\"").strip()
                    taxaid   = int(feature['taxon_id'])
                    taxaname = taxamap[taxaid]
                    md52id.write("%s\t%s\n"%(md5sum, featid))
                    md52seq.write("%s\t%s\n"%(md5sum, sequence))
                    md52func.write("%s\t%s\n"%(md5sum, function))
                    md52taxid.write("%s\t%s\n"%(md5sum, taxaid))
                except:
                    # some problem with this feature, skip silently
                    continue
            count += 1
        # end files loop
    # end sub-dir loop
    
    print "Done parsing %d genome files"%(count)
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
