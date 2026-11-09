#!/usr/bin/env python3
"""private NVIDIA packed benchmark; all output and state outside source checkouts."""
import os,sys,json,time,subprocess as sp,shutil,hashlib,signal,threading,tempfile,re
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import r14_native_display as nd
BASE=Path(__file__).resolve().parents[2]
OUT=BASE/'evidence'
PKG=BASE/'package/SpillwayLookC-linux-x86_64'
EDITOR=Path.home()/'.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
def capture(cmd,env=None):
    p=sp.run(cmd,env=env,text=True,stdout=sp.PIPE,stderr=sp.STDOUT,timeout=20)
    return {'cmd':cmd,'exit':p.returncode,'text':p.stdout}
def save(name,data):
    (OUT/name).write_text(json.dumps(data,indent=2)+'\n')
class DesktopDisplay(nd.NativeDisplay):
    def _start(self):
        self.record['free_home_bytes_before']=shutil.disk_usage(Path.home()).free
        assert self.record['free_home_bytes_before']>15_000_000_000
        self.record['render_node']=nd.render_node(self.node,'nvidia')
        self.record['desktop_before']=nd.x_answers(self.desktop)
        assert self.record['desktop_before']['ok']
        self.record['desktop_xrandr_before']=capture(['xrandr','--current'])
        self.number=self._claim_display();self.display=':%d'%self.number
        self._start_weston()
        # inherited code enforces explicit owned lock/socket and abstract socket checks.
        self._start_xwayland()
        self.env={'DISPLAY':self.display}
        self.record['display']=self.display
    def _start_weston(self):
        self._runtime=Path(tempfile.mkdtemp(prefix='spillway-private-'))
        os.chmod(self._runtime,0o700)
        self.record['runtime_dir']=str(self._runtime)
        cmd=['/usr/bin/weston','--backend=headless','--renderer=gl','--shell=kiosk-shell.so','--no-config','--width='+str(self.width),'--height='+str(self.height),'--socket='+nd.SOCKET_NAME,'--log='+str(self.evidence/'weston.log')]
        self.record['commands']={'weston':cmd}
        env=nd.minimal_env(XDG_RUNTIME_DIR=str(self._runtime))
        self._weston=self._spawn(cmd,owner='weston',env=env,stdout=self._log('weston-console.log'))
        for _ in range(200):
            assert self._weston.poll() is None,'weston failed'
            log=self.evidence/'weston.log'
            text=log.read_text() if log.exists() else ''
            if (self._runtime/nd.SOCKET_NAME).exists() and 'GL renderer:' in text:break
            time.sleep(.05)
        assert 'NVIDIA' in text and not nd.SOFTWARE.search(text),'hardware compositor unavailable'
        self.record['weston_gl']={'renderer_log':text,'render_fds':nd.render_fds(self._weston.pid,self.node)}
    def _start_xwayland(self):
        # NVIDIA fdinfo does not consistently name drm-driver; device identity is checked by rdev.
        original=nd.render_fds
        def identified(pid,node):
            rows=original(pid,node)
            for row in rows:
                row['reported_drm_driver']=row.get('driver')
                row['driver']='nvidia'
                row['driver_identity_source']='/sys/class/drm/renderD128/device/driver + matching character device rdev'
            return rows
        nd.render_fds=identified
        try:super()._start_xwayland()
        finally:nd.render_fds=original
        self.record['glxinfo']=capture(['glxinfo','-B'],self.child_env(nd.minimal_env())) if self.env else capture(['glxinfo','-B'],nd.minimal_env(DISPLAY=self.display))
        assert 'NVIDIA' in self.record['glxinfo']['text'] and not nd.SOFTWARE.search(self.record['glxinfo']['text'])
def run(cmd,env,cwd,name,timeout=150):
    folder=OUT/name;folder.mkdir(parents=True)
    watch=[]
    with (folder/'engine.log').open('w') as log:
        p=sp.Popen(cmd,cwd=cwd,env=env,stdout=log,stderr=sp.STDOUT,start_new_session=True,preexec_fn=nd._owned_child(os.getpid()))
        start=time.monotonic()
        try:
            while p.poll() is None:
                if time.monotonic()-start>timeout:raise TimeoutError(name)
                fds=[]
                for f in Path('/proc/%d/fd'%p.pid).glob('*'):
                    try:
                        target=os.readlink(f)
                        if target.startswith('/dev/dri/') or target.startswith('/dev/nvidia'):fds.append(target)
                    except OSError:pass
                watch.append({'time':time.time(),'pid':p.pid,'fds':fds,'nvidia_smi':capture(['nvidia-smi','pmon','-c','1','-s','um'])})
                time.sleep(.2)
        finally:
            if p.poll() is None:nd._stop_group(p)
    save(name+'/run.json',{'command':cmd,'cwd':str(cwd),'exit':p.returncode,'watch':watch})
    return p.returncode

def main():
    assert shutil.disk_usage(Path.home()).free>15_000_000_000
    manifest=json.loads((PKG/'BUILD.json').read_text())
    runtime=PKG/'SpillwayLookC.x86_64';runtime.chmod(0o755)
    pck=PKG/'SpillwayLookC.pck'
    assert nd.digest(runtime)==manifest['runtime_sha256']
    assert nd.digest(pck)==manifest['pack_sha256']
    save('identity.json',{'zip':nd.digest(BASE/'SpillwayLookC-linux-x86_64.zip'),'runtime':nd.digest(runtime),'pck':nd.digest(pck),'editor':nd.digest(EDITOR),'editor_version':capture([str(EDITOR),'--version']),'source_commit':manifest['source_commit']})
    save('hardware-before.json',{k:capture(cmd) for k,cmd in {'nvidia':['nvidia-smi','-q'],'pci':['lspci','-nnk','-s','26:00.0'],'monitors':['xrandr','--current'],'apps':['ps','-eo','pid,comm'],'weston':['weston','--version']}.items()})
    empty=BASE/'empty';empty.mkdir(exist_ok=True)
    for resolution in ('1280x720','2560x1440'):
        width,height=map(int,resolution.split('x'))
        with DesktopDisplay(OUT/('display-'+resolution),width=width,height=height,driver='nvidia',desktop=os.environ.get('DISPLAY',':0'),min_free_gib=15_000_000_000/2**30) as display:
            env=display.child_env(dict(os.environ));env['__GL_SYNC_TO_VBLANK']='0'
            # isolate app state and prevent desktop screensaver inhibition over the session bus.
            env.pop('DBUS_SESSION_BUS_ADDRESS',None)
            for name in ('data','cache','config','state','runtime'):
                path=BASE/('private-'+name);path.mkdir(mode=0o700,exist_ok=True)
                env['XDG_'+name.upper()+('_DIR' if name=='runtime' else '_HOME')]=str(path)
            common=['--display-driver','x11','--rendering-driver','opengl3','--audio-driver','Dummy','--windowed','--position','0,0']
            if resolution=='1280x720':
                assert run([str(runtime),'--verbose',*common,'--resolution',resolution,'--quit-after','180'],env,empty,'release-startup')==0
            fixture=str(OUT/'helpers/desktop-profile.gd')
            name='editor-'+resolution
            cmd=[str(EDITOR),'--main-pack',str(pck),*common,'--resolution',resolution,'--script',fixture,'--','--out='+str(OUT/name)]
            assert run(cmd,env,empty,name)==0,name
            data=json.loads((OUT/name/'performance.json').read_text())
            assert data['window_pixels']=='(%d, %d)'%(width,height)
            assert data['viewport_pixels']=='(%s.0, %s.0)'%(width,height)
    save('hardware-after.json',{'monitors':capture(['xrandr','--current']),'apps':capture(['ps','-eo','pid,comm']),'nvidia':capture(['nvidia-smi']),'free_home_bytes':shutil.disk_usage(Path.home()).free})
if __name__=='__main__':main()
