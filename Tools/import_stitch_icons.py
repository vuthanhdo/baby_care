"""Import only Material Symbols used in the checked-in Stitch design exports."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SOURCE = 'https://raw.githubusercontent.com/google/material-design-icons/master/'
icons = set()
for page in (ROOT / 'DesignReference/Stitch/Export').glob('*/code.html'):
    icons.update(s.strip() for s in re.findall(r'<span[^>]*class="[^"]*material-symbols[^"]*"[^>]*>(.*?)</span>', page.read_text(), re.S))
icons = sorted(s for s in icons if re.fullmatch('[a-z0-9_]+', s))

def fetch(symbol):
    existing = ROOT / 'BabyCare/Assets.xcassets' / ('Stitch_' + symbol + '.imageset') / ('Stitch_' + symbol + '.svg')
    if existing.exists():
        return symbol
    canonical = {'add_circle_outline': 'add_circle', 'delete_outline': 'delete', 'warning_amber': 'warning', 'nightlight_round': 'nightlight', 'help_outline': 'help', 'sd_storage': 'sd_card'}.get(symbol, symbol)
    url = SOURCE + f'symbols/web/{canonical}/materialsymbolsoutlined/{canonical}_24px.svg'
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            data = response.read()
    except Exception as error:
        return f'FAILED {symbol}: {error}'
    if b'<svg' not in data or b'<path' not in data:
        raise ValueError(symbol)
    name = 'Stitch_' + symbol
    folder = ROOT / 'BabyCare/Assets.xcassets' / (name + '.imageset')
    folder.mkdir(exist_ok=True)
    (folder / (name + '.svg')).write_bytes(data)
    (folder / 'Contents.json').write_text(json.dumps({
        'images': [{'filename': name + '.svg', 'idiom': 'universal'}],
        'info': {'author': 'xcode', 'version': 1},
        'properties': {'preserves-vector-representation': True, 'template-rendering-intent': 'template'}
    }, indent=2) + '\n')
    return symbol

if __name__ == '__main__':
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(fetch, icons))
        print('Imported:', len([r for r in results if not r.startswith('FAILED')]))
        failures = [r for r in results if r.startswith('FAILED')]
        if failures:
            raise RuntimeError(failures)
    license_path = ROOT / 'BabyCare/Resources/MaterialSymbols-LICENSE.txt'
    with urllib.request.urlopen(SOURCE + 'LICENSE', timeout=30) as response:
        license_path.write_bytes(response.read())
    (ROOT / 'DesignReference/Stitch/material-symbols.json').write_text(json.dumps(icons, indent=2) + '\n')
