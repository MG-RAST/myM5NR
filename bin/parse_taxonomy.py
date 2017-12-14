#!/usr/bin/env python

import os
import re
import sys
import json
import argparse
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
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input", dest="input", default=None, help="input taxonomy.dat file")
    parser.add_argument("-o", "--output", dest="output", default=None, help="output json file")
    args = parser.parse_args()
    
    if not (args.input and os.path.isfile(args.input)):
        parser.error("missing input")
    if not args.output:
        parser.error("missing output")
    
    taxaFile = open(args.input, 'r')
    domains = []
    nodeCount = 0
    
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
            
            # each ID will have two arrays of parents and children
            if nodeID not in nodes:
                nodes[nodeID] = {'childNodes':[]}
            nodes[nodeID]['id'] = nodeID
            nodes[nodeID]['rank'] = node['RANK'][0]
            nodes[nodeID]['label'] = node['SCIENTIFIC NAME'][0]
            nodes[nodeID]['parentNodes'] = node['PARENT ID']
            
            nodeCount += 1
            
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
    
    print "[status] %d nodes parsed\n"%(nodeCount)
    
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
    
    json.dump(data, open(args.output, 'w'), indent=4, separators=(', ', ': '))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
