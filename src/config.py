import customtkinter as ctk

# -------------------------- 配置 --------------------------
SCRIPT_ROOT = r"D:\powershell_manage\Scripts"
BACKUP_ROOT = r"D:\powershell_manage\VersionBackup"
METADATA_FILE = r"D:\powershell_manage\ScriptMetaData.json"

# 设置主题
def init_theme():
    ctk.set_appearance_mode("System")  # Modes: "System" (standard), "Dark", "Light"
    ctk.set_default_color_theme("blue")  # Themes: "blue" (standard), "green", "dark-blue"
