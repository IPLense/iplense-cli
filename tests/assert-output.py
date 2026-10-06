"""Check display widths, privacy and the bounded report body independently of rendering."""
import json
import re
import unicodedata
from pathlib import Path

root = Path(__file__).resolve().parent
ansi = re.compile(r'\x1b\[[0-9;]*m')

def width(text):
    return sum(0 if unicodedata.combining(c) else 2 if unicodedata.east_asian_width(c) in 'WF' else 1 for c in text)

for path in (root / 'snapshots').glob('*.txt'):
    text = ansi.sub('', path.read_text())
    if path.stem.startswith(('json', 'help', 'version')) or '-json-' in path.stem:
        continue
    columns = 120 if '-120-' in path.stem else 80
    for line in text.splitlines():
        assert width(line) <= columns, (path.name, width(line), line)
    if 'full' not in path.stem and path.stem != 'report-contract':
        assert '203.0.113.45' not in text, path.name
        assert '2001:db8:4860:1234' not in text, path.name
    assert 'Full result' not in text and '完整结果' not in text, path.name
    assert '\r' not in text and '\x1b[K' not in text, path.name

for path in (root / 'snapshots').glob('*json*.txt'):
    data = json.loads(path.read_text().split('\n\n[exit')[0])
    if 'full' not in path.stem and path.stem != 'report-contract':
        assert '203.0.113.45' not in json.dumps(data), path.name
        assert '2001:db8:4860:1234' not in json.dumps(data), path.name

request = json.loads((root / '.work/report.json').read_text())
assert set(request) == {'schema', 'clientVersion', 'locale', 'reportTokens', 'local'}
assert request['schema'] == 'cli-report/1' and request['clientVersion'] == '1.2.0'
assert len(request['local']) == len(request['reportTokens']) == 2
platforms = {'chatgpt', 'claude', 'gemini', 'netflix', 'disney', 'youtube', 'tiktok', 'prime', 'reddit'}
for local in request['local']:
    assert set(local) == {'family', 'platforms', 'port25', 'exitDiffers', 'exitIp'}
    assert set(local['platforms']) == platforms
    for name, check in local['platforms'].items():
        assert set(check) == {'status', 'region'}
        states = {'supported', 'unsupported', 'region', 'failed'} if name in ('chatgpt', 'claude') else {'available', 'unavailable', 'failed'}
        if name == 'netflix':
            states.add('originals_only')
        assert check['status'] in states
        assert re.fullmatch('[A-Z]{2}|', check['region'])
    assert local['port25'] in {'available', 'unavailable', 'failed'}
    assert type(local['exitDiffers']) is bool
    assert '*' in local['exitIp']
