#!/usr/bin/python3
import os
import os.path
import subprocess
import time

DBG=False

def execute(scenario, layout, settings, args):
    create_qemu_snapshots(scenario, settings, clean=False)
    start_core_scenario(scenario, settings, args.imnAbsPath)
    #cmdup commands executed per node (see IMN file)
    check_vm_status(scenario, settings)
    configure_xdgateways_nc(scenario)
    configure_xdhosts_nc_socat(scenario, settings)
    install_apps(scenario, settings)
    install_env_variables(scenario, settings)
    install_start_hal(scenario, settings)

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
            subprocess.run([f'{QSCRIPTSDIR}/qemu-emulator-customize.sh', '-g', GIMG, '-k', KRNL, '-a', QARCH, '-o', OFIL, '-n', NPLN, '-b', SNAPDIR])

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
    if os.environ.get('CORE_NO_GUI') is not None:
        opt_inter = "-b"
        print(f'Starting CORE session with no GUI (filename={filename})...', end="", flush=True)
    else:
        opt_inter = "-s"
        print(f'Starting CORE session (filename={filename})...', end="", flush=True)
    subprocess.Popen(["core-gui", opt_inter, filename], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(5) # give CORE a chance to start
    p = subprocess.run([settings.emuroot + '/scripts/core/core-get-session-id.sh'], stdout=subprocess.PIPE)
    id = 0
    for tok in ((p.stdout).decode("utf-8")).split():
        if tok.startswith('pycore.'):
            id = tok.split('.')[-1]
    if not id:
        raise Exception('ERROR: unable to obtain core session id')
    setattr(scenario, 'core_session_id', int(id))
    tries = 0
    while(tries < settings.core_timeout):
        f = open(f'/tmp/pycore.{scenario.core_session_id}/state', 'r')
        if 'RUNTIME' in f.readline():
            print(f'pycore={scenario.core_session_id}...DONE!', flush=True)
            f.close()
            return
        tries+=1
        f.close()
        time.sleep(1)
    raise Exception('ERROR: CORE session failed to start')

def check_vm_status(scenario, settings):
    for enc in scenario.enclave:
        for x in enc.xdhost:
            print(f'Checking QEMU up at {x.hostname}...', end="", flush=True)
            core_path = f'/tmp/pycore.{scenario.core_session_id}/{x.hostname}'
            res = subprocess.check_output(['vcmd', '-c', core_path, '--', 'scripts/xdh/xdh-check-qemu-up.sh'], text=True)
            if DBG: print(res)
            if 'SUCCESS' not in res:
                raise Exception (f'Failure to boot/ssh into {x.hostname}: {res}')
            print('DONE!', flush=True)

def configure_xdgateways_nc(scenario):
    for xdg in scenario.xdgateway:
        xdls = scenario.get_xdlinks_for_xdgateway(xdg)
        if len(xdls) > 1:
            raise('Scenario Generator does not currently support multiple xdlinks per gateway')
        for xdl in xdls:
            models = ['passthru', 'bknd', 'bitw']
            if xdl.model.lower() not in models:
                raise(f'xdlink model {xdl.model} not supported, choose from {models}')
            lhost = xdl.left.f
            rhost = xdl.right.t
            print(f'Configuring {xdg.hostname} as {xdl.model.upper()}...', end="", flush=True)

            ethPeers = {}
            interfaces = {}
            for p in xdg.ifpeer:
                ethPeers[p.peername] = p.ifname
            for i in xdg.nwconf.interface:
                interfaces[i.ifname] = i.addr.split('/')[0]

            left_ip = interfaces[ethPeers[lhost]]
            right_ip = interfaces[ethPeers[rhost]]
            lispec = xdl.left.ingress.filterspec
            lespec = xdl.left.egress.filterspec
            rispec = xdl.right.ingress.filterspec
            respec = xdl.right.egress.filterspec

            core_path = f'/tmp/pycore.{scenario.core_session_id}/{xdg.hostname}'
            args = [left_ip, '12345', right_ip, '12346']
            if xdl.model == 'bitw':
                args += [lispec, respec, rispec, lespec]
            cmd = ['vcmd', '-c', core_path, '--', f'scripts/xdg/xdg-config-{xdl.model.lower()}-nc.sh'] + args
            #print('exec: '+ ' '.join(cmd), flush=True)
            res = subprocess.check_output(cmd, text=True)
            if DBG: print(res)
            if 'SUCCESS' not in res:
                raise Exception (f'Failure to start nc at {xdg.hostname}')
            print('DONE!', flush=True)

def configure_xdhosts_nc_socat(scenario, settings):
    for xdl in scenario.xdlink:
        lhost = xdl.left.f
        rhost = xdl.right.t
        ghost = xdl.left.t
        lispec = xdl.left.ingress.filterspec
        lespec = xdl.left.egress.filterspec
        rispec = xdl.right.ingress.filterspec
        respec = xdl.right.egress.filterspec

        for xdg in scenario.xdgateway:
            if xdg.hostname == ghost:
                ethPeers = {}
                interfaces = {}
                for p in xdg.ifpeer:
                    ethPeers[p.peername] = p.ifname
                for i in xdg.nwconf.interface:
                    interfaces[i.ifname] = i.addr.split('/')[0]

                if xdl.model.lower() == 'bknd':
                    #install nc on qemu
                    for h in [lhost, rhost]:
                        right_ip = interfaces[ethPeers[h]]
                        if lhost == h:
                            right_port = '12345'
                            specs = [lespec, lispec]
                        else:
                            right_port = '12346'
                            specs = [respec, rispec]
                        core_path = f'/tmp/pycore.{scenario.core_session_id}/{h}'
                        print(f'Starting nc processes on {h}...', end="", flush=True)
                        res = subprocess.check_output(['vcmd', '-c', core_path, '--', 'scripts/xdh/xdh-config-bknd-nc.sh', '127.0.0.1', '54321', right_ip, right_port, settings.mgmt_ip] + specs, text=True)
                        if DBG: print(res)
                        if 'SUCCESS' not in res:
                            raise Exception (f'Failure to start nc on {h}: {res}')
                        print('DONE!', flush=True)

                # install socat
                for h in [lhost, rhost]:
                    socat_ip = '127.0.0.1'
                    socat_port = '54321'
                    if xdl.model.lower() != 'bknd':
                        for p in xdg.ifpeer:
                            if p.peername == h:
                                socat_ip = interfaces[p.ifname]
                        if h == lhost:
                            socat_port = 12345
                        else:
                            socat_port = 12346
                    core_path = f'/tmp/pycore.{scenario.core_session_id}/{h}'
                    print(f'Starting character device (socat) on {h}...', flush =True, end="")
                    res = subprocess.check_output(['vcmd', '-c', core_path, '--', 'scripts/xdh/xdh-config-socat.sh', settings.mgmt_ip, socat_ip, str(socat_port)], text=True)
                    if DBG: print(res)
                    if 'SUCCESS' not in res:
                        raise Exception (f'Failure to start socat on {h}: {res}')
                    print('DONE!')

def install_env_variables(scenario, settings):
    for enc in scenario.enclave:
        for x in enc.xdhost:
            print(f'Setting environment variables on {x.hostname}...', end="",flush=True)
            core_path = f'/tmp/pycore.{scenario.core_session_id}/{x.hostname}'
            res = subprocess.check_output(['vcmd', '-c', core_path, '--', 'scripts/xdh/xdh-install-env-profile.sh', settings.mgmt_ip, os.environ['DISPLAY'], os.environ['TERM']], text=True)
            if DBG: print(res)
            if 'SUCCESS' not in res:
                raise Exception (f'Unable to install enviroment script on {x.hostname}: {res}')
            print('DONE!', flush=True)
            
def install_apps(scenario, settings):
    for enc in scenario.enclave:
        for x in enc.xdhost:
            print(f'Installing Apps on {x.hostname}...', end="", flush=True)
            core_path = f'/tmp/pycore.{scenario.core_session_id}/{x.hostname}'
            res = subprocess.check_output(['vcmd', '-c', core_path, '--', 'scripts/xdh/xdh-install-apps.sh', settings.mgmt_ip], text=True)
            if DBG: print(res)
            if 'SUCCESS' not in res:
                raise Exception (f'Unable to install apps on {x.hostname}: {res}')
            print('DONE!', flush=True)

def install_start_hal(scenario, settings):
    for enc in scenario.enclave:
        for x in enc.xdhost:
            print(f'Install/Start HAL on {x.hostname}...', end="", flush=True)
            core_path = f'/tmp/pycore.{scenario.core_session_id}/{x.hostname}'
            cfg = f'{settings.emuroot}/config/{scenario.qname}/{x.halconf}'
            if(os.path.isdir(f'{settings.emuroot}/../mbig/{x.hwconf.arch}')):
                hal = f'{settings.emuroot}/../mbig/{x.hwconf.arch}/hal/daemon/hal'
            else:
                hal = f'{settings.instdir}/bin/hal'
            res = subprocess.check_output(['vcmd', '-c', core_path, '--', 'mkdir', '-p', 'hal'], text=True)
            res = subprocess.check_output(['cp', cfg, f'{core_path}.conf/hal/{x.halconf}'], text=True)
            res = subprocess.check_output(['cp', hal, f'{core_path}.conf/hal/hal'], text=True)
            res = subprocess.check_output(['vcmd', '-c', core_path, '--', 'scripts/xdh/xdh-install-start-hal.sh', cfg], text=True, stderr=subprocess.STDOUT)
            if DBG: print(res)
            if 'SUCCESS' not in res:
                raise Exception (f'Unable to install/start HAL on {x.hostname}: {res}')
            print('DONE!', flush=True)
