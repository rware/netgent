from seleniumbase import Driver
import logging
logger = logging.getLogger(__name__)
from selenium.webdriver.common.keys import Keys
from selenium import webdriver

"""
Initializes Browser Session with SeleniumBase.
With the pre-defined settings, the browser is ready to use.
"""
class BrowserSession:
    def __init__(self, proxy: str = None, user_data_dir: str | None = None):
        self._driver: Driver | None = None
        self._default_args: list[str] = [
            # "--profile.default_zoom_level: -2",
            "--disable-dev-shm-usage",
            "--disable-blink-features=AutomationControlled",
            "--no-sandbox",
            "--use-fake-ui-for-media-stream",
            "--use-fake-device-for-media-stream",
            "--window-size=1920,1080",
            "--start-maximized",
            "--disable-gpu",
            "--ssl-key-log-file=/opt/SSLkeylogs/sslkeylog.log"
        ]
        if user_data_dir:
            self._default_args.append(f" --user-data-dir={user_data_dir}")
        import os
        net_log_path = os.environ.get('NETGENT_NET_LOG')
        if net_log_path:
            self._default_args.append(f"--log-net-log={net_log_path}")
        self._args: str = ",".join(self._default_args)
        self.proxy: str = proxy
        self.user_data_dir: str | None = user_data_dir
        self.start()

    @property
    def driver(self) -> Driver:
        if self._driver is None:
            raise ValueError("Driver is not initialized")
        return self._driver

    def start(self):
        if self._driver is not None:
            raise ValueError("Driver is already initialized")
        # Ensure DISPLAY is set for visible browser on VNC
        import os
        if not os.environ.get('DISPLAY'):
            os.environ['DISPLAY'] = ':99'

        # Setup Xlib display for pyautogui on Linux/X11
        import Xlib.display
        import pyautogui
        from pyvirtualdisplay import Display
        #Added
        # v_display = Display(visible=True, size=(3840,2160), backend="xvfb", use_xauth=True)
        # v_display.start()
        #end of add
        pyautogui._pyautogui_x11._display = Xlib.display.Display(os.environ['DISPLAY'])
        num = int(os.environ['DISPLAY'][1:])
        # Don't use xvfb=True since we're managing Xvfb ourselves in the startup script
        self._driver = Driver(uc=True, headed=True, browser="chrome", chromium_arg=self._args, use_auto_ext=False,
            undetectable=True, proxy=self.proxy, user_data_dir=f"/urs/local/driver{num}")
        self._driver.set_window_size(3840,2160)
        # self._driver.set_window_size(1920,1080)

    def quit(self):
        if self._driver is None:
            raise ValueError("Driver is not initialized")
        self._driver.quit()
