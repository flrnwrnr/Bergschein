"""Run with python3 output/backend-season/test_seasons.py (requires PHP)."""
import json
import subprocess
from pathlib import Path

root = Path(__file__).parent
for filename, variable, end in [
    ('track.php', '$data', '$installId ='),
    ('community.php', '$_GET', '$maxCheckins ='),
]:
    source = (root / filename).read_text()
    validation = source[source.index('// Missing season IDs'):source.index(end)]
    for payload, expected in [
        ({}, 'bergschein-2026'),
        ({'season_id': 'bergschein-2026'}, 'bergschein-2026'),
        ({'season_id': 'bergschein-2027'}, 'bergschein-2027'),
        ({'season_id': 'test-bergschein-2026'}, 'test-bergschein-2026'),
        ({'season_id': 'test-bergschein-2027'}, 'test-bergschein-2027'),
        ({'season_id': ''}, '422'),
        ({'season_id': []}, '422'),
        ({'season_id': 'bergschein-2028'}, '422'),
    ]:
        encoded = json.dumps(payload)
        code = "<?php\nfunction jsonResponse($status, $body) { echo $status; exit; }\n"
        code += variable + " = json_decode('" + encoded + "', true);\n"
        code += validation + 'echo $seasonId;'
        result = subprocess.run(['php'], input=code, text=True, capture_output=True, check=True)
        assert result.stdout == expected, (filename, payload, result.stdout)
print('16 season validation checks passed')
