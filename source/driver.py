import GAPSEmu as GAPS

scenario = GAPS.Scenario("2enclave")
scenario.add_enclave("orange", GAPS.X86_64, 2)
scenario.add_enclave("purple", GAPS.X86_64, 2)
scenario.add_xdGateway("orange", "purple", GAPS.BITW)
scenario.start()
