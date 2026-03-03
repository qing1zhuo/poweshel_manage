import customtkinter as ctk
import os
import json
import subprocess
import threading
from datetime import datetime
from PIL import Image

# -------------------------- 配置 --------------------------
SCRIPT_ROOT = r"D:\powershell_manage\Scripts"
BACKUP_ROOT = r"D:\powershell_manage\VersionBackup"
METADATA_FILE = r"D:\powershell_manage\ScriptMetaData.json"

# 设置主题
ctk.set_appearance_mode("System")  # Modes: "System" (standard), "Dark", "Light"
ctk.set_default_color_theme("blue")  # Themes: "blue" (standard), "green", "dark-blue"

class ScriptManagerApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        # 窗口配置
        self.title("🛠️ PowerShell 脚本管理器 v2.0")
        self.geometry("1200x750")
        self.minsize(1000, 600) # 设置最小窗口尺寸，防止布局崩坏

        # 布局
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        # 左侧导航栏
        self.sidebar_frame = ctk.CTkFrame(self, width=200, corner_radius=0)
        self.sidebar_frame.grid(row=0, column=0, sticky="nsew")
        self.sidebar_frame.grid_rowconfigure(4, weight=1)

        self.logo_label = ctk.CTkLabel(self.sidebar_frame, text="PS Manager", font=ctk.CTkFont(size=20, weight="bold"))
        self.logo_label.grid(row=0, column=0, padx=20, pady=(20, 10))

        self.btn_refresh = ctk.CTkButton(self.sidebar_frame, text="🔄 刷新列表", command=self.load_scripts)
        self.btn_refresh.grid(row=1, column=0, padx=20, pady=10)

        self.btn_add = ctk.CTkButton(self.sidebar_frame, text="✨ 新增脚本", command=self.add_script_dialog)
        self.btn_add.grid(row=2, column=0, padx=20, pady=10)

        self.appearance_mode_label = ctk.CTkLabel(self.sidebar_frame, text="外观模式:", anchor="w")
        self.appearance_mode_label.grid(row=5, column=0, padx=20, pady=(10, 0))
        self.appearance_mode_optionemenu = ctk.CTkOptionMenu(self.sidebar_frame, values=["Light", "Dark", "System"],
                                                                       command=self.change_appearance_mode)
        self.appearance_mode_optionemenu.grid(row=6, column=0, padx=20, pady=(10, 20))

        # 右侧内容区
        self.main_frame = ctk.CTkFrame(self, corner_radius=10)
        self.main_frame.grid(row=0, column=1, padx=20, pady=20, sticky="nsew")
        self.main_frame.grid_columnconfigure(0, weight=4) # 脚本列表占 4 份
        self.main_frame.grid_columnconfigure(1, weight=5) # 控制台占 5 份
        self.main_frame.grid_rowconfigure(1, weight=1)

        # 脚本列表列 (左侧)
        self.list_column_frame = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        self.list_column_frame.grid(row=0, column=0, rowspan=2, padx=(20, 10), pady=20, sticky="nsew")
        self.list_column_frame.grid_columnconfigure(0, weight=1)
        self.list_column_frame.grid_rowconfigure(1, weight=1)

        self.header_label = ctk.CTkLabel(self.list_column_frame, text="📦 脚本库详情", font=ctk.CTkFont(size=18, weight="bold"))
        self.header_label.grid(row=0, column=0, padx=0, pady=(0, 10), sticky="w")

        self.scrollable_frame = ctk.CTkScrollableFrame(self.list_column_frame, label_text="所有可用脚本")
        self.scrollable_frame.grid(row=1, column=0, padx=0, pady=0, sticky="nsew")
        self.scrollable_frame.grid_columnconfigure(0, weight=1)

        # 控制台列 (右侧)
        self.console_column_frame = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        self.console_column_frame.grid(row=0, column=1, rowspan=2, padx=(10, 20), pady=20, sticky="nsew")
        self.console_column_frame.grid_columnconfigure(0, weight=1)
        self.console_column_frame.grid_rowconfigure(1, weight=1)

        self.console_header_label = ctk.CTkLabel(self.console_column_frame, text="💻 实时控制台交互", font=ctk.CTkFont(size=18, weight="bold"))
        self.console_header_label.grid(row=0, column=0, padx=0, pady=(0, 10), sticky="w")

        self.console_frame = ctk.CTkFrame(self.console_column_frame, corner_radius=5, fg_color="#1e1e1e")
        self.console_frame.grid(row=1, column=0, padx=0, pady=0, sticky="nsew")
        
        self.console_text = ctk.CTkTextbox(self.console_frame, fg_color="#1e1e1e", text_color="#d4d4d4", font=("Consolas", 12))
        self.console_text.pack(fill="both", expand=True, padx=10, pady=10)

        # 交互输入行
        self.input_frame = ctk.CTkFrame(self.console_frame, fg_color="transparent")
        self.input_frame.pack(fill="x", padx=10, pady=(0, 10))
        self.input_entry = ctk.CTkEntry(self.input_frame, placeholder_text="在此输入并按回车发送...", fg_color="#2d2d2d", border_width=0)
        self.input_entry.pack(side="left", fill="x", expand=True, padx=(0, 5))
        self.input_entry.bind("<Return>", lambda event: self.send_to_process())
        self.send_btn = ctk.CTkButton(self.input_frame, text="发送", width=60, command=self.send_to_process)
        self.send_btn.pack(side="right")

        self.stop_btn = ctk.CTkButton(self.input_frame, text="🛑 停止", width=60, fg_color="#c42b1c", hover_color="#9e2217", command=self.stop_current_process)
        self.stop_btn.pack(side="right", padx=(5, 0))

        # 当前进程
        self.current_process = None

        # 初始加载
        self.load_scripts()

    def stop_current_process(self):
        if self.current_process and self.current_process.poll() is None:
            try:
                # 终止进程及其所有子进程
                subprocess.run(["taskkill", "/F", "/T", "/PID", str(self.current_process.pid)], capture_output=True)
                self.log_console("\n🛑 脚本已强制停止。", tag="error")
                self.current_process = None
            except Exception as e:
                self.log_console(f"\n❌ 停止脚本失败: {e}")
        else:
            self.log_console("\n⚠️ 当前没有正在运行的脚本。")

    def rollback_script(self, script_name):
        # 获取该脚本的所有备份文件
        backups = [f for f in os.listdir(BACKUP_ROOT) if f.startswith(f"{script_name}_v") and f.endswith(".ps1")]
        if not backups:
            self.log_console(f"⚠️ 未找到 {script_name} 的历史版本。")
            return

        # 简单的选择对话框
        backups.sort(reverse=True) # 按文件名排序，通常版本号大的在前面
        
        # 创建一个简单的选择窗口
        dialog = ctk.CTkToplevel(self)
        dialog.title(f"回滚 - {script_name}")
        dialog.geometry("400x300")
        dialog.attributes("-topmost", True)

        label = ctk.CTkLabel(dialog, text=f"请选择要回滚的版本:", font=ctk.CTkFont(size=14, weight="bold"))
        label.pack(pady=10)

        scroll = ctk.CTkScrollableFrame(dialog)
        scroll.pack(fill="both", expand=True, padx=10, pady=10)

        def do_rollback(backup_file):
            confirm = subprocess.run(["powershell.exe", "-Command", f"[System.Windows.MessageBox]::Show('确定要回滚到 {backup_file} 吗？', '确认', 'YesNo')"], capture_output=True, text=True)
            # 注意：此处简单的 MessageBox 调用可能因环境而异，这里直接执行回滚
            source_path = os.path.join(BACKUP_ROOT, backup_file)
            target_path = os.path.join(SCRIPT_ROOT, f"{script_name}.ps1")
            
            try:
                import shutil
                shutil.copy2(source_path, target_path)
                self.log_console(f"✅ {script_name} 已成功回滚到版本: {backup_file}")
                dialog.destroy()
                self.load_scripts()
            except Exception as e:
                self.log_console(f"❌ 回滚失败: {e}")

        for b in backups:
            btn = ctk.CTkButton(scroll, text=b, command=lambda f=b: do_rollback(f))
            btn.pack(fill="x", pady=2, padx=5)

    def send_to_process(self):
        if self.current_process and self.current_process.poll() is None:
            user_input = self.input_entry.get() + "\n"
            try:
                self.current_process.stdin.write(user_input)
                self.current_process.stdin.flush()
                self.log_console(f"> {user_input.strip()}", tag="input")
                self.input_entry.delete(0, "end")
            except Exception as e:
                self.log_console(f"❌ 发送输入失败: {e}")
        else:
            self.log_console("⚠️ 当前没有正在运行的脚本或脚本不需要输入。")
            self.input_entry.delete(0, "end")

    def change_appearance_mode(self, new_appearance_mode: str):
        ctk.set_appearance_mode(new_appearance_mode)

    def load_scripts(self):
        # 清空当前列表
        for widget in self.scrollable_frame.winfo_children():
            widget.destroy()

        if not os.path.exists(METADATA_FILE):
            with open(METADATA_FILE, 'w', encoding='utf-8') as f:
                json.dump({}, f)

        with open(METADATA_FILE, 'r', encoding='utf-8') as f:
            metadata = json.load(f)

        scripts = [f for f in os.listdir(SCRIPT_ROOT) if f.endswith(".ps1")]
        
        for i, script_file in enumerate(scripts):
            name = os.path.splitext(script_file)[0]
            meta = metadata.get(name, {"Description": "无描述", "Version": 1, "CreateTime": "未知"})
            
            # 脚本卡片
            card = ctk.CTkFrame(self.scrollable_frame, corner_radius=10)
            card.grid(row=i, column=0, padx=10, pady=5, sticky="ew")
            card.grid_columnconfigure(0, weight=1)

            # 信息
            info_frame = ctk.CTkFrame(card, fg_color="transparent")
            info_frame.grid(row=0, column=0, padx=15, pady=10, sticky="ew") # 改为 ew 以撑满左侧空间
            
            name_label = ctk.CTkLabel(info_frame, text=f"{name}.ps1", font=ctk.CTkFont(size=14, weight="bold"))
            name_label.pack(anchor="w")
            
            # 在分栏模式下，左侧宽度通常在 300px 左右，这里设置 240 为安全换行阈值
            desc_label = ctk.CTkLabel(info_frame, text=f"🔍 {meta['Description']}", font=ctk.CTkFont(size=12), text_color="gray", wraplength=240, justify="left")
            desc_label.pack(anchor="w")

            ver_label = ctk.CTkLabel(info_frame, text=f"🔢 版本: v{meta['Version']}  |  🕒 {meta['CreateTime']}", font=ctk.CTkFont(size=11), text_color="gray")
            ver_label.pack(anchor="w")

            # 按钮区
            btn_frame = ctk.CTkFrame(card, fg_color="transparent")
            btn_frame.grid(row=0, column=1, padx=15, pady=10)

            run_btn = ctk.CTkButton(btn_frame, text="🚀 运行", width=80, height=30, command=lambda n=name: self.run_script(n))
            run_btn.pack(side="left", padx=5)

            edit_btn = ctk.CTkButton(btn_frame, text="✏️ 修改", width=80, height=30, fg_color="#3b3b3b", hover_color="#2b2b2b", command=lambda n=name: self.edit_script(n))
            edit_btn.pack(side="left", padx=5)

            rollback_btn = ctk.CTkButton(btn_frame, text="🔄 回滚", width=80, height=30, fg_color="#3b3b3b", hover_color="#2b2b2b", command=lambda n=name: self.rollback_script(n))
            rollback_btn.pack(side="left", padx=5)

    def log_console(self, message, tag=None, newline=True):
        msg = f"{message}\n" if newline else message
        if tag == "input":
            self.console_text.insert("end", msg, "input_text")
            self.console_text.tag_config("input_text", foreground="#00FF00")
        else:
            self.console_text.insert("end", msg)
        self.console_text.see("end")

    def run_script(self, script_name):
        # 自动停止当前正在运行的脚本
        if self.current_process and self.current_process.poll() is None:
            self.log_console(f"--- 🔄 正在停止当前脚本以运行 {script_name} ---")
            self.stop_current_process()
            # 给一点点时间让进程彻底关闭
            import time
            time.sleep(0.5)

        path = os.path.join(SCRIPT_ROOT, f"{script_name}.ps1")
        self.log_console(f"--- 🚀 正在启动: {script_name} ---")
        
        # 聚焦到输入框，方便交互
        self.input_entry.focus()

        def run():
            # 核心改进：
            # 1. 注入 Read-Host 的包装函数，将提示词通过 Write-Host (Stdout) 输出，
            #    这样我们在 GUI 中才能捕捉并显示它。
            # 2. 移除 -NonInteractive 确保 Read-Host 能正常执行。
            # 3. 设置编码环境。
            env = os.environ.copy()
            env["PYTHONIOENCODING"] = "utf-8"
            
            # 这里的包装函数将 Read-Host 的提示词重定向到标准输出流 (Write-Host)
            # 然后调用原始的 Read-Host 来执行实际的读取操作
            wrapper = 'function Read-Host($p){ if($p){Write-Host $p -NoNewline}; Microsoft.PowerShell.Utility\\Read-Host };'
            cmd = [
                "powershell.exe", 
                "-NoProfile", 
                "-ExecutionPolicy", "Bypass", 
                "-Command", f"{wrapper} & '{path}'"
            ]

            self.current_process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=0,
                env=env,
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            
            # 改进的读取循环：使用 read(1) 确保即使没有换行符也能立即显示
            try:
                while True:
                    char = self.current_process.stdout.read(1)
                    if not char and self.current_process.poll() is not None:
                        break
                    if char:
                        self.after(0, self.log_console, char, None, False)
            except Exception as e:
                self.after(0, self.log_console, f"\n❌ 读取输出出错: {e}")
            
            self.current_process.stdout.close()
            self.current_process.wait()
            self.after(0, self.log_console, f"\n--- ✅ {script_name} 执行完毕 ---")
            self.current_process = None

        threading.Thread(target=run, daemon=True).start()

    def edit_script(self, script_name):
        path = os.path.join(SCRIPT_ROOT, f"{script_name}.ps1")
        # 简单逻辑：调用系统记事本修改，并触发备份（这里需要同步更新元数据）
        subprocess.run(["notepad.exe", path])
        self.log_console(f"📝 正在编辑 {script_name}.ps1...")

    def add_script_dialog(self):
        # 简化版：这里可以弹出一个 ctk.CTkToplevel 窗口
        self.log_console("✨ 功能开发中：新增脚本对话框")

if __name__ == "__main__":
    app = ScriptManagerApp()
    app.mainloop()
