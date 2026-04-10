import customtkinter as ctk
import os
import subprocess
import shutil
import re
import json
from src.config.settings import SCRIPT_ROOT, BACKUP_ROOT, METADATA_FILE

def show_rollback_dialog(parent, script_name, core, refresh_callback):
    backups = core.get_backups(script_name)
    if not backups:
        core.log(f"⚠️ 未找到 {script_name} 的历史版本。")
        return

    dialog = ctk.CTkToplevel(parent)
    dialog.title(f"回滚 - {script_name}")
    dialog.geometry("400x350")
    dialog.attributes("-topmost", True)
    
    # 居中显示
    dialog.update_idletasks()
    x = parent.winfo_x() + (parent.winfo_width() // 2) - (400 // 2)
    y = parent.winfo_y() + (parent.winfo_height() // 2) - (350 // 2)
    dialog.geometry(f"+{x}+{y}")

    label = ctk.CTkLabel(dialog, text=f"请选择要回滚的版本:", font=ctk.CTkFont(size=14, weight="bold"))
    label.pack(pady=10)

    scroll = ctk.CTkScrollableFrame(dialog)
    scroll.pack(fill="both", expand=True, padx=10, pady=10)

    def do_rollback(backup_file):
        source_path = os.path.join(BACKUP_ROOT, backup_file)
        target_path = os.path.join(SCRIPT_ROOT, f"{script_name}.ps1")
        
        try:
            version_match = re.search(r'_v(\d+)\.ps1$', backup_file)
            new_version = int(version_match.group(1)) if version_match else 1
            
            core.backup_script(script_name)
            shutil.copy2(source_path, target_path)
            
            # 更新元数据
            metadata = core.load_metadata()
            metadata[script_name]["Version"] = new_version
            core.save_metadata(metadata)
            
            core.log(f"✅ {script_name} 已成功回滚到版本: {backup_file}")
            dialog.destroy()
            refresh_callback()
        except Exception as e:
            core.log(f"❌ 回滚失败: {e}")

    for b in backups:
        btn = ctk.CTkButton(scroll, text=b, command=lambda f=b: do_rollback(f))
        btn.pack(fill="x", pady=2, padx=5)

def show_add_script_dialog(parent, core, refresh_callback):
    dialog = ctk.CTkToplevel(parent)
    dialog.title("✨ 新增脚本")
    dialog.geometry("400x300")
    dialog.attributes("-topmost", True)
    
    # 居中显示
    dialog.update_idletasks()
    x = parent.winfo_x() + (parent.winfo_width() // 2) - (400 // 2)
    y = parent.winfo_y() + (parent.winfo_height() // 2) - (300 // 2)
    dialog.geometry(f"+{x}+{y}")

    ctk.CTkLabel(dialog, text="脚本名称 (无需 .ps1):", font=ctk.CTkFont(weight="bold")).pack(pady=(20, 5))
    name_entry = ctk.CTkEntry(dialog, width=300)
    name_entry.pack(pady=5)
    name_entry.focus()

    ctk.CTkLabel(dialog, text="功能描述:", font=ctk.CTkFont(weight="bold")).pack(pady=(10, 5))
    desc_entry = ctk.CTkEntry(dialog, width=300)
    desc_entry.pack(pady=5)

    def save():
        name = name_entry.get().strip()
        desc = desc_entry.get().strip()
        if not name:
            return
        
        file_path = os.path.join(SCRIPT_ROOT, f"{name}.ps1")
        if os.path.exists(file_path):
            core.log(f"⚠️ 脚本 {name}.ps1 已存在。")
            dialog.destroy()
            return

        template = f'''<#
.SYNOPSIS
    {desc}
.DESCRIPTION
    详细描述...
.PARAMETER ParameterName
    参数说明...
.EXAMPLE
    运行示例...
#>

do {{
    Write-Host "--- 🚀 正在运行 {name} ---" -ForegroundColor Cyan
    # 核心逻辑开始
    
    # 核心逻辑结束
    $continueChoice = Read-Host "`n是否继续操作？(Y/N，默认Y)"
    $isContinue = ($continueChoice.Trim().ToLower() -ne "n")
}} while ($isContinue)
'''
        try:
            with open(file_path, 'w', encoding='utf-8-sig') as f:
                f.write(template)
            
            core.update_metadata(name, description=desc)
            core.log(f"✅ 成功创建脚本: {name}.ps1")
            subprocess.Popen(["notepad.exe", file_path])
            dialog.destroy()
            refresh_callback()
        except Exception as e:
            core.log(f"❌ 创建失败: {e}")

    ctk.CTkButton(dialog, text="创建并编辑", command=save).pack(pady=20)
