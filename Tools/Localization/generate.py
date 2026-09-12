"""Generate standard iOS string resources from the reviewed translation table."""
import json
from pathlib import Path
source = Path(__file__).with_name('translations.json')
root = source.parents[2] / 'BabyCare' / 'Localization'
translations = json.loads(source.read_text())
for language in ('en', 'vi'):
    target = root / f'{language}.lproj' / 'Localizable.strings'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text('// UI strings. {0}, {1}, … are interpolation arguments.\n' + '\n'.join(
        f'{json.dumps(key, ensure_ascii=False)} = {json.dumps(value if language == "en" else key, ensure_ascii=False)};'
        for key, value in sorted(translations.items())
    ) + '\n')
