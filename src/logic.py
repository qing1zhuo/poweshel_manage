import os
import json
import shutil
import re
from datetime import datetime
from src.config import SCRIPT_ROOT, BACKUP_ROOT, METADATA_FILE

class ScriptCore:
    def __init__(self, logger_callback=None):
        self.logger = logger_callback

    def log(self, message, tag=None, newline=True):
        if self.logger:
            self.logger(message, tag, newline)

    def backup_script(self, script_name):
        source_path = os.path.join(SCRIPT_ROOT, f"{script_name}.ps1")
        if not os.path.exists(source_path):
            return

        metadata = self.load_metadata()
        meta = metadata.get(script_name, {"Version": 0})
        version = meta.get("Version", 0)
        
        backup_name = f"{script_name}_v{version}.ps1"
        backup_path = os.path.join(BACKUP_ROOT, backup_name)
        
        if not os.path.exists(BACKUP_ROOT):
            os.makedirs(BACKUP_ROOT)
            
        shutil.copy2(source_path, backup_path)
        self.log(f"📦 已自动备份当前版本到: {backup_name}")

    def load_metadata(self):
        if not os.path.exists(METADATA_FILE):
            with open(METADATA_FILE, 'w', encoding='utf-8-sig') as f:
                json.dump({}, f)
            return {}

        try:
            with open(METADATA_FILE, 'r', encoding='utf-8-sig') as f:
                return json.load(f)
        except Exception as e:
            self.log(f"❌ 读取元数据失败: {e}")
            return {}

    def save_metadata(self, metadata):
        try:
            with open(METADATA_FILE, 'w', encoding='utf-8-sig') as f:
                json.dump(metadata, f, indent=4, ensure_ascii=False)
        except Exception as e:
            self.log(f"❌ 保存元数据失败: {e}")

    def update_metadata(self, script_name, description=None, increment_version=True):
        metadata = self.load_metadata()
        
        if script_name not in metadata:
            metadata[script_name] = {
                "Description": description or "无描述",
                "Version": 1,
                "CreateTime": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
        else:
            if description:
                metadata[script_name]["Description"] = description
            if increment_version:
                metadata[script_name]["Version"] += 1

        self.save_metadata(metadata)

    def get_scripts_list(self):
        if not os.path.exists(SCRIPT_ROOT):
            os.makedirs(SCRIPT_ROOT)
        return [f for f in os.listdir(SCRIPT_ROOT) if f.endswith(".ps1")]

    def get_backups(self, script_name):
        if not os.path.exists(BACKUP_ROOT):
            return []
        backups = [f for f in os.listdir(BACKUP_ROOT) if f.startswith(f"{script_name}_v") and f.endswith(".ps1")]
        backups.sort(key=lambda x: os.path.getmtime(os.path.join(BACKUP_ROOT, x)), reverse=True)
        return backups
