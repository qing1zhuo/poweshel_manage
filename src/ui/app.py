import customtkinter as ctk
import os
import subprocess
import threading
import time
from src.config.settings import SCRIPT_ROOT, BACKUP_ROOT, METADATA_FILE
from src.core.script_logic import ScriptCore
from src.ui.dialogs import show_rollback_dialog, show_add_script_dialog

class ScriptManagerApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        # 初始化核心逻辑
        self.core = ScriptCore(logger_callback=self.log_console)

        # 窗口配置
        self.title("🛠️ PowerShell 脚本管理器 v2.0 (模块化版)")
        self.geometry("1200x750")
        self.minsize(1000, 600)

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
        self.main_frame.grid_columnconfigure(0, weight=4)
        self.main_frame.grid_columnconfigure(1, weight=5)
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
        self.console_text.tag_config("input_text", foreground="#00FF00")

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

    def log_console(self, message, tag=None, newline=True):
        msg = f"{message}\n" if newline else message
        if tag == "input":
            self.console_text.insert("end", msg, "input_text")
        else:
            self.console_text.insert("end", msg)
        self.console_text.see("end")

    def load_scripts(self):
        # 清空当前列表
        for widget in self.scrollable_frame.winfo_children():
            widget.destroy()

        metadata = self.core.load_metadata()
        scripts = self.core.get_scripts_list()
        
        for i, script_file in enumerate(scripts):
            name = os.path.splitext(script_file)[0]
            meta = metadata.get(name, {"Description": "无描述", "Version": 1, "CreateTime": "未知"})
            
            card = ctk.CTkFrame(self.scrollable_frame, corner_radius=10)
            card.grid(row=i, column=0, padx=10, pady=5, sticky="ew")
            card.grid_columnconfigure(0, weight=1)

            info_frame = ctk.CTkFrame(card, fg_color="transparent")
            info_frame.grid(row=0, column=0, padx=15, pady=10, sticky="ew")
            
            name_label = ctk.CTkLabel(info_frame, text=f"{name}.ps1", font=ctk.CTkFont(size=14, weight="bold"))
            name_label.pack(anchor="w")
            
            desc_label = ctk.CTkLabel(info_frame, text=f"🔍 {meta['Description']}", font=ctk.CTkFont(size=12), text_color="gray", wraplength=240, justify="left")
            desc_label.pack(anchor="w")

            ver_label = ctk.CTkLabel(info_frame, text=f"🔢 版本: v{meta['Version']}  |  🕒 {meta['CreateTime']}", font=ctk.CTkFont(size=11), text_color="gray")
            ver_label.pack(anchor="w")

            btn_frame = ctk.CTkFrame(card, fg_color="transparent")
            btn_frame.grid(row=0, column=1, padx=15, pady=10)

            run_btn = ctk.CTkButton(btn_frame, text="🚀 运行", width=80, height=30, command=lambda n=name: self.run_script(n))
            run_btn.pack(side="left", padx=5)

            edit_btn = ctk.CTkButton(btn_frame, text="✏️ 修改", width=80, height=30, fg_color="#3b3b3b", hover_color="#2b2b2b", command=lambda n=name: self.edit_script(n))
            edit_btn.pack(side="left", padx=5)

            rollback_btn = ctk.CTkButton(btn_frame, text="🔄 回滚", width=80, height=30, fg_color="#3b3b3b", hover_color="#2b2b2b", command=lambda n=name: show_rollback_dialog(self, n, self.core, self.load_scripts))
            rollback_btn.pack(side="left", padx=5)

    def stop_current_process(self):
        proc = self.current_process
        if proc and proc.poll() is None:
            try:
                subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True)
                self.log_console("\n🛑 脚本已强制停止。", tag="error")
                self.current_process = None
            except Exception as e:
                self.log_console(f"\n❌ 停止脚本失败: {e}")
        else:
            self.log_console("\n⚠️ 当前没有正在运行的脚本。")

    def run_script(self, script_name):
        # 运行新脚本前清空控制台
        self.console_text.delete("1.0", "end")

        if self.current_process and self.current_process.poll() is None:
            self.log_console(f"--- 🔄 正在停止当前脚本以运行 {script_name} ---")
            self.stop_current_process()
            time.sleep(0.5)

        path = os.path.join(SCRIPT_ROOT, f"{script_name}.ps1")
        self.log_console(f"--- 🚀 正在启动: {script_name} ---")
        self.input_entry.focus()

        wrapper = 'function Read-Host($p){ if($p){Write-Host $p -NoNewline}; Microsoft.PowerShell.Utility\\Read-Host };'
        cmd = [
            "powershell.exe", 
            "-NoProfile", 
            "-ExecutionPolicy", "Bypass", 
            "-Command", f"{wrapper} & '{path}'"
        ]

        try:
            env = os.environ.copy()
            env["PYTHONIOENCODING"] = "utf-8"
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
        except Exception as e:
            self.log_console(f"❌ 启动脚本失败: {e}")
            return

        def read_output():
            proc = self.current_process
            try:
                while proc:
                    char = proc.stdout.read(1)
                    if not char and proc.poll() is not None:
                        break
                    if char:
                        self.after(0, self.log_console, char, None, False)
            except Exception as e:
                # 如果 proc 是因为被杀死而导致读取失败，且 self.current_process 已被置空，则忽略
                if self.current_process is not None:
                    self.after(0, self.log_console, f"\n❌ 读取输出出错: {e}")
            
            if proc:
                try:
                    proc.stdout.close()
                except:
                    pass
                
                # 检查是否是正常结束
                if self.current_process == proc:
                    self.after(0, self.log_console, f"\n--- ✅ {script_name} 执行完毕 ---")
                    self.current_process = None

        threading.Thread(target=read_output, daemon=True).start()

    def edit_script(self, script_name):
        self.core.backup_script(script_name)
        self.core.update_metadata(script_name)
        path = os.path.join(SCRIPT_ROOT, f"{script_name}.ps1")
        subprocess.Popen(["notepad.exe", path])
        self.log_console(f"📝 正在编辑 {script_name}.ps1 (版本已提升)...")
        self.load_scripts()

    def add_script_dialog(self):
        show_add_script_dialog(self, self.core, self.load_scripts)

    def change_appearance_mode(self, new_appearance_mode: str):
        ctk.set_appearance_mode(new_appearance_mode)

    def send_to_process(self):
        proc = self.current_process
        if proc and proc.poll() is None:
            user_input = self.input_entry.get() + "\n"
            try:
                proc.stdin.write(user_input)
                proc.stdin.flush()
                self.log_console(f"> {user_input.strip()}", tag="input")
                self.input_entry.delete(0, "end")
            except Exception as e:
                self.log_console(f"❌ 发送输入失败: {e}")
        else:
            self.log_console("⚠️ 当前没有正在运行的脚本或脚本不需要输入。")
            self.input_entry.delete(0, "end")
