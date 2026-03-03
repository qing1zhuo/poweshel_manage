# 🛠️ PowerShell 脚本管理工具 (v2.0)

这是一个专为 Windows 用户设计的本地脚本管理系统。它能帮助你轻松管理日常使用的 PowerShell 脚本，支持脚本的**增删改查、版本回滚、功能描述以及一键运行**。

---

## 📂 项目结构

- `ScriptManager.py`: **新版管理工具入口 (Python + CustomTkinter)**。提供现代化的图形化界面与集成控制台。
- `Scripts/`: 脚本存放目录。所有的 `.ps1` 脚本都存放在这里。
- `VersionBackup/`: 版本备份目录。当你在 GUI 内编辑脚本时，旧版本会自动备份到这里，可通过管理器点击“🔄 回滚”恢复。
- `ScriptMetaData.json`: 元数据文件。记录脚本的描述、版本号和创建时间。
- `CONTRIBUTING.md`: **开发与操作规范**。所有开发者修改本项目前必须阅读。

---

## 🚀 快速开始

1. **安装依赖**（仅首次）：
   ```bash
   pip install customtkinter pillow
   ```

2. **运行管理工具**：
   在终端执行：
   ```bash
   python ScriptManager.py
   ```

3. **操作说明**：
   - **刷新列表**：点击侧边栏的“刷新列表”同步本地脚本。
   - **运行脚本**：在脚本卡片中点击“运行”，输出将实时显示在下方控制台，支持 Read-Host 交互。
   - **修改脚本**：点击“修改”将调用记事本打开脚本，修改前会自动备份当前版本。
   - **回滚脚本**：点击“回滚”按钮可从历史版本恢复旧稿。
   - **主题切换**：支持 Light/Dark/System 模式切换。

---

## 💡 内置实用脚本介绍

目前系统中已包含以下脚本：

### 1. 📤 [Push-ToGitHub.ps1](file:///d:/powershell_manage/Scripts/Push-ToGitHub.ps1)
- **功能**：一键将本地文件夹推送到 GitHub 仓库。
- **用法**：运行后输入文件夹路径和 GitHub 仓库 URL，脚本会自动完成 `git init`、`commit` 和 `push`。

### 2. 📑 [Count_files.ps1](file:///d:/powershell_manage/Scripts/Count_files.ps1)
- **功能**：递归统计指定文件夹下指定扩展名文件的数量，支持多类型预设和自定义扩展名。
- **特点**：支持连续统计多个路径，默认开启“继续统计”模式，结果按数量降序显示各类型占比.

### 3. 📦 [Zip_to_img_to_pdf.ps1](file:///d:/powershell_manage/Scripts/Zip_to_img_to_pdf.ps1)
- **功能**：全自动化文档数字化流水线。
- **特点**：集成 ZIP 批量解压、图像提取与高质 PDF 合成。支持任务完成后自动清理原压缩包及临时文件夹，保持工作区整洁。需依赖 ImageMagick 7+。

---

## ⚠️ 注意事项

1. **环境要求**：需安装 Python 3.10+ 环境。
2. **权限说明**：如果无法运行 PowerShell 脚本，请以管理员身份打开 PowerShell 并运行：
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
3. **备份机制**：修改脚本时系统会自动备份旧版本到 `VersionBackup` 文件夹。

---

祝你使用愉快！如有疑问，请随时通过脚本管理工具查看详情。
