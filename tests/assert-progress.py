"""Exercise progress through a real PTY and ordinary pipes, without network access."""
import errno
import os
import pty
import select
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
env = dict(os.environ, PATH=f'{root}/tests/stub:{os.environ["PATH"]}', LANG='zh_CN.UTF-8', TERM='xterm', COLUMNS='80', STUB_V4='full-v4.kv:200', STUB_LOCAL='available', STUB_REPORT='success')
for name in ('NO_COLOR', 'LC_ALL', 'LC_CTYPE', 'STUB_V6'):
    env.pop(name, None)
code = r'''eval "$(sed '\$d' "$0")"
smtp_address() { printf 192.0.2.25; }
smtp_greeting() { printf '220 mx.example.test'; }
main "$@"'''.replace(r"'\$d'", "'$d'")

def run(args, terminal):
    cmd = ['/bin/bash', '-c', code, str(root / 'iplense.sh'), *args]
    if not terminal:
        result = subprocess.run(cmd, env=env, capture_output=True, timeout=30, check=True)
        return result.stdout + result.stderr
    master, slave = pty.openpty()
    proc = subprocess.Popen(cmd, env=env, stdin=subprocess.DEVNULL, stdout=slave, stderr=slave)
    os.close(slave)
    data = bytearray()
    try:
        while select.select([master], [], [], 30)[0]:
            try:
                chunk = os.read(master, 65536)
            except OSError as error:
                if error.errno == errno.EIO:
                    break
                raise
            if not chunk:
                break
            data.extend(chunk)
        assert proc.wait(timeout=5) == 0
    finally:
        os.close(master)
    return bytes(data)

text = run(['-4'], True).decode()
assert '正在查询本机 IPv4 结果…' in text
for name, i in [('ChatGPT', 1), ('Claude', 2), ('Gemini', 3), ('Netflix', 4), ('Disney+', 5), ('YouTube Premium', 6), ('TikTok', 7), ('Prime Video', 8), ('Reddit', 9), ('出站 25 端口', 10)]:
    assert f'正在检测 {name}（{i}/10）…' in text
assert '\r\x1b[K\x1b[1;94m┌' in text
for args, terminal in [(['-4'], False), (['-4', '-j'], True), (['-4', '-o', str(root / 'tests/.work/tty-saved.txt')], True)]:
    output = run(args, terminal).decode()
    assert '正在' not in output and '\x1b[K' not in output
print('PTY progress, non-TTY, -j and -o: passed')
