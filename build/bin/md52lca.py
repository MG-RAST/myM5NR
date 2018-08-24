#!/usr/bin/env python

import os
import sys
import json
import itertools
import argparse

taxa = {}
root = False
RANKS = ['domain', 'phylum', 'class', 'order', 'family', 'genus', 'species', 'strain']

def all_equal(iterable):
    "Returns True if all the elements are equal to each other"
    g = itertools.groupby(iterable)
    return next(g, True) and not next(g, False)

def getAncestors(tid):
    ancestors = []
    if tid in taxa:
        if (not root) and (len(taxa[tid]['parentNodes']) == 0):
            # dont add root node
            return ancestors
        name = taxa[tid]['label'].split(';')[0] # no ';' allowed
        ancestors = [ {'label': name, 'rank': taxa[tid]['rank'], 'id': tid} ]
        parents = taxa[tid]['parentNodes']
        if len(parents) == 1:
            ancestors = getAncestors(parents[0]) + ancestors
    return ancestors

def gapFill(branch):
    filled = []
    taxaPos = 0
    try:
        for i, rank in enumerate(RANKS):
            if (taxaPos + 1) > len(branch):
                break
            taxa = branch[taxaPos]
            if taxa['rank'] == rank:
                filled.append((taxa['label'], taxa['id']))
                taxaPos += 1
            else:
                filled.append(('unknown '+branch[taxaPos-1]['label'], None))
        return filled
    except:
        sys.stderr.write("[error] can not map branch to ranks\n")
        sys.exit(1)

def getLca(tids):
    lca = ["-"] * 8
    tid = None
    lvl = 0
    branches = []
        
    for t in tids:
        b = getAncestors(t)
        if len(b) > 0:
            branches.append(gapFill(b))
    
    try:
        if len(branches) == 0:
            return None, None, 0
        if len(branches) == 1:
            for i, x in enumerate(branches[0]):
                lca[i] = x[0]
                tid = x[1]
                lvl = i + 1
            return ";".join(lca), tid, lvl
    
        maxdepth = min(map(lambda x: len(x), branches))
        for i, b in enumerate(branches):
            branches[i] = b[:maxdepth]
    
        rotate = zip(*branches)
        for i, level in enumerate(rotate):
            names = map(lambda x: x[0], level)
            if all_equal(names):
                lca[i] = level[0][0]
                tid = level[0][1]
                lvl = i + 1
            else:
                break
        return ";".join(lca), tid, lvl
    except:
        sys.stderr.write("[error] with: %s\n"%(", ".join(tids)))
        sys.exit(1)

def main(args):
    global taxa, root
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input", dest="input", default=None, help="input file: md5 \\t taxid, sorted by md5")
    parser.add_argument("-o", "--output", dest="output", default=None, help="output file: md5 \\t taxid \\t lca \\t depth")
    parser.add_argument("-t", "--taxa", dest="taxa", default=None, help="json format taxonomy file")
    parser.add_argument("-r", "--root", dest="root", action="store_true", default=False, help="if true keep root node in lca, skip otherwise")
    args = parser.parse_args()
    
    if not (args.input and os.path.isfile(args.input)):
        parser.error("missing input")
    if not (args.taxa and os.path.isfile(args.taxa)):
        parser.error("missing taxa")
    if not args.output:
        parser.error("missing output")
    
    root = args.root
    taxa = json.load(open(args.taxa, 'r'))
    ihdl = open(args.input, 'r')
    ohdl = open(args.output, 'w')
    curr = None
    tids = set()
    mnum = 0
    lnum = 0
    
    # process set of taxids per md5
    for line in ihdl:
        parts = line.strip().split("\t")
        if len(parts) != 2:
            continue
        (md5, tid) = parts
        if curr is None:
            curr = md5
        if curr != md5:
            mnum += 1
            lcaStr, lcaId, lvl = getLca(tids)
            if lcaStr and lcaId:
                lnum += 1
                ohdl.write("%s\t%s\t%s\t%d\n"%(curr, lcaId, lcaStr, lvl))
            curr = md5
            tids = set()
        tids.add(tid)
    
    if len(tids) > 0:
        mnum += 1
        lcaStr, lcaId, lvl = getLca(tids)
        if lcaStr and lcaId:
            lnum += 1
            ohdl.write("%s\t%s\t%s\t%d\n"%(curr, lcaId, lcaStr, lvl))
    
    print "Produced %d LCAs for %d md5sums"%(lnum, mnum)
    ihdl.close()
    ohdl.close()
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
