#!/usr/bin/env python

import os
import re
import sys
import json
from optparse import OptionParser
from collections import defaultdict

nodes = {}
descSeen = set()
# max recrusion depth
sys.setrecursionlimit(10000)

def getNode(stream):
    block = []
    for line in stream:
        if line.strip() == "//":
            break
        else:
            if line.strip() != "":
                block.append(line.strip())
    return block

def parseTagValue(node):
    data = defaultdict(list)
    for line in node:
        tag = line.split(': ',1)[0].strip()
        value = line.split(': ',1)[1].strip()
        data[tag].append(value)
    return data

def getDescendents(nid):
    global descSeen
    decendents = {}
    if nid in nodes:
        if nid in descSeen:
            # avoid circular refrences
            return decendents
        descSeen.add(nid)
        decendents = {nid: nodes[nid]}
        children = nodes[nid]['childNodes']
        if len(children) > 0:
            for child in children:
                decendents.update(getDescendents(child))
    return decendents

def main(args):
    global nodes
    parser = OptionParser(usage="usage: %prog [options] -i <input file> -o <output file>")
    parser.add_option("-i", "--input", dest="input", default=None, help="input taxonomy.dat file")
    parser.add_option("-o", "--output", dest="output", default=None, help="output: .json file")
    
    (opts, args) = parser.parse_args()
    if not (opts.input and os.path.isfile(opts.input)):
        parser.error("missing input")
    if not opts.output:
        parser.error("missing output")
    
    taxaFile = open(opts.input, 'r')
    domains = []
    
    # infinite loop to go through the file.
    # breaks when the node returned is empty, indicating end of file
    while 1:
        # get the term using the two parsing functions
        node = parseTagValue(getNode(taxaFile))
        # quite if node is empty
        if len(node) == 0:
            break
        try:
            nodeID = node['ID'][0]
            print nodeID
            
            # each ID will have two arrays of parents and children
            if nodeID not in nodes:
                nodes[nodeID] = {'childNodes':[]}
            nodes[nodeID]['id'] = nodeID
            nodes[nodeID]['rank'] = node['RANK'][0]
            nodes[nodeID]['label'] = node['SCIENTIFIC NAME'][0]
            nodes[nodeID]['parentNodes'] = node['PARENT ID']
            
            # rank fix
            if nodes[nodeID]['rank'] == 'superkingdom':
                nodes[nodeID]['rank'] = 'domain'
                nodes[nodeID]['parentNodes'] = ['1']
                domains.append(nodeID)
            
            # for every parent term, add this current term as children
            for parentID in nodes[nodeID]['parentNodes']:
                if parentID not in nodes:
                    nodes[parentID] = {'childNodes':[]}
                nodes[parentID]['childNodes'].append(nodeID)
        except:
            # continue if node is broken
            continue
    
    data = {
        'rootNode' : '1',
        'nodes' : {
            '1' : {
                'id': '1',
                'rank': None,
                'label': 'root',
                'parentNodes': [],
                'childNodes': domains
            }
        }
    }
    
    for nid in domains:
        data['nodes'].update( getDescendents(nid) )
    
    json.dump(data, open(opts.output, 'w'), indent=4, separators=(', ', ': '))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
