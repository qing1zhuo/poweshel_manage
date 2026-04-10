from src.ui.app import ScriptManagerApp
from src.config.settings import init_theme

def main():
    init_theme()
    app = ScriptManagerApp()
    app.mainloop()

if __name__ == "__main__":
    main()
