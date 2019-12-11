#!/usr/bin/python3

from   argparse import ArgumentParser
from   inspect  import isclass
from   scenexec import execute
import json
import os

# Parse arguments
def get_args():
  p = ArgumentParser(description='CLOSURE Scenario Configuration')
  p.add_argument('-f', '--file', required=True, type=str, help='Input config file')
  p.add_argument('-l', '--layout', required=True, type=str, help='Input layout file')
  p.add_argument('-s', '--settings', required=True, type=str, help='Emulator settings file')
  p.add_argument('-o', '--outfile', required=True, type=str, help='Output IMN file')
  return p.parse_args()

# Base class for object containment hierarchy built from JSON
class base: 
  def __init__(self,**kwargs): 
    for k in kwargs: setattr(self,k,kwargs[k])
  def render(self,depth,style='basic',layout=None, settings=None): 
    if style is not 'basic': raise Exception('Unsupported style: ' + style)
    return ' ' * depth + self.__class__.__name__ + '\n'
  def field_render(depth,fldval,fldnam,style='basic',layout=None, settings=None): 
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
    ret += v.render(depth,style=style,layout=layout,settings=None)
    for i in fields(v): 
      x = getattr(v,i)
      if isinstance(x,list):
        ret += ''.join([traverse(j,i,depth+1,style,layout) for j in x])
      else:
        ret += traverse(x,i,depth+1,style,layout)
  else:
    ret += base.field_render(depth,v,name,style,layout=layout,settings=None)
  return ret

# Generic rendering of all children that are class instances or list thereof
def render_children(v,depth,style,layout,settings,exclude=[]): 
  ret = ''
  for i in fields(v): 
    if i in exclude: continue
    x = getattr(v,i)
    if isinstance(x,list):
      ret += ''.join([j.render(depth+1,style,layout,settings) for j in x])
    elif valid_class_instance(x): 
      ret += x.render(depth+1,style,layout,settings)
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
    if nm in self.nm2id:
      return self.nm2id[nm]
    else:
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
  def render(self,depth,style='imn',layout=None,settings=None): 
    return render_children(self,depth,style,layout,settings) if style is 'imn' else super().render(depth,style,layout,settings)

#####################################################################################################
# Scenario classes derived from basewid
class scenario(basewid): 
  def get_hostnames(self):
    names = []
    for e in self.enclave:
       for h in e.xdhost + e.inthost:
         names.append(h.hostname)
    for h in self.xdgateway:
      names.append(h.hostname)
    return names

  def render_addons(self, depth, style, layout, settings):
    #instantiation hook
    ret = 'hook 3:instantiation_hook.sh {\n'
    for n in self.get_hostnames():
      ret += f'    mkdir $SESSION_DIR/{n}.conf/scripts\n'
      ret += f'    cp -r {settings.emuroot}/scripts/* $SESSION_DIR/{n}.conf/scripts\n' 
    ret += '}\n'
    return ret if style is 'imn' else ""

  def render(self, depth, style='imn', layout=None, settings=None):
    return super().render(depth,style,layout,settings) + self.render_addons(depth,style,layout,settings)
     
class enclave(basewid):  pass # use basewid rendering

class xdhost(basewid): 
  def render(self,depth,style='imn',layout=None,settings=None):
    if style is 'imn':
      ret = ""
      nid = basewid.__idgen__.get_id(self.hostname, type(self).__name__)
      nodelayout = layout.get_node_layout(self.hostname)
      ret+=f'''node {nid} {{
    type router
    model host
    network-config {{
\thostname {self.hostname}
\t!
'''   
      ret += self.nwconf.render(depth, style, layout,settings)
      ret += '    }\n'
      ret += nodelayout.render(depth,style,layout,settings)
      ret += self.swconf.render(depth,style,layout,settings)
      for p in self.ifpeer:
        ret += p.render(depth, style, layout, settings)
      ret += self.custom.render(depth, style, layout, settings)
      ret += '}\n'
      cmdup= "cmdup=("
      for c in gen_cmdup(self, settings):
        cmdup += f"'{c}', "
      cmdup += ')'
      ret = ret.replace('cmdup=XXX', cmdup)
      return ret
    else:
      return super().render(depth,style,layout,settings)

class inthost(basewid):
  def render(self,depth,style='imn',layout=None,settings=None):
    if style is 'imn':
      nid = basewid.__idgen__.get_id(self.hostname, type(self).__name__)
      nodelayout = layout.get_node_layout(self.hostname)
      ret=f'''node {nid} {{
    type router
    model host
    network-config {{
\thostname {self.hostname}
\t!\n'''   
      ret += self.nwconf.render(depth, style, layout, settings)
      ret += '    }\n'
      ret += nodelayout.render(depth, style, layout, settings)
      ret += self.swconf.render(depth, style, layout, settings)
      for p in self.ifpeer:
        ret += p.render(depth, style, layout, settings)
      ret += self.custom.render(depth, style, layout, settings)
      ret += '}\n'
      cmdup= "cmdup=("
      for c in gen_cmdup(self, settings):
        cmdup += f"'{c}', "
      cmdup += ')'
      ret = ret.replace('cmdup=XXX', cmdup)
      return ret
    else:
      return super().render(depth, style, layout, settings)

class hub(basewid): 
  def render(self,depth,style='imn',layout=None,settings=None):
    if style is 'imn':
      nid = basewid.__idgen__.get_id(self.hostname, type(self).__name__)
      nodelayout = layout.get_node_layout(self.hostname)
      ret=f'''node {nid} {{
    type hub
    network-config {{
\thostname {self.hostname}
\t!
    }}\n'''
      ret += nodelayout.render(depth, style, layout, settings)
      for i in self.ifpeer:
        ret += i.render(depth, style, layout, settings)
      ret += '}\n'
      return ret
    else:
      return super().render(depth, style, layout, settings)

class xdgateway(basewid): 
  def render(self,depth, style='imn',layout=None,settings=None):
    if style is 'imn':
      nid = basewid.__idgen__.get_id(self.hostname, type(self).__name__)
      nodelayout = layout.get_node_layout(self.hostname)
      ret=f'''node {nid} {{
    type router
    model host
    network-config {{
\thostname {self.hostname}
\t!
'''
      ret += self.nwconf.render(depth, style, layout, settings)
      ret += '    }\n'
      ret += nodelayout.render(depth, style, layout, settings)
      ret += self.swconf.render(depth, style, layout, settings)
      for p in self.ifpeer:
        ret += p.render(depth,style, layout, settings)
      ret += self.custom.render(depth, style, layout, settings)
      ret += '}\n'
      cmdup= "cmdup=("
      for c in gen_cmdup(self, settings):
        cmdup += f"'{c}', "
      cmdup += ')'
      ret = ret.replace('cmdup=XXX', cmdup)
      return ret
    else:
      return super().render(depth,style,layout,settings)

class link(basewid): 
  def render(self,depth,style='imn',layout=None,settings=None):
    lid = basewid.__idgen__.get_id(self.f+'<-->'+self.t, type(self).__name__)
    return f'''link {lid} {{
    nodes {{{basewid.__idgen__.get_id(self.f, type(self).__name__)} {basewid.__idgen__.get_id(self.t, type(self).__name__)}}}
    bandwidth {self.bandwidth}
    delay {self.delay}
}}\n''' if style is 'imn' else super().render(depth,style,layout,settings)

class xdlink(basewid): 
  def render(self,depth,style='imn',layout=None,settings=None):
    if style is 'imn':
      ret = self.left.render(depth,style,layout,settings)
      ret += self.right.render(depth,style,layout,settings)
      return ret
    else:
      return super().render(depth,style,layout,settings)

## TODO
class hwconf(basewid): pass

class swconf(basewid):
  def render(self, depth, style='imn', layout=None,settings=None):
    svcs = ' '.join(svc.s for svc in self.service) 
    ret = f'    services {{{svcs}}}\n'
    return ret if style is 'imn' else super().render(depth, style, layout, settings)

class nwconf(basewid):
  def render(self, depth, style='imn', layout=None, settings=None):
    if style is 'imn':
      ret = ""
      for i in self.interface:
        ret += i.render(depth, style, layout, settings)
      return ret
    else:
      return super().render(depth,style,layout,settings)

class interface(basewid):
  def render(self, depth, style='imn', layout=None, settings=None):
    return f"\tinterface {self.ifname}\n\tip address {self.addr}\n\t!\n" if style is 'imn' else super().render(depth,style,layout,settings)

class ifpeer(basewid):
  def render(self, depth, style='imn', layout=None, settings=None):
      return f'    interface-peer {{{self.ifname} {basewid.__idgen__.get_id(self.peername, "NODE")}}}\n' if style is 'imn' else super().render(depth,style,layout,settings)
      
class left(basewid):
  def render(self, depth, style='imn', layout=None, settings=None):
    lid = basewid.__idgen__.get_id(self.f+'<-->'+self.t, type(self).__name__)
    return f'''link {lid} {{
    nodes {{{basewid.__idgen__.get_id(self.f, type(self).__name__)} {basewid.__idgen__.get_id(self.t, type(self).__name__)}}}
    bandwidth {{{self.egress.bandwidth} {self.ingress.bandwidth}}}
    delay {{{self.egress.delay} {self.ingress.delay}}}
}}\n''' if style is 'imn' else super().render(depth,style,layout,settings)

class right(basewid):
  def render(self, depth, style='imn', layout=None, settings=None):
    lid = basewid.__idgen__.get_id(self.f+'<-->'+self.t, type(self).__name__)
    return f'''link {lid} {{
    nodes {{{basewid.__idgen__.get_id(self.f, type(self).__name__)} {basewid.__idgen__.get_id(self.t, type(self).__name__)}}}
    bandwidth {{{self.egress.bandwidth} {self.ingress.bandwidth}}}
    delay {{{self.egress.delay} {self.ingress.delay}}}
}}\n''' if style is 'imn' else super().render(depth,style,layout,settings)

## TODO      
class egress(basewid): pass
## TODO
class ingress(basewid): pass

# Layout classes
class scenlayout(basewid): 
  def render(self,depth,style='imn',layout=None,settings=None): 
    return render_children(self,depth,style,layout,settings,exclude=['nodelayout', 'custom_config', 'nodeservice']) if style is 'imn' else super().render(depth,style,layout,settings)
  def get_node_layout(self, nod):
    x = [n for n in self.nodelayout if n.hostname == nod]
    if len(x) != 1: raise Exception ('Error getting layout for:' + nod)
    return x[0]
  def get_node_service(self, nod):
    x = [n for n in self.nodeservice if n.hostname == nod]
    if len(x) != 1: raise Exception ('Error getting layout for:' + nod)
    return x[0] 

class option(basewid): pass 

class optglobal(basewid):
  def render(self,depth,style='imn',layout=None,settings=None):
    return f'''option global {{
    interface_names {self.interface_names}
    ip_addresses {self.ip_addresses}
    ipv6_addresses {self.ipv6_addresses}
    node_labels {self.node_labels}
    link_labels {self.link_labels}
    show_api {self.show_api}
    background_images {self.background_images}
    annotations {self.annotations}
    grid {self.grid}
    traffic_start {self.traffic_start}
}}\n''' if style is 'imn' else super().render(depth,style,layout,settings)

class session(basewid):
  def render(self,depth,style='imn',layout=None,settings=None): 
    return 'option session { }\n' if style is 'imn' else super().render(depth,style,layout,settings)

class canvas(basewid):
  def render(self,depth,style='imn',layout=None,settings=None): 
    cid = basewid.get_id(self.name,'canvas')
    return 'canvas %s { name { %s } }\n' % (cid,self.name) if style is 'imn' else super().render(depth,style,layout,settings)

class annotation(basewid):
  def render(self,depth,style='imn',layout=None,settings=None):
    aid = basewid.get_id(None,'annotation')
    return f'''annotation {aid} {{
    {self.bbox.render(depth, style, layout, settings)}
    type {self.type}
    label {self.label}
    labelcolor {self.labelcolor}
    fontfamily {self.fontfamily}
    fontsize {self.fontsize}
    color {self.color}
    width {self.width}
    border {self.border}
    rad {self.rad}
    canvas {basewid.__idgen__.get_id(self.canvas, 'canvas')}
}}\n''' if style is 'imn' else super().render(depth,style,layout,settings)

class bbox(basewid):
  def render(self, depth, style='imn', layout=None, settings=None):
    return f'iconcoords {{{self.x1} {self.y1} {self.x2} {self.y2}}}' if style is 'imn' else super().render(depth,style,layout,settings)

class nodelayout(basewid):
  def render(self, depth, style='imn', layout=None, settings=None):
    return f'    canvas {basewid.__idgen__.get_id(self.canvas, "canvas")}\n    {self.iconcoords.render(depth, style, layout, settings)}\n    {self.labelcoords.render(depth, style, layout, settings)}\n' if style is 'imn' else super().render(depth,style,layout,settings)

class iconcoords(basewid):
  def render(self, depth, style='imn', layout=None,settings=None):
    return f'iconcoords {{{self.x} {self.y}}}' if style is 'imn' else super().render(depth,style,layout,settings)

class labelcoords(basewid):
  def render(self, depth, style='imn', layout=None, settings=None):
    return f'labelcoords {{{self.x} {self.y}}}' if style is 'imn' else super().render(depth,style,layout,settings)

class custom(basewid):
  def render (self, depth, style='imn', layout=None, settings=None):
    return f'    custom-config {{\n\tcustom-config-id {self.custom_config_id}\n\tcustom-command {self.custom_command}\n\t' + self.config.render(depth, style, layout, settings) + f'    }}\n' 

class config (basewid):
  def render(self, depth, style='imn', layout=None, settings=None):
    dirstr = 'dirs=('
    for dir in self.dirs:
      dirstr += f"'{dir.d}', "
    cmdupstr = 'cmdup=XXX'
    return f'config {{\n\t{dirstr} )\n\t{cmdupstr}\n    \t}}\n' if style is 'imn' else super().render(depth,style,layout,settings)

class dirs (basewid): pass
class service(basewid): pass
class settings(basewid): pass

def gen_cmdup(x, settings):
  cmds = []
  cmds.append(f'scripts/common/ssh_setup.sh {settings.emuroot}/{settings.snapdir}')
  if type(x).__name__ is 'xdhost':
    cmds.append(f'scripts/xdhost/bridge_and_tap.sh')
    cmds.append(f'scripts/xdhost/start_qemu.sh {x.hwconf.arch} {settings.emuroot}/{settings.snapdir}/{x.swconf.os}-{x.hwconf.arch}-{x.hostname}.qcow2 {settings.imgdir}/linux-kernel-{x.hwconf.arch}-{x.swconf.kernel} {os.environ["USER"]}')
  return cmds

if __name__ == '__main__':
  args = get_args()
  with open(args.file, 'r')     as inf1: conf = json.load(inf1)
  with open(args.layout, 'r')   as inf2: layo = json.load(inf2)
  with open(args.settings, 'r') as inf3: sett = json.load(inf3)
  scen = compose('scenario',conf)
  locs = compose('scenlayout',layo)
  sets = compose('settings', sett)

  ret = scen.render(0,'imn',locs,sets)
  ret += locs.render(0,'imn',None, None)
  
  with open(args.outfile,'w') as outf: outf.write(ret)
  outf.close()

  execute(scen, locs, sets, args)

  #print(traverse(scen','scenario',0,'basic',locs))
  #print(traverse(locs,'scenlayout',  0,'basic',locs))
  #print(basewid.__idgen__.nm2id)
