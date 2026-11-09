"""Maintain aliases for legacy display encodings and mark translated format strings.

Never changes game IDs, balance values or save data. Run after adding catalog entries.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'data/localization/en.json'
TOKEN = re.compile(r'"(?:\\.|[^"\\])*"')
FORMATTED = re.compile(r'Localization\.text\(("(?:\\.|[^"\\])*")\)\s*%\s*\[')


def translate_arguments(line):
    # Only the explicit array form is rewritten. Preserve surrounding GDScript.
    while match := FORMATTED.search(line):
        position = match.end()
        depth = 1
        while position < len(line) and depth:
            if line[position] == '"':
                token = TOKEN.match(line, position)
                if token:
                    position = token.end()
                    continue
            if line[position] == '[':
                depth += 1
            elif line[position] == ']':
                depth -= 1
            position += 1
        if depth:
            break
        arguments = line[match.end()-1:position]
        line = line[:match.start()] + 'Localization.format_text(' + match[1] + ', ' + arguments + ')' + line[position:]
    return line


def clean(value):
    for _ in range(5):
        try:
            repaired = value.encode('cp1252').decode('utf-8')
        except (UnicodeError, LookupError):
            break
        if repaired == value:
            break
        value = repaired
    return value


def main():
    catalog = json.loads(CATALOG.read_text(encoding='utf-8'))
    italian = {}
    aliases = 0
    sources = list((ROOT / 'scripts').rglob('*.gd')) + list((ROOT / 'scenes').rglob('*.tscn'))
    for path in sources + [ROOT / 'data/balance.json']:
        for token in TOKEN.findall(path.read_text(encoding='utf-8-sig')):
            try:
                original = json.loads(token)
            except ValueError:
                continue
            normalized = clean(original)
            if normalized != original:
                italian[original] = normalized
            if original not in catalog and normalized in catalog:
                catalog[original] = catalog[normalized]
                aliases += 1
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (ROOT / 'data/localization/it.json').write_text(json.dumps(italian, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    changes = []
    for path in (ROOT / 'scripts').rglob('*.gd'):
        if path.parts[-2] not in ['ui', 'gameplay', 'economy', 'core'] or path.name == 'localization.gd':
            continue
        lines = []
        count = 0
        for line in path.read_text(encoding='utf-8-sig').splitlines(keepends=True):
            def replace(match):
                nonlocal count
                try:
                    source = json.loads(match.group())
                except ValueError:
                    return match.group()
                presentation = any(marker in line for marker in ['_notify(', 'machine_message.emit(', 'prompt', 'return _step(', 'return _collect_step('])
                if source not in catalog and source not in italian:
                    return match.group()
                if ('%' not in source and not presentation) or line.lstrip().startswith(('#', 'const ')):
                    return match.group()
                if line[:match.start()].endswith(('Localization.text(', 'Localization.format_text(', 'TranslationServer.translate(')):
                    return match.group()
                count += 1
                return 'Localization.text(' + match.group() + ')'
            translated = translate_arguments(TOKEN.sub(replace, line))
            translated = re.sub(r'Localization\.format_text\(Localization\.text\(("(?:\\.|[^"\\])*")\),', r'Localization.format_text(\1,', translated)
            if translated != line and count == 0:
                count = 1
            lines.append(translated)
        if count:
            path.write_text(''.join(lines), encoding='utf-8')
            changes.append((path.name, count))
    print('Legacy aliases:', aliases, 'Translated format expressions:', changes)


if __name__ == '__main__':
    main()
