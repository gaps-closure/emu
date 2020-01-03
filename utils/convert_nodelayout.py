#!/bin/python3
from argparse import ArgumentParser

def get_args():
    p = ArgumentParser(description='Pull layout from imn file')
    p.add_argument('-f', '--file', required=True, type=str, help='Input imn file')
    return p.parse_args()

args = get_args()
f = open(args.file, 'r')

# Node Layout
h = None
ix = None
iy = None
lx = None
ly = None
for line in f:
    if 'hostname' in line:
        h = line.split()[1]
    if 'iconcoords' in line:
        ix=line.split()[1].lstrip('{')
        iy=line.split()[2].rstrip('}')
    if 'labelcoords' in line:
        lx=line.split()[1].lstrip('{')
        ly=line.split()[2].rstrip('}')
    if h and ix and iy and lx and ly:
        print('  {\n   "hostname":"%s",\n   "canvas":"Canvas1",\n   "iconcoords": {"x":%s, "y":%s},\n   "labelcoords": {"x":%s, "y":%s}\n  },' % (h, ix, iy, lx, ly))
        h = None
        ix = None
        iy = None
        lx = None
        ly = None
f.close()

        
