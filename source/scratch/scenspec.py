#!/usr/bin/python3

from   argparse import ArgumentParser
from   inspect  import isclass
import json
import random

# Base class of all scenario objects
class base: 
  def __init__(self,**kwargs): 
    for k in kwargs: setattr(self,k,kwargs[k])
  def render(self,depth,style='basic',layout=None): 
    if style is 'basic':
      return ' ' * depth + self.__class__.__name__ + '\n'
    else:
      raise Exception('Unsupported style: ' + style)
  def field_render(depth,fldval,fldnam,style='basic',layout=None): 
    if style is 'basic':
      return ' ' * depth + fldnam + ':' + str(fldval) + '\n'
    else:
      raise Exception('Unsupported style: ' + style)

# Parse arguments
def get_args():
  p = ArgumentParser(description='CLOSURE Scenario Configuration')
  p.add_argument('-f', '--file', required=True, type=str, help='Input config file')
  p.add_argument('-l', '--layout', required=True, type=str, help='Input layout file')
  return p.parse_args()

# Non-function, non-internal fields of scenario class instance
def fields(v):
  return [a for a in dir(v) if not callable(getattr(v,a)) and not a.startswith("__")]

# Name of valid scenario class
def valid_class_name(n):
  g = globals()
  return True if n in g and isclass(g[n]) and issubclass(g[n], base) else False

# Instance of valid scenario class
def valid_class_instance(v):
  return True if isclass(type(v)) and issubclass(type(v), base) else False

# Compose scenario from dict
def compose(n,d):
  if not valid_class_name(n): raise Exception('Unsupported class: ' + n)
  def subcomp(k,v):
    if isinstance(v,list):   return [compose(k,i) for i in v] 
    elif isinstance(v,dict): return compose(k,v)
    else:                    return v
  return globals()[n](**{k:subcomp(k,v) for k,v in d.items()})

# Generic traversal using depth-first search
def traverse(v,name,depth,style,layout=None):
  ret = ""
  if valid_class_instance(v): 
    ret += v.render(depth,style=style,layout=layout)
    for i in fields(v): 
      x = getattr(v,i)
      if isinstance(x,list):
        ret += "".join([traverse(j,i,depth+1,style,layout) for j in x])
      else:
        ret += traverse(x,i,depth+1,style,layout)
  else:
    ret += base.field_render(depth,v,name,style,layout=layout)
  return ret

class IDGen():
  def __init__(self):
    self.nid = 0
    self.lid = 0
    self.cid = 0
    self.nm2id = {}

  def get_id(nm,typ):
    if nm not in nm2id: 
      if typ in ['NODE', 'xdhost', 'inthost', 'hub', 'xdgateway']:
        nm2id[nm] = 'n'+str(self.nid)
        self.nid += 1
      elif typ in ['link', 'left', 'right']:
        nm2id[nm] = 'l'+str(self.lid)
        self.lid += 1
      elif typ in ['canvas']:
        nm2id[nm] = 'c'+str(self.cid)
        self.cid += 1
    return nm2id[nm]

# Scenario classes derived from base class
class scenario(base):  
  def render(self,depth,style='imn',layout=None): 
    if style is 'imn':
      # handle enclave[]
      #for e in enclave:
      #  for x in e.xdhost:
      #      x.hwconf
      # handle xdgateway[]
      # handle xdlink[]
      # handle additional stuff such as canvas, 
      return "foostring"
    else:
      return super().render(depth,style)

class enclave(base): pass
class xdhost(base): pass
class hwconf(base): pass
class swconf(base): pass
class nwconf(base): pass
class interface(base): pass
class ifpeer(base): pass
class inthost(base): pass
class link(base): pass
class hub(base): pass
class xdgateway(base): pass
class xdlink(base): pass
class left(base): pass
class right(base): pass
class egress(base): pass
class ingress(base): pass

# Layout classes also derived from base class
class layout(base): 
  def get_node_layout(nod):
    x = [n for n in self.nodelayout if n.hostname == nod]
    if len(x) != 1: raise Exception ('Error getting layout for:' + nod)
    return x[0] 
 
class canvas(base): pass
class option(base): pass
class optglobal(base): pass
class session(base): pass
class nodelayout(base): pass
class iconcoords(base): pass
class labelcoords(base): pass
class annotation(base): pass
class bbox(base): pass

if __name__ == '__main__':
  args = get_args()
  with open(args.file, 'r')   as inf1: conf = json.load(inf1)
  with open(args.layout, 'r') as inf2: layo = json.load(inf2)

  scen = compose('scenario',conf)
  locs = compose('layout',layo)

  #print(traverse(scen,'scenario',0,'basic',locs))
  #print(traverse(locs,'layout',  0,'basic',locs))

  #scen.render(0,'imn',locs)
