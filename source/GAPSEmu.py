from FixedData import ICoords as IC
from FixedData import LCoords as LC
from FixedData import POSTAMBLE

#Model Types
BITW = 0
BKND = 1

#Globals
nid = 0
eid = 0
linkId = 0

def new_nid():
    global nid
    nid = nid + 1
    return nid 

def new_eid():
    global eid
    eid = eid + 1
    return eid

def new_linkId():
    global linkId
    linkId = linkId + 1
    return linkId

class Enclave:
    def __init__(self, color, lan_size):
        self.eid = new_eid()
        self.color = color
        self.hub = Hub(color)
        self.lan_nodes = self.make_lan_nodes(lan_size)
        self.enclave_gateway = EnclaveGateway(color, self.eid, self.hub)

    def make_lan_nodes(self, lan_size):
        ret = {}
        for lid in range(0, lan_size):
            l = LanNode(self.color, self.eid, lid+1, self.hub)
            ret[lid] = l
        return ret

    def render_imn(self):
        ret = ""
        ret += self.enclave_gateway.render_imn()
        links = []
        for l in self.lan_nodes:
            ret += self.lan_nodes[l].render_imn()
            links += self.lan_nodes[l].links
        ret += self.hub.render_imn()
        links += self.enclave_gateway.links
        for link in links:
            ret += link.render_imn()
        return ret

class Hub:
    def __init__(self, color):
        self.nid = new_nid()
        self.color = color
        self.if_peers = {}

    def add_peer(self, peer):
        if peer in self.if_peers:
            raise Exception
        self.if_peers[peer] = "e%d" % (len(self.if_peers))
    def render_imn(self):
        hostname = self.color + "-local-net"
        ret = """
node n%d {
    type hub
    network-config {
\thostname %s
\t!
    }
    canvas c1
    iconcoords {%s}
    labelcoords {%s}\n""" % (self.nid, hostname, IC[hostname], LC[hostname])
        for n in self.if_peers:
            ret += "    interface-peer {%s %s}\n" % (n, self.if_peers[n])
        ret += "}\n"
        return ret

class EnclaveGateway:
    def __init__(self, color, eid, hub):
        self.nid = new_nid()
        self.eid = eid
        self.color = color
        self.hub = hub
        self.ifAddresses = {}
        self.ifPeers = {}
        self.links = []
        self.xd_gateway = None
        self.links += [Link(self.nid, self.hub.nid)]

    def set_xd_gateway(self, xd_gateway):
        self.xd_gateway = xd_gateway
        self.links += [Link(self.nid, self.xd_gateway.nid)]
        
    def render_imn(self):
        hostname = self.color + "-enclave-gw"
        ret = """
node n%d {
    type router
    model host
    network-config {
\thostname %s
\t!
\tinterface eth0
\t ip address 10.%d.%d.100/24
\t!
\tinterface eth1
\t ip address 10.0.%d.10/24
\t!
    }
    canvas c1
    iconcoords {%s}
    labelcoords {%s}\n""" % (self.nid, hostname, self.eid, self.eid, self.eid, IC[hostname], LC[hostname])
        ret += "    interface-peer {eth0 n%d}\n" % (self.hub.nid)
        ret += "    interface-peer {eth1 n%d}\n" % (self.xd_gateway.nid)
        ret += "}\n"
        return ret
        
class LanNode:
    def __init__(self, color, eid, lid, hub):
        self.nid = new_nid()
        self.color = color
        self.eid = eid
        self.lid = lid
        self.hub = hub
        self.links = []
        self.links += [Link(self.nid, self.hub.nid)]
        
    def render_imn(self):
        hostname = "%s-%d" % (self.color, self.lid)
        return """
node n%d {
    type router
    model host
    network-config {
\thostname %s
\t!
\tinterface eth0
\t ip address 10.%d.%d.%d/24
\t!
    }
    canvas c1
    iconcoords {%s}
    labelcoords {%s}
    interface-peer {eth0 n%d}
}\n""" % (self.nid, hostname, self.eid, self.eid, 100+self.lid, IC[hostname], LC[hostname], self.hub.nid)

class XDomainGateway:
    def __init__(self, enclaves):
        self.nid = new_nid()
        self.enclaves = enclaves

    def render_imn(self):
        hostname = "cross-domain-gw-%d" % (self.nid)
        ret = """
node n%d {
    type router
    model router
    network-config {
\thostname %s
\t!\n""" % (self.nid, hostname)
        for e in self.enclaves:
            ret += "\tinterface eth%d\n\t ip address 10.0.%d.1/24\n\t!\n" % (e.eid-1, e.eid)
        ret += """    }
    canvas c1
    iconcoords {%s}
    labelcoords {%s}\n""" % (IC[hostname], LC[hostname])
        for e in self.enclaves:
            ret += "    interface-peer {eth%d n%d}\n" % (e.eid-1, e.enclave_gateway.nid)
        ret += "    services {IPForward}\n}\n"
        return ret

class Link:
    def __init__(self, n1,n2):
        self.linkId = new_linkId()
        self.n1 = n1
        self.n2 = n2
        self.bandwidth = 0
    def render_imn(self):
        return "\nlink l%d {\n    nodes {n%d n%d}\n    bandwidth %d\n}\n" % (self.linkId, self.n1, self.n2, self.bandwidth)
    
class Scenario:
    def __init__(self, name, mode):
        self.name = name
        self.imn_file = "%s.imn" % (self.name)
        self.mode = mode
        self.enclaves = {}
        self.xd_gateways = {}
        self.node_count = 0

    def add_enclave(self, color, lan_size):
        if color in self.enclaves:
            raise Exception
        enclave = Enclave(color, lan_size)
        self.enclaves[color] = enclave

    def add_xdGateway(self, colors):
        enclaves = []
        for c in colors:
            enclaves += [self.enclaves[c]]
        xdg = XDomainGateway(enclaves)
        for c in colors:
            self.enclaves[c].enclave_gateway.set_xd_gateway(xdg)
        self.xd_gateways[xdg.nid] = xdg

    def render_imn(self):
        ret = ""
        for color in self.enclaves:
            ret += self.enclaves[color].render_imn()
        for xdg in self.xd_gateways:
            ret += self.xd_gateways[xdg].render_imn()
        ret += POSTAMBLE
        return ret
