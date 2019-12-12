import os
import subprocess
import time

def execute(scenario, layout, settings, args):
    create_qemu_snapshots(scenario, settings, clean=False)
    start_core_scenario(scenario, settings, args.outfile)
    check_vm_status(scenario, settings)

def clean_snapshots(settings):
    subprocess.run(['rm', '-rf', settings.snapdir])

def create_qemu_snapshots(scenario, settings, clean=True):
    if clean: clean_snapshots(settings)
    IMGDIR = settings.imgdir
    SNAPDIR = settings.snapdir
    QSCRIPTSDIR = settings.emuroot + '/scripts/qemu'
    if not os.path.exists(SNAPDIR):
        os.mkdir(SNAPDIR)
    for enc in scenario.enclave:
        for x in enc.xdhost:
            GIMG = f'{IMGDIR}/{x.swconf.os}-{x.hwconf.arch}-{x.swconf.distro}-qemu.qcow2'
            if not os.path.exists(GIMG):
                raise Exception ("Golden Image not found: " + GIMG)
            KRNL = f'{IMGDIR}/linux-kernel-{x.hwconf.arch}-{x.swconf.kernel}'
            setattr(x, 'kernel', KRNL)
            if not os.path.exists(KRNL):
                raise Exception ("Kernel not found: " + KRNL)
            QARCH = x.hwconf.arch
            OFIL = f'{x.swconf.os}-{x.hwconf.arch}-{x.hostname}.qcow2'
            setattr(x, 'snap', OFIL)
            if os.path.exists(f'{SNAPDIR}/{OFIL}'):
                print(f'Using pre-existing snapshot for {x.hostname}: {OFIL}')
                continue
            make_netplan(x, f'{SNAPDIR}/{OFIL}.np')
            NPLN = f'{OFIL}.np'
            subprocess.run([f'{QSCRIPTSDIR}/emulator_customize.sh', '-g', GIMG, '-k', KRNL, '-a', QARCH, '-o', OFIL, '-n', NPLN, '-b', SNAPDIR])

def make_netplan(xdhost, outfile):
    ifmap = {}
    arch = xdhost.hwconf.arch
    for i in xdhost.nwconf.interface:
        n = int(i.ifname[3:])
        # HACK until interfaces can be ordered/named same per arch
        if arch == 'arm64':
            n += 1
        elif arch == 'amd64':
            n += 3
        if n in ifmap:
            raise Exception ("invalid nwconf for: " + xdhost.hostname)
        ifmap[n] = i.addr
    mgmt_n = 0 if arch == 'arm64' else max(ifmap.keys()) + 1
    ifmap[mgmt_n] = "10.200.0.1/24"
    
    np = 'network:\n  version: 2\n  renderer: networkd\n  ethernets:\n'
    for n,ip in sorted(ifmap.items()):
            ifname = 'ens'+str(n) if arch == 'amd64' else 'eth'+str(n)
            np += f'    {ifname}:\n      addresses:\n        - {ip}\n'
    with open(outfile, 'w') as outf: outf.write(np)
    outf.close()

def start_core_scenario(scenario, settings, filename):
    if not os.path.exists(filename):
        raise Exception ("CORE scenario file not found: " + filename)
    print(f'Starting CORE session (filename={filename})...', end="", flush=True)
    subprocess.Popen(["core-gui", "-s", filename], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(2) # give CORE a chance to start
    p = subprocess.run([settings.emuroot + '/scripts/core/get_core_session.sh'], stdout=subprocess.PIPE)
    setattr(scenario, 'core_session_id', int(p.stdout))
    tries = 0
    while(tries < settings.core_timeout):
        f = open(f'/tmp/pycore.{scenario.core_session_id}/state', 'r')
        if 'RUNTIME' in f.readline():
            print(f'pycore={scenario.core_session_id}...DONE!', flush=True)
            f.close()
            return
        tries+=1
        time.sleep(1)
    raise Exception('ERROR: CORE session failed to start')

def check_vm_status(scenario, settings):
    for enc in scenario.enclave:
        for x in enc.xdhost:
            print(f'Checking QEMU up at {x.hostname}...', end="", flush=True)
            core_path = f'/tmp/pycore.{scenario.core_session_id}/{x.hostname}'
            res = subprocess.check_output(['vcmd', '-c', core_path, '--', 'scripts/xdhost/check_vm.sh'], text=True)
            if 'SUCCESS' not in res:
                raise Exception (f'Failure to boot/ssh into {x.hostname}: {res}')
            print('DONE!', flush=True)

