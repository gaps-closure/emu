#!/usr/bin/python3

from   argparse import ArgumentParser
from   inspect  import isclass
import json

# Parse arguments
def get_args():
  p = ArgumentParser(description='CLOSURE Scenario Configuration')
  p.add_argument('-f', '--file', required=True, type=str, help='Input config file')
  p.add_argument('-l', '--layout', required=True, type=str, help='Input layout file')
  return p.parse_args()

# Base class for object containment hierarchy built from JSON
class base: 
  def __init__(self,**kwargs): 
    for k in kwargs: setattr(self,k,kwargs[k])
  def render(self,depth,style='basic',layout=None): 
    if style is not 'basic': raise Exception('Unsupported style: ' + style)
    return ' ' * depth + self.__class__.__name__ + '\n'
  def field_render(depth,fldval,fldnam,style='basic',layout=None): 
    if style is not 'basic': raise Exception('Unsupported style: ' + style)
    return ' ' * depth + fldnam + ':' + str(fldval) + '\n'

# Return non-function, non-internal fields of scenario class instance
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
      pass # note, we ignore all non class fields in generic render_children
  return ret

##############################################
# IMN scenario generator specifc code below

class IDGen():
  def __init__(self):
    self.nid = 0
    self.lid = 0
    self.cid = 0
    self.aid = 0
    self.nm2id = {}

  def get_id(self,nm,typ):
    if nm is None or nm not in self.nm2id: 
      if typ in ['NODE', 'xdhost', 'inthost', 'hub', 'xdgateway']:
        self.nid += 1
        mnm = 'n'+str(self.nid)
      elif typ in ['link', 'left', 'right']:
        self.lid += 1
        mnm = 'l'+str(self.lid)
      elif typ in ['canvas']:
        self.cid += 1
        mnm = 'c'+str(self.cid)
      elif typ in ['annotation']:
        self.aid += 1
        mnm = 'a'+str(self.aid) 
    self.nm2id[mnm if nm is None else nm] = mnm 
    return mnm

# Extend base with a class member and class method for ID generation/mapping
class basewid(base):  
  __idgen__ = IDGen()  
  def get_id(nm,typ): return basewid.__idgen__.get_id(nm,typ)
  def render(self,depth,style='imn',layout=None): 
    return render_children(self,depth,style,layout) if style is 'imn' else super().render(depth,style,layout)

#####################################################################################################
# Scenario classes derived from basewid
class scenario(basewid): pass # use basewid rendering
class enclave(basewid):  pass # use basewid rendering

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
    tstr = 'hub to be handled, use of get_id: ' + self.hostname + ' ' + basewid.get_id(self.hostname,'hub')
    return tstr + '\n' if style is 'imn' else super().render(depth,style,layout)

## TODO
class xdgateway(basewid): 
  def render(self,depth,style='imn',layout=None): 
    return 'xdgateway to be handled\n' if style is 'imn' else super().render(depth,style,layout)

## TODO
class link(basewid): 
  def render(self,depth,style='imn',layout=None): 
    lid = basewid.get_id(None,'link')
    return 'link %s { to be handled ... }\n' % (lid) if style is 'imn' else super().render(depth,style,layout)

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

class option(basewid): pass # use basewid rendering

## TODO
class optglobal(basewid):
  def render(self,depth,style='imn',layout=None): 
    return 'option global { to be handled ... }\n' if style is 'imn' else super().render(depth,style,layout)

## TODO
class session(basewid):
  def render(self,depth,style='imn',layout=None): 
    return 'option session { to be handled ... }\n' if style is 'imn' else super().render(depth,style,layout)

class canvas(basewid):
  def render(self,depth,style='imn',layout=None): 
    cid = basewid.get_id(self.name,'canvas')
    return 'canvas %s { name { %s } }\n' % (cid,self.name) if style is 'imn' else super().render(depth,style,layout)

## TODO
class annotation(basewid):
  def render(self,depth,style='imn',layout=None): 
    aid = basewid.get_id(None,'annotation')
    return 'annotation %s { to be handled ... }\n' % (aid) if style is 'imn' else super().render(depth,style,layout)

## TODO
class bbox(basewid): pass

## TODO
class nodelayout(basewid): pass

## TODO
class iconcoords(basewid): pass

## TODO
class labelcoords(basewid): pass

if __name__ == '__main__':
  args = get_args()
  with open(args.file, 'r')   as inf1: conf = json.load(inf1)
  with open(args.layout, 'r') as inf2: layo = json.load(inf2)

  scen = compose('scenario',conf)
  locs = compose('scenlayout',layo)

  ret = scen.render(0,'imn',locs)
  ret += locs.render(0,'imn',None)
  with open('out.imn','w') as outf: outf.write(ret)  # XXX: make output file an argument?

  #print(traverse(scen,'scenario',0,'basic',locs))
  #print(traverse(locs,'scenlayout',  0,'basic',locs))
  #print(basewid.__idgen__.nm2id)
