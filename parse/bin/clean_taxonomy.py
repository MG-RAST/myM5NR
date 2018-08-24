#!/usr/bin/env python

import sys
import copy
import json
import argparse
from collections import defaultdict

"""
Requires 'id', 'rank', and 'parentNodes' fields.
"""

curRanks = [
    ['domain', '-'],
    ['phylum', '-'],
    ['class', '-'],
    ['order', '-'],
    ['family', '-'],
    ['genus', '-'],
    ['species', '-'],
    ['strain', '-']
]
RANKS = map(lambda x: x[0], curRanks)
DEPTH = len(RANKS)

def toRemove(data):
    remove = []
    for n in data.itervalues():
        if (len(n['childNodes']) == 0) and ((not n['description']) or (n['description'] == n['label'])):
            remove.append(copy.deepcopy(n))
    return remove

def cleanDesc(nodes, root_id):
    i = 1
    remove = toRemove(nodes)
    while len(remove) > 0:
        print "round %d, remove %d"%(i, len(remove))
        for r in remove:
            if root_id and (r['id'] == root_id):
                continue
            # this node has no children
            # update parents children list
            for p in r['parentNodes']:
                if p in nodes:
                    nodes[p]['childNodes'].remove(r['id'])
            # remove node
            if r['id'] in nodes:
                del nodes[r['id']]
        remove = toRemove(nodes)
        i += 1
    print "root %s: round %d, remove %d"%(root_id, i, len(remove))
    return nodes

def checkRank(node):
    if 'rank' not in node:
        return "missing"
    if node['rank'] not in RANKS:
        return node['rank']
    return None

def cleanRank(nodes, root_id):
    removed = defaultdict(int)
    nodeIds = nodes.keys()
    for nid in nodeIds:
        if nid not in nodes:
            continue
        # skip root
        if root_id and (nid == root_id):
            continue
        # skip leaf nodes
        if len(nodes[nid]['childNodes']) == 0:
            continue
        n = nodes[nid]
        key = checkRank(n)
        if not key:
            continue
        # update child lists of parents
        for p in n['parentNodes']:
            if p in nodes:
                temp = list(set(nodes[p]['childNodes'] + n['childNodes']))
                temp.remove(nid)
                nodes[p]['childNodes'] = temp
        # update parent lists of children
        for c in n['childNodes']:
            if c in nodes:
                temp = list(set(nodes[c]['parentNodes'] + n['parentNodes']))
                temp.remove(nid)
                nodes[c]['parentNodes'] = temp
        # remove node
        del nodes[nid]
        removed[key] += 1
    for r in removed.keys():
        print "root %s: removed rank: %s, %d nodes"%(root_id, r, removed[r])
    return nodes

def cleanLeaf(nodes, root_id):
    removed = defaultdict(int)
    changed = defaultdict(int)
    skip = 0
    nodeIds = nodes.keys()
    for nid in nodeIds:
        if nid not in nodes:
            continue
        # skip root
        if root_id and (nid == root_id):
            continue
        n = nodes[nid]
        # skip non-leaf
        if len(n['childNodes']) > 0:
            skip += 1
            continue  
        # make sure leaf rank is correct
        # assume parent rank is correct
        currRank = n['rank']
        if currRank in RANKS:
            continue
        pRankIdx = RANKS.index(nodes[n['parentNodes'][0]]['rank'])
        if pRankIdx == 7:
            # update child lists of parents
            for p in n['parentNodes']:
                if p in nodes:
                    temp = list(set(nodes[p]['childNodes'] + n['childNodes']))
                    temp.remove(nid)
                    nodes[p]['childNodes'] = temp
            del nodes[nid]
            removed[currRank] += 1
        else:
            nodes[nid]['rank'] = RANKS[pRankIdx+1]
            changed[currRank] += 1
    print "skipped nodes: %d"%(skip)
    for r in removed.keys():
        print "root %s: removed rank: %s, %d nodes"%(root_id, r, removed[r])
    for c in changed.keys():
        print "root %s: changed rank: %s, %d nodes"%(root_id, c, changed[c])
    return nodes

def getDescendents(nodes, nid):
    decendents = []
    if nid in nodes:
        decendents = [nid]
        children = nodes[nid]['childNodes']
        if len(children) > 0:
            for child in children:
                decendents.extend(getDescendents(nodes, child))
    return decendents

def pruneTree(nodes, root_id, prune):
    pruneParents = set()
    total = 0
    for p in prune:
        if p not in nodes:
            continue
        for pn in nodes[p]['parentNodes']:
            pruneParents.add(pn)
        decendents = getDescendents(nodes, p)
        toDelete = set(decendents)
        for d in toDelete:
            if d in nodes:
                total += 1
                del nodes[d]
    print "root %s: pruned %d nodes, %d decendents removed"%(root_id, len(prune), total)
    for pp in pruneParents:
        if pp not in nodes:
            continue
        for p in prune:
            if p in nodes[pp]['childNodes']:
                nodes[pp]['childNodes'].remove(p)
    return nodes

def printBranches(nodes, nid, ofile):
    global curRanks
    if nid in nodes:
        rank = nodes[nid]['rank']
        # sanity check
        if rank not in RANKS:
            sys.stderr.write("[error] nodeID (%s) rank (%s)\n"%(nid, rank))
            sys.exit(1)
        curDepth = RANKS.index(rank)
        # set global variables
        curRanks[curDepth][1] = nodes[nid]['label']
        # print - fill gaps only in local copy
        fixRanks = map(lambda x: x[1], curRanks)
        for i in range(curDepth):
            if fixRanks[i] == '-':
                if fixRanks[i-1].startswith('unknown'):
                    fixRanks[i] = fixRanks[i-1]
                else:
                    fixRanks[i] = 'unknown '+fixRanks[i-1]
        ofile.write("%s\t%s\n"%(nid, "\t".join(fixRanks)))
        children = nodes[nid]['childNodes']
        # process children
        if len(children) > 0:
            for child in children:
                printBranches(nodes, child, ofile)
        # revert global changes
        curRanks[curDepth][1] = '-'
    return


def main(args):
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input", dest="input", default=[], help="one or more input .json file", action='append')
    parser.add_argument("-o", "--output", dest="output", default=None, help="output file prefix")
    parser.add_argument("-f", "--format", dest="format", default='json', help="output format, one of: json, tsv, both")
    parser.add_argument("-d", "--desc", dest="desc", action="store_true", default=False, help="remove all nodes with no descrption, walk tree from leaf nodes up")
    parser.add_argument("-r", "--rank", dest="rank", action="store_true", default=False, help="remove all nodes without valid rank, connect childern to grandparents")
    parser.add_argument("-p", "--prune", dest="prune", default=None, help="comma seperated list of ids, those ids and all their descendents will be removed from output")
    parser.add_argument("--root", dest="root", default=None, help="id of root node to be created if mutiple inputs used")
    parser.add_argument("--no_id", dest="no_id", action="store_true", default=False, help="remove 'id' from struct to reduce size")
    parser.add_argument("--no_parents", dest="no_parents", action="store_true", default=False, help="remove 'parentNodes' from struct to reduce size")
    parser.add_argument("--header", dest="header", action="store_true", default=False, help="print header, 'tsv' format only")
    args = parser.parse_args()
    
    if len(args.input) == 0:
        parser.error("missing input")
    if (len(args.input) > 1) and (not args.root):
        parser.error("missing root id")
    if not args.output:
        parser.error("missing output")
    
    nodes = []
    root = None
    
    for i in args.input:
        print "[status] reading file %s ... "%(i)
        try:
            info = json.load(open(i, 'r'))
            root = info['rootNode']
            nodes.append(info)
        except:
            parser.error("input %s is invalid format"%(i))
    
    if len(args.input) > 1:
        root = args.root
    
    # rank cleanup
    if args.rank:
        print "[status] cleaning ranks ... "
        for i, n in enumerate(nodes):
            nodes[i]['nodes'] = cleanRank(n['nodes'], n['rootNode'])
        print "[status] cleaning leaf rank ... "
        for i, n in enumerate(nodes):
            nodes[i]['nodes'] = cleanLeaf(n['nodes'], n['rootNode'])
    
    # description cleanup
    if args.desc:
        print "[status] cleaning descriptions ... "
        for i, n in enumerate(nodes):
            nodes[i]['nodes'] = cleanDesc(n['nodes'], n['rootNode'])
    
    # remove messy branches
    # 'unclassified'
    # 'environmental samples'
    prune = []
    for node in nodes:
        for v in node['nodes'].itervalues():
            if v['label'].startswith('unclassified') or v['label'].startswith('environmental'):
                prune.append(v['id'])
    
    # add inputted
    if args.prune:
        prune.extend(args.prune.split(','))
    
    # prune branches
    for i, n in enumerate(nodes):
        print "[status] pruning ... "
        nodes[i]['nodes'] = pruneTree(n['nodes'], n['rootNode'], prune)
    
    # trim if needed
    if args.no_id:
        print "[status] trimming ids ... "
        for n in nodes:
            for v in n['nodes'].itervalues():
                del v['id']
    if args.no_parents:
        print "[status] trimming parentNodes ... "
        for n in nodes:
            for v in n['nodes'].itervalues():
                del v['parentNodes']
    
    # merge
    data = {}
    if len(nodes) > 1:
        print "[status] merging trees ... "
        data[root] = {
            'id': root,
            'label': 'root',
            'parentNodes': [],
            'childNodes': []
        }
        for n in nodes:
            data.update(n['nodes'])
            data[root]['childNodes'].append(n['rootNode'])
            data[n['rootNode']]['parentNodes'] = [root]
    else:
        data = nodes[0]['nodes']
    
    # output
    if (args.format == 'json') or (args.format == 'both'):
        ofile = open(args.output+'.json', 'w')
        print "[status] printing to %s.json ... "%(args.output)
        json.dump(data, ofile, separators=(',',':'))
        ofile.close()
    if (args.format == 'tsv') or (args.format == 'both'):
        ofile = open(args.output+'.tsv', 'w')
        print "[status] printing to %s.tsv ... "%(args.output)
        if args.header:
            ofile.write("taxid\t%s\n"%("\t".join(RANKS)))
        for r in data[root]['childNodes']:
            printBranches(data, r, ofile)
        ofile.close()
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
