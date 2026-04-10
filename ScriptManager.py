from src.ui.app import ScriptManagerApp
from src.config import init_theme

if __name__ == "__main__":
    init_theme()
    app = ScriptManagerApp()
    app.mainloop()
