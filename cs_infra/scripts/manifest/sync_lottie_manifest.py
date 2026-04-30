#!/usr/bin/env python3
"""
sync_lottie_manifest.py

增量扫描单个 .dart 文件中的 CsLottie(configKey: '...') 用法，
将新发现的 configKey 追加到 lottie_manifest.json。

用法：
    python3 sync_lottie_manifest.py <dart_file_path> <workspace_root>
"""

import sys
import re
import json
import os
from datetime import date


def infer_page(dart_file_path: str, config_key: str) -> str:
    """从文件名或 key 前缀推断所属页面。"""
    filename = os.path.basename(dart_file_path)

    # 从文件名推断：home_screen.dart → home
    m = re.match(r'^([a-z][a-z0-9_]+?)(?:_screen|_page|_view)?\.dart$', filename)
    if m:
        candidate = m.group(1)
        if candidate not in ('main', 'app', 'widget', 'common', 'base', 'shared'):
            return candidate

    # 从 key 前缀推断：home_loading_animation → home
    parts = config_key.split('_')
    if len(parts) >= 2:
        return parts[0]

    return 'uncategorized'


def extract_cs_lotties(dart_content: str) -> list[dict]:
    """
    从 dart 文件内容中提取所有 CsLottie 的 configKey 和 description。
    支持参数跨行的写法。
    """
    results = []

    for match in re.finditer(r'\bCsLottie\s*\(', dart_content):
        start = match.end()
        depth = 1
        pos = start
        while pos < len(dart_content) and depth > 0:
            if dart_content[pos] == '(':
                depth += 1
            elif dart_content[pos] == ')':
                depth -= 1
            pos += 1
        widget_body = dart_content[start:pos - 1]

        key_match = re.search(r"configKey\s*:\s*['\"]([^'\"]+)['\"]", widget_body)
        if not key_match:
            continue
        config_key = key_match.group(1)

        desc_match = re.search(r"description\s*:\s*['\"]([^'\"]+)['\"]", widget_body)
        description = desc_match.group(1) if desc_match else config_key

        results.append({'config_key': config_key, 'description': description})

    return results


def load_manifest(manifest_path: str) -> dict:
    with open(manifest_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def save_manifest(manifest_path: str, manifest: dict) -> None:
    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write('\n')


def get_all_existing_keys(manifest: dict) -> set:
    keys = set()
    for page_data in manifest.get('pages', {}).values():
        keys.update(page_data.get('animations', {}).keys())
    return keys


def update_summary(manifest: dict) -> None:
    total = placeholder = local = remote = 0
    for page_data in manifest.get('pages', {}).values():
        for anim in page_data.get('animations', {}).values():
            total += 1
            status = anim.get('status', 'placeholder')
            if status == 'placeholder':
                placeholder += 1
            elif status == 'local':
                local += 1
            elif status == 'remote':
                remote += 1
    manifest['summary'] = {
        'total': total,
        'placeholder': placeholder,
        'local': local,
        'remote': remote,
    }


def main():
    if len(sys.argv) < 3:
        print("Usage: sync_lottie_manifest.py <dart_file> <workspace_root>", file=sys.stderr)
        sys.exit(1)

    dart_file = sys.argv[1]
    workspace_root = sys.argv[2]
    manifest_path = os.path.join(workspace_root, 'aiworkspace', 'lottie_manifest.json')

    if not os.path.exists(dart_file):
        sys.exit(0)
    if not os.path.exists(manifest_path):
        sys.exit(0)

    try:
        with open(dart_file, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception:
        sys.exit(0)

    usages = extract_cs_lotties(content)
    if not usages:
        sys.exit(0)

    try:
        manifest = load_manifest(manifest_path)
    except Exception:
        sys.exit(0)

    existing_keys = get_all_existing_keys(manifest)
    new_entries = [u for u in usages if u['config_key'] not in existing_keys]

    if not new_entries:
        sys.exit(0)

    today = date.today().isoformat()
    pages = manifest.setdefault('pages', {})
    added = []

    for entry in new_entries:
        config_key = entry['config_key']
        description = entry['description']
        page_key = infer_page(dart_file, config_key)

        if page_key not in pages:
            filename = os.path.basename(dart_file).replace('.dart', '').replace('_', ' ').title()
            pages[page_key] = {
                'title': filename,
                'animations': {},
            }

        pages[page_key]['animations'][config_key] = {
            'description': description,
            'asset_path': None,
            'animation_url': None,
            'status': 'placeholder',
            'last_updated': today,
        }
        added.append(f'{page_key}.{config_key}')

    manifest['_last_updated'] = today
    update_summary(manifest)
    save_manifest(manifest_path, manifest)

    print(f'[cs-lottie-manager] 新增 {len(added)} 个动画插槽: {", ".join(added)}')


if __name__ == '__main__':
    main()
