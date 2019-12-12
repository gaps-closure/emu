ICoords = {"orange-enclave-gw": "265.0 171.0",
           "purple-enclave-gw": "697.0 168.0",
           "orange-1":          "122.0 74.0",
           "orange-2":          "121.0 265.0",
           "purple-2":          "839.0 268.0",
           "purple-1":          "837.0 72.0",
           "orange-local-net":  "121.0 171.0",
           "purple-local-net":  "838.0 167.0",
           "cross-domain-gw-9": "483.0 169.0"}

LCoords = {"orange-enclave-gw": "265.0 203.0",
           "purple-enclave-gw": "697.0 200.0",
           "orange-1":          "122.0 106.0",
           "orange-2":          "121.0 297.0",
           "purple-2":          "838.0 300.0",
           "purple-1":          "837.0 104.0",
           "orange-local-net":  "121.0 195.0",
           "purple-local-net":  "838.0 191.0",
           "cross-domain-gw-9": "483.0 201.0"}

POSTAMBLE='''
annotation a1 {
    iconcoords {56.0 36.0 399.0 322.0}
    type rectangle
    label {}
    labelcolor black
    fontfamily {Arial}
    fontsize {12}
    color #ff8c00
    width 0
    border black
    rad 25
    canvas c1
}

annotation a2 {
    iconcoords {607.0 41.0 918.0 327.0}
    type rectangle
    label {}
    labelcolor black
    fontfamily {Arial}
    fontsize {12}
    color #c300ff
    width 0
    border black
    rad 25
    canvas c1
}

canvas c1 {
    name {Canvas1}
}

option global {
    interface_names no
    ip_addresses no
    ipv6_addresses no
    node_labels yes
    link_labels yes
    show_api no
    background_images no
    annotations yes
    grid yes
    traffic_start 0
}

option session {
}
'''

#Model Types
BITW = 0
BKND = 1

#Supported Architctures
X86_64 = 0
ARM64  = 1

