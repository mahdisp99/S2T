from __future__ import annotations

import sys

from stt_windows.gui_app import SpeechToTextTrayApp


def main() -> int:
    app = SpeechToTextTrayApp()
    return app.run()


if __name__ == "__main__":
    sys.exit(main())

