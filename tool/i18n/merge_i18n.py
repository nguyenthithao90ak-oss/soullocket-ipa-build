#!/usr/bin/env python3
"""Gộp khóa dịch mới vào assets/i18n/*.json.

- multi/*.json : {key: {lang: text}}  (đủ hoặc một phần ngôn ngữ, ghi đè)
- src/*.json   : {key: {"vi": ..., "en": ...}} (nguồn)
- tr/<lang>__*.json : {key: text} (bản dịch theo ngôn ngữ)
"""
import glob, json, os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'i18n')
HERE = os.path.dirname(os.path.abspath(__file__))
LANGS = [os.path.basename(p)[:-5] for p in glob.glob(f'{ROOT}/*.json')]

updates = {lang: {} for lang in LANGS}
for path in sorted(glob.glob(f'{HERE}/multi/*.json')) + sorted(glob.glob(f'{HERE}/src/*.json')):
    for key, per_lang in json.load(open(path, encoding='utf-8')).items():
        for lang, text in per_lang.items():
            assert lang in updates, (path, lang)
            updates[lang][key] = text
for path in sorted(glob.glob(f'{HERE}/tr/*.json')):
    lang = os.path.basename(path).split('__')[0]
    assert lang in updates, path
    for key, text in json.load(open(path, encoding='utf-8')).items():
        updates[lang][key] = text

placeholder = re.compile(r'\{\w+\}')
en_ref = dict(json.load(open(f'{ROOT}/en.json', encoding='utf-8')))
en_ref.update(updates['en'])
errors = []
for lang, items in updates.items():
    for key, text in items.items():
        if key in en_ref and set(placeholder.findall(text)) != set(placeholder.findall(en_ref[key])):
            errors.append(f'{lang}:{key}: {text!r} vs en {en_ref[key]!r}')
        if not text.strip():
            errors.append(f'{lang}:{key}: empty')
if errors:
    print('\n'.join(errors)); sys.exit(1)

check_only = '--check' in sys.argv
for lang in LANGS:
    path = f'{ROOT}/{lang}.json'
    data = json.load(open(path, encoding='utf-8'))
    data.update(updates[lang])
    if not check_only:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

# Báo cáo khóa mới còn thiếu bản dịch.
new_keys = set()
for path in glob.glob(f'{HERE}/src/*.json') + glob.glob(f'{HERE}/multi/*.json'):
    new_keys |= set(json.load(open(path, encoding='utf-8')))
missing = {lang: sorted(k for k in new_keys if k not in updates[lang]) for lang in LANGS}
for lang in sorted(LANGS):
    if missing[lang]:
        print(f'{lang}: thiếu {len(missing[lang])} khóa')
print('ok' + (' (check only)' if check_only else ''))
