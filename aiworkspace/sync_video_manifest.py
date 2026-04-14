#!/usr/bin/env python3
"""
sync_video_manifest.py

增量扫描单个 .dart 文件中的 CsVideo(configKey: '...') 用法，
将新发现的 configKey 追加到 video_manifest.json。

用法：
    python3 sync_video_manifest.py <dart_file_path> <workspace_root>
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

    # 从 key 前缀推断：home_intro_video → home
    parts = config_key.split('_')
    if len(parts) >= 2:
        return parts[0]

    return 'uncategorized'


def extract_cs_videos(dart_content: str) -> list[dict]:
    """
    从 dart 文件内容中提取所有 CsVideo 的 configKey 和 description。
    支持参数跨行的写法。
    """
    results = []

    for match in re.finditer(r'\bCsVideo\s*\(', dart_content):
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


def all_existing_keys(manifest: dict) -> set[str]:
    """收集 manifest 中所有已有的 configKey。"""
    keys = set()
    for page_data in manifest.get('pages', {}).values():
        keys.update(page_data.get('videos', {}).keys())
    return keys


def sync(dart_file_path: str, workspace_root: str) -> None:
    manifest_path = os.path.join(workspace_root, 'aiworkspace', 'video_manifest.json')

    if not os.path.exists(manifest_path):
        print(f'[sync_video] manifest not found: {manifest_path}', file=sys.stderr)
        return

    try:
        with open(dart_file_path, 'r', encoding='utf-8') as f:
            dart_content = f.read()
    except FileNotFoundError:
        return

    found = extract_cs_videos(dart_content)
    if not found:
        return

    manifest = load_manifest(manifest_path)
    existing_keys = all_existing_keys(manifest)

    new_entries = [v for v in found if v['config_key'] not in existing_keys]
    if not new_entries:
        return

    today = date.today().isoformat()
    manifest['_last_updated'] = today

    pages = manifest.setdefault('pages', {})

    for entry in new_entries:
        config_key = entry['config_key']
        description = entry['description']
        page_name = infer_page(dart_file_path, config_key)

        page = pages.setdefault(page_name, {'title': page_name, 'videos': {}})
        page['videos'][config_key] = {
            'description': description,
            'aspect_ratio': '16:9',
            'format': 'mp4/mov/m3u8',
            'asset_path': None,
            'video_url': None,
            'status': 'placeholder',
            'last_updated': None,
        }
        print(f'[sync_video] +{config_key} → {page_name}')

    # 更新 summary
    all_videos = [
        v
        for page_data in pages.values()
        for v in page_data.get('videos', {}).values()
    ]
    manifest['summary'] = {
        'total': len(all_videos),
        'placeholder': sum(1 for v in all_videos if v.get('status') == 'placeholder'),
        'local': sum(1 for v in all_videos if v.get('status') == 'local'),
        'remote': sum(1 for v in all_videos if v.get('status') == 'remote'),
    }

    save_manifest(manifest_path, manifest)


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Usage: sync_video_manifest.py <dart_file> <workspace_root>')
        sys.exit(1)

    sync(sys.argv[1], sys.argv[2])
