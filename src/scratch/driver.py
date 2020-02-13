from GAPSEmu import Scenario
from Constants import BITW
from Constants import X86_64

scenario = Scenario("2enclave")
scenario.add_enclave("orange", X86_64, 2)
scenario.add_enclave("purple", X86_64, 2)
scenario.add_xdGateway("orange", "purple", BITW)
scenario.start()
