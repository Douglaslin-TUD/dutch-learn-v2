# 文件夹重组设计

日期：2026-02-01

## 目标

清晰区分电脑端和手机端代码，使项目结构一目了然。

## 新结构概览

```
/
├── desktop/               ← 🖥️ 电脑端（Web App）
│   ├── app/
│   ├── static/
│   ├── requirements.txt
│   └── run.py
│
├── mobile/                ← 📱 手机端（Flutter App）
│   ├── lib/
│   ├── android/
│   ├── pubspec.yaml
│   └── ...
│
├── docs/                  ← 📚 共享文档
├── scripts/               ← 🔧 工具脚本
├── data/                  ← 💾 运行时数据
│
├── CLAUDE.md
├── README.md
└── .gitignore
```

## 执行步骤

### 任务 1：创建 desktop/ 文件夹并移动文件

```bash
mkdir -p desktop
git mv app/ desktop/app/
git mv static/ desktop/static/
git mv requirements.txt desktop/requirements.txt
git mv run.py desktop/run.py
```

验证：`ls desktop/` 应显示 app/, static/, requirements.txt, run.py

### 任务 2：创建 mobile/ 文件夹并移动 Flutter 文件

```bash
git mv flutter_app/dutch_learn_app/ mobile/
rmdir flutter_app/
```

验证：`ls mobile/` 应显示 lib/, android/, pubspec.yaml 等

### 任务 3：整理 scripts/ 文件夹

```bash
git mv create_project_from_existing.py scripts/
git mv upload_to_drive.py scripts/
```

验证：`ls scripts/` 应显示 3 个脚本文件

### 任务 4：清理重复的文档文件

```bash
git rm docs/architecture.md
git rm docs/requirements.md
```

验证：`ls docs/` 只显示文件夹，没有重复的 .md 文件

### 任务 5：更新 desktop/app/ 中的 import 路径

检查并更新 `desktop/app/main.py` 和其他文件中的导入路径。

由于使用相对导入，可能不需要修改。需要测试验证。

验证：`cd desktop && python -c "from app.main import app; print('OK')"`

### 任务 6：更新 mobile/ 中的配置

更新 `mobile/pubspec.yaml` 中的项目名称（如果需要）。

验证：`cd mobile && flutter pub get`

### 任务 7：更新 CLAUDE.md

更新所有路径引用，反映新的文件夹结构。

### 任务 8：更新 README.md

更新项目说明，反映新的文件夹结构。

### 任务 9：更新 .gitignore

检查并更新路径引用（如 data/, venv/ 等）。

### 任务 10：提交更改

```bash
git add -A
git commit -m "Restructure: separate desktop/ and mobile/ folders"
git push
```

## 风险和注意事项

1. **Python 导入路径**：移动后需要测试 `from app.xxx` 是否仍然有效
2. **Flutter 配置**：移动后需要运行 `flutter pub get` 重新生成依赖
3. **CI/CD**：如果有自动化脚本，需要更新路径
