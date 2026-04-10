import customtkinter as ctk
import os

# 获取项目根目录 (D:\powershell_manage)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# -------------------------- 配置 --------------------------
SCRIPT_ROOT = os.path.join(BASE_DIR, "scripts")
BACKUP_ROOT = os.path.join(BASE_DIR, "backups")
METADATA_FILE = os.path.join(BASE_DIR, "data", "metadata.json")

# 设置主题
def init_theme():
    ctk.set_appearance_mode("System")  # Modes: "System" (standard), "Dark", "Light"
    ctk.set_default_color_theme("blue")  # Themes: "blue" (standard), "green", "dark-blue"
