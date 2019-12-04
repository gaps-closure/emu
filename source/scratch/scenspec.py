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
  ret = ''
  if valid_class_instance(v): 
    ret += v.render(depth,style=style,layout=layout)
    for i in fields(v): 
      x = getattr(v,i)
      if isinstance(x,list):
        ret += ''.join([traverse(j,i,depth+1,style,layout) for j in x])
      else:
        ret += traverse(x,i,depth+1,style,layout)
  else:
    ret += base.field_render(depth,v,name,style,layout=layout)
  return ret

# Generic rendering of all children that are class instances or list thereof
def render_children(v,depth,style,layout,exclude=[]): 
  ret = ''
  for i in fields(v): 
    if i in exclude: continue
    x = getattr(v,i)
    if isinstance(x,list):
      ret += ''.join([j.render(depth+1,style,layout) for j in x])
    elif valid_class_instance(x): 
      ret += x.render(depth+1,style,layout)
    else:
      pass # ignore all non class fields in generic render_children
  return ret

##############################################
# IMN scenario generator specifc code below

class IDGen():
  def __init__(self):
    self.nid = 0
    self.lid = 0
    self.cid = 0
    self.nm2id = {}

  def get_id(self,nm,typ):
    if nm not in self.nm2id: 
      if typ in ['NODE', 'xdhost', 'inthost', 'hub', 'xdgateway']:
        self.nm2id[nm] = 'n'+str(self.nid)
        self.nid += 1
      elif typ in ['link', 'left', 'right']:
        self.nm2id[nm] = 'l'+str(self.lid)
        self.lid += 1
      elif typ in ['canvas']:
        self.nm2id[nm] = 'c'+str(self.cid)
        self.cid += 1
    return self.nm2id[nm]

class basewid(base):  
  _idgen = IDGen()  # class member, common for instances of this class and all subclasses

# Scenario classes 
class scenario(basewid):  
  def render(self,depth,style='imn',layout=None): 
    return render_children(self,depth,style,layout) if style is 'imn' else super().render(depth,style,layout)

class enclave(basewid): 
  def render(self,depth,style='imn',layout=None): 
    return render_children(self,depth,style,layout) if style is 'imn' else super().render(depth,style,layout)

## TODO
class xdhost(basewid): 
  def render(self,depth,style='imn',layout=None): 
    return 'xdhost to be handled\n' if style is 'imn' else super().render(depth,style,layout)

## TODO
class inthost(basewid): 
  def render(self,depth,style='imn',layout=None): 
    return 'inthost to be handled\n' if style is 'imn' else super().render(depth,style,layout)

## TODO
class hub(basewid): 
  def render(self,depth,style='imn',layout=None): 
    tstr = 'hub to be handled, use of get_id: ' + self.hostname + ' ' + basewid._idgen.get_id(self.hostname,'hub')
    return tstr + '\n' if style is 'imn' else super().render(depth,style,layout)

## TODO
class xdgateway(basewid): 
  def render(self,depth,style='imn',layout=None): 
    return 'xdgateway to be handled\n' if style is 'imn' else super().render(depth,style,layout)

## TODO
class link(basewid): 
  def render(self,depth,style='imn',layout=None): 
    return 'link to be handled\n' if style is 'imn' else super().render(depth,style,layout)

## TODO
class xdlink(basewid): 
  def render(self,depth,style='imn',layout=None): 
    return 'xdlink to be handled\n' if style is 'imn' else super().render(depth,style,layout)

## TODO
class hwconf(basewid): pass
## TODO
class swconf(basewid): pass
## TODO
class nwconf(basewid): pass
## TODO
class interface(basewid): pass
## TODO
class ifpeer(basewid): pass
## TODO
class left(basewid): pass
## TODO
class right(basewid): pass
## TODO
class egress(basewid): pass
## TODO
class ingress(basewid): pass

# Layout classes
## TODO
class scenlayout(basewid): 
  def render(self,depth,style='imn',layout=None): 
    return render_children(self,depth,style,layout,exclude=['nodelayout']) if style is 'imn' else super().render(depth,style,layout)
  def get_node_layout(nod):
    x = [n for n in self.nodelayout if n.hostname == nod]
    if len(x) != 1: raise Exception ('Error getting layout for:' + nod)
    return x[0] 

class option(basewid):
  def render(self,depth,style='imn',layout=None): 
    return render_children(self,depth,style,layout) if style is 'imn' else super().render(depth,style,layout)

## TODO
class nodelayout(basewid): pass
## TODO
class iconcoords(basewid): pass
## TODO
class labelcoords(basewid): pass

## TODO
class canvas(basewid):
  def render(self,depth,style='imn',layout=None): 
    return 'canvas to be handled\n' if style is 'imn' else super().render(depth,style,layout)
## TODO
class optglobal(basewid):
  def render(self,depth,style='imn',layout=None): 
    return 'optglobal to be handled\n' if style is 'imn' else super().render(depth,style,layout)
## TODO
class session(basewid):
  def render(self,depth,style='imn',layout=None): 
    return 'session to be handled\n' if style is 'imn' else super().render(depth,style,layout)
## TODO
class annotation(basewid):
  def render(self,depth,style='imn',layout=None): 
    return 'annotation to be handled\n' if style is 'imn' else super().render(depth,style,layout)
## TODO
class bbox(basewid): pass

if __name__ == '__main__':
  args = get_args()
  with open(args.file, 'r')   as inf1: conf = json.load(inf1)
  with open(args.layout, 'r') as inf2: layo = json.load(inf2)

  scen = compose('scenario',conf)
  locs = compose('scenlayout',layo)

  #print(traverse(scen,'scenario',0,'basic',locs))
  #print(traverse(locs,'scenlayout',  0,'basic',locs))

  ret = scen.render(0,'imn',locs)
  ret += locs.render(0,'imn',None)
  print(ret)
