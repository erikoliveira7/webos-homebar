"""setup.pid is trusted only for a process running our setup.js, and an update without a
checksum is refused. Real script text, disposable paths (a fake /proc, stub curl and sha256sum)."""
import hashlib, os, re, stat, subprocess, tempfile, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def snippet(path, start, end):
    s = path.read_text(); i = s.index(start); return s[i:s.index(end, i) + len(end)]
def alive(p):
    try: os.kill(p.pid, 0); return p.poll() is None
    except OSError: return False
with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    for name, path, start, end, var in (
        ('apply.sh', ROOT / 'webos4/apply.sh', 'pid=$(cat "$base/setup.pid"', '    esac\n', 'base'),
        ('uninstall.sh', ROOT / 'webos4/uninstall.sh', 'pid=$(cat "$BASE/setup.pid"', 'esac\n', 'BASE')):
        code = snippet(path, start, end).replace('/proc/', '"$PROCDIR"/')
        code = code.replace('"$PROCDIR"/$pid', '"$PROCDIR/$pid"')
        for ours, expect_alive in ((True, False), (False, True)):
            base = tmp / (name + str(ours)); base.mkdir(); procdir = tmp / ('proc' + name + str(ours)); procdir.mkdir()
            victim = subprocess.Popen(['sleep', '30'])
            (procdir / str(victim.pid)).mkdir()
            (procdir / str(victim.pid) / 'cmdline').write_bytes(b'node\0/var/lib/webosbrew/rawin-launcher/setup/setup.js\0' if ours else b'/usr/bin/some-other-daemon\0')
            (base / 'setup.pid').write_text(str(victim.pid))
            subprocess.run(['sh', '-c', code], env=dict(os.environ, base=str(base), BASE=str(base), PROCDIR=str(procdir)), check=True)
            time.sleep(0.3)
            assert alive(victim) == expect_alive, (name, 'ours' if ours else 'a stranger', alive(victim))
            victim.kill(); victim.wait()
        # garbage and a missing file never break the script
        base = tmp / (name + 'junk'); base.mkdir(); (base / 'setup.pid').write_text('12; rm -rf x')
        subprocess.run(['sh', '-c', code], env=dict(os.environ, base=str(base), BASE=str(base), PROCDIR=str(tmp)), check=True)
        base = tmp / (name + 'none'); base.mkdir()
        subprocess.run(['sh', '-c', code], env=dict(os.environ, base=str(base), BASE=str(base), PROCDIR=str(tmp)), check=True)

    # update.sh download
    bin_ = tmp / 'bin'; bin_.mkdir()
    pkg = tmp / 'pkg'; (pkg / 'rawin-launcher').mkdir(parents=True); (pkg / 'rawin-launcher/VERSION').write_text('9.9.9\n')
    tgz = tmp / 'asset.tar.gz'; subprocess.run(['tar', 'czf', str(tgz), '-C', str(pkg), 'rawin-launcher'], check=True)
    good = hashlib.sha256(tgz.read_bytes()).hexdigest()
    (bin_ / 'curl').write_text('#!/bin/sh\ncat "%s"\n' % tgz); (bin_ / 'sha256sum').write_text('#!/bin/sh\nshasum -a 256 "$@"\n')
    for f in bin_.iterdir(): f.chmod(f.stat().st_mode | stat.S_IEXEC)
    script = (ROOT / 'update.sh').read_text()
    def run(sum_):
        work = tmp / ('work' + (sum_ or 'none')[:6]); work.mkdir()
        (work / 'url').write_text('https://example.invalid/asset'); (work / 'version').write_text('9.9.9'); (work / 'sha256').write_text(sum_)
        (tmp / 'update.sh').write_text(re.sub(r'^WORK=.*$', 'WORK=' + str(work), script, flags=re.M))
        r = subprocess.run(['sh', str(tmp / 'update.sh'), 'download'], env=dict(os.environ, PATH=str(bin_) + ':' + os.environ['PATH']), text=True, capture_output=True)
        return r.stdout
    assert 'no checksum' in run(''), run('')
    assert 'checksum mismatch' in run('0' * 64)
    assert '"ok":true' in run(good), run(good)
print('PASS setup.pid kills only our setup.js (apply, uninstall; junk and missing file are fine); update refuses a missing or wrong checksum')
