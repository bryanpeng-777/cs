# cs_ui 视觉主题库

cs_framework 配套的 Flutter 视觉主题系统，基于 `shadcn_ui` 封装，提供 4 套开箱即用的配色方案。

- **GitHub**: https://github.com/bryanpeng-777/cs_ui（待创建）
- **本地路径**: `/Users/pengchao/cursorBiz/cs_ui`
- **依赖**: `shadcn_ui: '>=0.21.0 <0.22.0'`（注意版本约束，见踩坑）

---

## 主题体系

### 4 套主题

| 文件 | 主题名 | 风格 |
|------|--------|------|
| `cartoon_theme.dart` | Cartoon | 卡通活泼，高饱和配色，适合儿童/游戏类 App |
| `fresh_minimal_theme.dart` | Fresh Minimal | 清新简约，低饱和，适合工具/效率类 App |
| `nature_theme.dart` | Nature | 自然绿系，适合健康/户外类 App |
| `cs_app_theme.dart` | CsApp | 通用默认主题，适合大多数场景 |

### 目录结构

```
cs_ui/
├── lib/
│   ├── cs_ui.dart              ← 包入口（统一导出）
│   └── src/
│       ├── theme/
│       │   ├── cartoon_theme.dart
│       │   ├── fresh_minimal_theme.dart
│       │   ├── nature_theme.dart
│       │   └── cs_app_theme.dart
│       └── widgets/
│           └── cs_app.dart     ← CsApp 入口组件
└── pubspec.yaml
```

---

## 使用方式

### 接入到 App

```yaml
# pubspec.yaml（发布引用）
cs_ui:
  git:
    url: https://github.com/bryanpeng-777/cs_ui.git
    ref: main

# pubspec_overrides.yaml（本地开发，不提交）
dependency_overrides:
  cs_ui:
    path: ../cs_ui
```

### 使用 CsApp 入口组件

```dart
import 'package:cs_ui/cs_ui.dart';

void main() {
  runApp(
    CsApp(
      theme: CartoonTheme(),   // 选择主题
      home: MyHomePage(),
    ),
  );
}
```

### 切换主题

```dart
// 可选主题：CartoonTheme / FreshMinimalTheme / NatureTheme / CsAppTheme
CsApp(theme: FreshMinimalTheme(), ...)
```

---

## 新增主题

1. 在 `lib/src/theme/` 下新建 `my_theme.dart`
2. 实现 `ShadColorScheme`（参考 `cartoon_theme.dart`）
3. 在 `lib/cs_ui.dart` 中 export 新文件

---

## 踩坑

- **shadcn_ui 版本约束**：当前锁定 `>=0.21.0 <0.22.0`，0.22.x 引入了 Flutter 3.27.4 不存在的 `TapRegionUpCallback`，会导致 Xcode 编译失败（dart analyze 可通过但 build 不过）。升级前需验证 Flutter SDK 版本兼容性。
