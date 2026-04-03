import json
import urllib.request
import urllib.error
from pathlib import Path

p = Path('/root/.litellm_env')
if not p.exists():
    print('ERR: /root/.litellm_env not found')
    raise SystemExit(1)
line = p.read_text(errors='ignore').strip()
key = line.split('=', 1)[1] if '=' in line else ''
if not key:
    print('ERR: key empty')
    raise SystemExit(1)

base = 'https://generativelanguage.googleapis.com/v1beta'
models_url = f'{base}/models?key={key}'

try:
    with urllib.request.urlopen(models_url, timeout=30) as r:
        models_data = json.loads(r.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    body = e.read().decode('utf-8', errors='ignore')
    print('ERR_LIST_MODELS_HTTP', e.code)
    print(body)
    raise SystemExit(1)

models = models_data.get('models', [])
cands = []
for m in models:
    name = m.get('name', '')
    methods = m.get('supportedGenerationMethods') or []
    if 'generateContent' not in methods:
        continue
    if not (name.startswith('models/gemini') or name.startswith('models/gemma')):
        continue
    cands.append(name)

priority = [
    'models/gemini-2.5-flash',
    'models/gemini-2.5-pro',
    'models/gemini-2.0-flash',
    'models/gemini-flash-latest',
    'models/gemini-pro-latest',
    'models/gemini-2.5-flash-lite',
    'models/gemini-3-flash-preview',
    'models/gemini-3-pro-preview',
    'models/gemini-3.1-flash-lite-preview',
    'models/gemini-3.1-pro-preview',
    'models/gemma-3-4b-it',
    'models/gemma-3-12b-it',
]
ordered = []
seen = set()
for n in priority:
    if n in cands and n not in seen:
        ordered.append(n)
        seen.add(n)
for n in cands:
    if n not in seen:
        ordered.append(n)
        seen.add(n)
ordered = ordered[:20]

payload = json.dumps({
    'contents': [{'parts': [{'text': 'reply exactly: OK'}]}]
}).encode('utf-8')

results = []
for name in ordered:
    url = f"{base}/{name}:generateContent?key={key}"
    req = urllib.request.Request(url, data=payload, headers={'Content-Type': 'application/json'}, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            body = json.loads(r.read().decode('utf-8'))
            text = ''
            try:
                text = body['candidates'][0]['content']['parts'][0].get('text', '')
            except Exception:
                pass
            results.append({'model': name, 'status': 'PASS', 'detail': text[:80]})
    except urllib.error.HTTPError as e:
        raw = e.read().decode('utf-8', errors='ignore')
        code = e.code
        detail = raw[:180]
        try:
            obj = json.loads(raw)
            err = obj.get('error', {})
            reason = err.get('status') or ''
            msg = err.get('message', '')
            detail = (reason + ' | ' + msg)[:220]
        except Exception:
            pass
        tag = 'HTTP_' + str(code)
        if code == 429:
            tag = 'QUOTA_429'
        elif code == 404:
            tag = 'NOT_FOUND_404'
        elif code == 403:
            tag = 'FORBIDDEN_403'
        elif code == 400:
            tag = 'BADREQ_400'
        results.append({'model': name, 'status': tag, 'detail': detail})
    except Exception as e:
        results.append({'model': name, 'status': 'ERROR', 'detail': str(e)[:180]})

print('=== MODEL TEST RESULTS ===')
for x in results:
    print(x['model'] + '\t' + x['status'] + '\t' + x['detail'])
