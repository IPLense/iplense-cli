"""Check display widths, privacy and the bounded report body independently of rendering."""
import json
import re
import unicodedata
from pathlib import Path
VERSION = re.search(r'^VERSION=(\S+)$', open('iplense.sh').read(), re.M).group(1)

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
assert request['schema'] == 'cli-report/2' and request['clientVersion'] == VERSION
assert len(request['local']) == len(request['reportTokens']) == 2
platforms = {'chatgpt', 'claude', 'gemini', 'grok', 'netflix', 'disney', 'prime', 'hbo', 'paramount', 'tiktok', 'reddit'}
mail = {'gmail', 'outlook', 'yahoo', 'apple', 'qq', 'mailru', 'aol', 'gmx', 'mailcom', 'netease', 'sohu', 'sina'}
for local in request['local']:
    assert set(local) == {'family', 'platforms', 'port25', 'mail', 'exitDiffers', 'exitIp'}
    assert set(local['platforms']) == platforms
    for name, check in local['platforms'].items():
        assert set(check) == {'status', 'region'}
        states = {'supported', 'unsupported', 'region', 'failed', 'no_ipv6'} if name in ('chatgpt', 'claude') else {'available', 'unavailable', 'failed', 'no_ipv6'}
        if name == 'netflix':
            states.add('originals_only')
        assert check['status'] in states
        assert re.fullmatch('[A-Z]{2}|', check['region'])
    assert local['port25'] in {'available', 'unavailable', 'failed'}
    # Mail providers only where port 25 is open, all twelve then.
    assert (set(local['mail']) == mail) if local['port25'] == 'available' else local['mail'] == {}
    assert all(state in {'open', 'closed', 'no_ipv6', 'failed'} for state in local['mail'].values())
    assert type(local['exitDiffers']) is bool
    assert '*' in local['exitIp']
