#!/usr/bin/env python3
"""Dependency-light validation for the complete GiveChain Flutter source."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
FAILURES: list[str] = []


def run(command: list[str], *, required: bool = True) -> bool:
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if result.returncode != 0:
        if required:
            FAILURES.append(
                f"Command failed: {' '.join(command)}\n{result.stdout}{result.stderr}".strip()
            )
        return False
    return True


dart_files = sorted((ROOT / 'lib').rglob('*.dart')) + sorted((ROOT / 'test').rglob('*.dart'))
if shutil.which('dart'):
    run(['dart', 'format', '--output=none', '--set-exit-if-changed', 'lib', 'test'])
else:
    try:
        from tree_sitter import Language, Parser
        import tree_sitter_dart
        parser = Parser(Language(tree_sitter_dart.language()))
        for path in dart_files:
            tree = parser.parse(path.read_bytes())
            stack = [tree.root_node]
            while stack:
                node = stack.pop()
                if node.type == 'ERROR' or node.is_missing:
                    FAILURES.append(
                        f'{path.relative_to(ROOT)}: Dart syntax {node.type} at {node.start_point}'
                    )
                stack.extend(node.children)
    except ImportError:
        FAILURES.append('Neither Dart nor tree-sitter-dart is available for syntax validation.')

# Resolve every local import/export/part.
for path in dart_files:
    text = path.read_text(encoding='utf-8')
    for imported in re.findall(r"(?:import|export|part)\s+'([^']+)'", text):
        if imported.startswith('package:give_chain_app/'):
            target = ROOT / 'lib' / imported.split('package:give_chain_app/', 1)[1]
        elif imported.startswith('.'):
            target = (path.parent / imported).resolve()
        else:
            continue
        if not target.exists():
            FAILURES.append(f'{path.relative_to(ROOT)}: missing import {imported}')

# Project completeness checks.
required_files = [
    'pubspec.yaml', 'analysis_options.yaml', '.metadata',
    'lib/main.dart', 'lib/give-chain-app.dart',
    'lib/features/login/ui/login_screen.dart',
    'android/settings.gradle.kts', 'android/app/build.gradle.kts',
    'android/app/src/main/AndroidManifest.xml',
    'web/index.html', 'web/manifest.json',
    'ios/Runner/Info.plist',
    'assets/config/givechain_api_contract.json',
    'docs/GiveChain_Mobile_Guide.md',
]
for relative in required_files:
    if not (ROOT / relative).exists():
        FAILURES.append(f'Missing complete-project file: {relative}')

pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
required_dependencies = {
    'dio', 'go_router', 'flutter_bloc', 'shared_preferences',
    'flutter_secure_storage', 'image_picker', 'file_picker',
    'url_launcher', 'intl', 'cached_network_image', 'equatable',
    'flutter_screenutil',
}
for dependency in required_dependencies:
    if not re.search(rf'^\s{{2}}{re.escape(dependency)}:', pubspec, re.MULTILINE):
        FAILURES.append(f'pubspec.yaml missing dependency: {dependency}')
for asset in ('assets/images/', 'assets/config/'):
    if asset not in pubspec:
        FAILURES.append(f'pubspec.yaml does not bundle {asset}')

# Official backend contract count and key routes.
try:
    contract = json.loads(
        (ROOT / 'assets/config/givechain_api_contract.json').read_text(encoding='utf-8')
    )
    operations = contract.get('confirmedOperations', {})
    if len(operations) != 49:
        FAILURES.append(f'Bundled API contract has {len(operations)} operations; expected 49.')
    expected = {
        'login': ('POST', '/api/mobile/auth/login'),
        'register': ('POST', '/api/mobile/auth/register'),
        'campaignDonate': ('POST', '/api/mobile/campaigns/{id}/donate'),
        'caseDonate': ('POST', '/api/mobile/cases/{id}/donate'),
        'donationsCreate': ('POST', '/api/mobile/donations'),
        'profileUpdate': ('PUT', '/api/mobile/profile'),
        'profilePassword': ('PUT', '/api/mobile/profile/password'),
        'mediaUpload': ('POST', '/api/media'),
        'charityLookupBySubdomain': ('GET', '/api/charities/lookup'),
        'version': ('GET', '/api/version'),
    }
    for name, (method, path) in expected.items():
        operation = operations.get(name, {})
        if operation.get('method') != method or operation.get('path') != path:
            FAILURES.append(f'Contract mismatch {name}: {operation}')
except Exception as error:
    FAILURES.append(f'Invalid API contract asset: {error}')

# No user-supplied secrets may be embedded.
secret_pattern = re.compile(r'eyJ[A-Za-z0-9_-]{20,}|abduljawadrabie|12345678', re.I)
for path in ROOT.rglob('*'):
    if not path.is_file() or '.git' in path.parts or '__pycache__' in path.parts:
        continue
    if path.name == 'verify_source.py':
        continue
    try:
        text = path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        continue
    if secret_pattern.search(text):
        FAILURES.append(f'{path.relative_to(ROOT)}: possible embedded test credential')

# Platform-specific configuration required by the implemented UI.
manifest = (ROOT / 'android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8')
for needle in (
    'android.permission.INTERNET',
    'android.permission.READ_MEDIA_IMAGES',
    'android:scheme="givechain"',
    'android:host="app"',
):
    if needle not in manifest:
        FAILURES.append(f'AndroidManifest missing: {needle}')
info_plist = (ROOT / 'ios/Runner/Info.plist').read_text(encoding='utf-8')
for needle in ('NSPhotoLibraryUsageDescription', '<string>givechain</string>'):
    if needle not in info_plist:
        FAILURES.append(f'iOS Info.plist missing: {needle}')

run([sys.executable, 'tools/api_ui_coverage.py'])
run([sys.executable, 'tools/ui_route_audit.py'])
run([sys.executable, '-m', 'py_compile',
     'tools/api_readonly_smoke.py',
     'tools/api_ui_coverage.py',
     'tools/ui_route_audit.py'])
run(['bash', '-n', 'tools/prepare_flutter_platforms.sh'])

if FAILURES:
    print('VALIDATION FAILED')
    for failure in FAILURES:
        print('-', failure)
    sys.exit(1)

print(f'PASS: {len(dart_files)} Dart files passed syntax parsing.')
print('PASS: all local imports resolve.')
print('PASS: full Android, iOS bootstrap, and web source layout exists.')
print('PASS: all 49 official APIs have data and UI bindings.')
print('PASS: route and critical journey audit passed.')
print('PASS: no supplied credentials are embedded.')
