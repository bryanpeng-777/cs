#!/bin/bash
# sync-video-manifest.sh
# afterFileEdit hook：dart 文件保存后，增量同步 CsVideo configKey 到 video_manifest.json

input=$(cat)

# 提取编辑的文件路径
file_path=$(python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    path = (data.get('path') or
            data.get('tool_input', {}).get('path') or
            data.get('file_path') or '')
    print(path)
except Exception:
    print('')
" <<< "$input" 2>/dev/null)

# 只处理 .dart 文件
if [[ "$file_path" != *.dart ]]; then
    echo '{}'
    exit 0
fi

workspace_root="$(pwd)"
sync_script="$workspace_root/aiworkspace/sync_video_manifest.py"

if [[ ! -f "$sync_script" ]]; then
    echo '{}'
    exit 0
fi

# 后台运行，不阻塞编辑器
python3 "$sync_script" "$file_path" "$workspace_root" &

echo '{}'
exit 0
