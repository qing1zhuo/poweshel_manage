# 🛠️ PowerShell 脚本管理工具 (v1.2)

这是一个专为 Windows 用户设计的本地脚本管理系统。它能帮助你轻松管理日常使用的 PowerShell 脚本，支持脚本的**增删改查、版本回滚、功能描述以及一键运行**。

---

## 📂 项目结构

- `ScriptManager.ps1`: **管理工具入口**。运行此脚本即可进入交互式菜单。
- `Scripts/`: 脚本存放目录。所有的 `.ps1` 脚本都存放在这里。
- `VersionBackup/`: 版本备份目录。当你修改脚本时，旧版本会自动备份到这里。
- `ScriptMetaData.json`: 元数据文件。记录脚本的描述、版本号和创建时间。
- `CONTRIBUTING.md`: **开发与操作规范**。所有开发者修改本项目前必须阅读。

---

## 🚀 快速开始

1. **运行管理工具**：
   在项目根目录下，右键点击 `ScriptManager.ps1` 选择“使用 PowerShell 运行”，或在终端执行：
   ```powershell
   .\ScriptManager.ps1
   ```

2. **菜单功能详解**：
   - **[1] 新增脚本**：输入脚本名称和功能描述，工具会自动为你打开记事本编写代码。
   - **[2] 修改脚本**：选择一个脚本进行修改。工具会**先自动备份当前版本**，然后再打开编辑器。
   - **[3] 删除脚本**：彻底删除脚本及其所有历史备份（需二次确认）。
   - **[4] 版本回滚**：如果新改的代码有问题，可以随时回滚到之前的任意历史版本。
   - **[5] 查看列表**：一目了然地查看所有脚本的功能描述、当前版本和创建时间。
   - **[6] 运行脚本**：直接在管理工具内选择并执行脚本，无需手动切换目录。

---

## 💡 内置实用脚本介绍

目前系统中已包含以下脚本：

### 1. 📤 [Push-ToGitHub.ps1](file:///d:/powershell_manage/Scripts/Push-ToGitHub.ps1)
- **功能**：一键将本地文件夹推送到 GitHub 仓库。
- **用法**：运行后输入文件夹路径和 GitHub 仓库 URL，脚本会自动完成 `git init`、`commit` 和 `push`。

### 2. 📑 [Count_files.ps1](file:///d:/powershell_manage/Scripts/Count_files.ps1)
- **功能**：递归统计指定文件夹下 PDF 和 ZIP 文件的数量。
- **特点**：支持连续统计多个路径，默认开启“继续统计”模式。

### 3. 📦 [Zip_to_img_to_pdf.ps1](file:///d:/powershell_manage/Scripts/Zip_to_img_to_pdf.ps1)
- **功能**：自动化处理压缩包。解压 -> 提取图片 -> 合成 PDF -> 清理临时文件。
- **特点**：全自动化流程，适合批量处理文档图片。

---

## ⚠️ 注意事项

1. **权限说明**：如果无法运行脚本，请以管理员身份打开 PowerShell 并运行以下命令：
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
2. **默认选择**：所有的确认提示（Y/N）现在都默认为 **Y**。如果你想继续操作，直接按 **Enter** 即可。
3. **备份机制**：每次使用“修改脚本”功能时，系统都会自动在 `VersionBackup` 文件夹下创建一个备份，确保你的代码永远不会丢失。

---

祝你使用愉快！如有疑问，请随时通过脚本管理工具查看详情。
