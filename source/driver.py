import GAPSEmu as GAPS

scenario = GAPS.Scenario("2enclave")
scenario.add_enclave("orange", 2)
scenario.add_enclave("purple", 2)
scenario.add_xdGateway("orange", "purple", GAPS.BITW)
print(scenario.render_imn())
