"""Exercise the real Ziran executable, owned window and Linux child transport."""
import os
import ctypes
import ctypes.util
from pathlib import Path
import shlex
import struct
import subprocess
import sys
import tempfile
import time


def run(arguments, env, expected=0):
    result = subprocess.run(arguments, env=env, capture_output=True, text=True, timeout=15)
    assert result.returncode == expected, (arguments, result.returncode, result.stdout, result.stderr)
    return result


def close_window(window, pid, env):
    """Send the window manager's close request to our private, owned window."""
    assert env["DISPLAY"] == os.environ["DISPLAY"]
    assert int(run(["xdotool", "getwindowpid", window], env).stdout) == pid

    class Data(ctypes.Union):
        _fields_ = [("longs", ctypes.c_long * 5), ("bytes", ctypes.c_char * 20)]

    class Message(ctypes.Structure):
        _fields_ = [("type", ctypes.c_int), ("serial", ctypes.c_ulong),
                    ("send_event", ctypes.c_int), ("display", ctypes.c_void_p),
                    ("window", ctypes.c_ulong), ("message_type", ctypes.c_ulong),
                    ("format", ctypes.c_int), ("data", Data)]

    class Event(ctypes.Union):
        _fields_ = [("message", Message), ("pad", ctypes.c_long * 24)]

    x11 = ctypes.CDLL(ctypes.util.find_library("X11"))
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    x11.XInternAtom.restype = ctypes.c_ulong
    x11.XSendEvent.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int,
                              ctypes.c_long, ctypes.POINTER(Event)]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    display = x11.XOpenDisplay(env["DISPLAY"].encode())
    assert display, "Could not connect to the private display"
    try:
        event = Event()
        event.message.type = 33  # ClientMessage
        event.message.send_event = 1
        event.message.display = display
        event.message.window = int(window)
        event.message.message_type = x11.XInternAtom(display, b"WM_PROTOCOLS", 0)
        event.message.format = 32
        event.message.data.longs[0] = x11.XInternAtom(display, b"WM_DELETE_WINDOW", 0)
        assert x11.XSendEvent(display, int(window), 0, 0, ctypes.byref(event))
        x11.XFlush(display)
    finally:
        x11.XCloseDisplay(display)


def main():
    assert os.environ.get("T9_PRIVATE_XVFB") == "1", "Run through the private Xvfb test target"
    display = os.environ["DISPLAY"]
    authority = os.environ["XAUTHORITY"]
    binary = str(Path(sys.argv[1]).resolve())
    with tempfile.TemporaryDirectory(prefix="t9-window-", dir="build/ziran") as directory:
        work = Path(directory).resolve()
        shell = work / "shell"
        shell.write_text('#!/bin/sh\nexec /bin/sh -c "$2"\n')
        shell.chmod(0o700)
        env = os.environ.copy()
        for name in ("DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY", "ENV", "BASH_ENV",
                     "DBUS_SESSION_BUS_ADDRESS", "SESSION_MANAGER", "KRYON_CAPTURE_PATH"):
            env.pop(name, None)
        env.update(XDG_CONFIG_HOME=str(work / "config"), XDG_STATE_HOME=str(work / "state"),
                   KTREM_TARGET_FPS="15", KTREM_ACTIVE_FPS="30",
                   KTREM_PTY_BURST_MS="0", LP_NUM_THREADS="1", OMP_NUM_THREADS="1")
        assert "usage: t9" in run([binary, "--help"], env).stdout
        assert "t9 0.1" in run([binary, "--version"], env).stdout
        assert "\x1b[48;5;" in run([binary, "--color-table"], env).stdout
        assert "invalid geometry" in run([binary, "--geometry", "bad"], env, 2).stderr

        # The child gets only the explicitly created private display.
        env["DISPLAY"] = display
        env["XAUTHORITY"] = authority
        env["SDL_VIDEODRIVER"] = "x11"
        capture = work / "terminal.png"
        env["KRYON_CAPTURE_PATH"] = str(capture)
        result = run([binary, "--shell", str(shell), "--command", "printf 'Ziran Terminal\\n'",
                      "--hold", "--geometry", "40x12"], env)
        assert capture.is_file(), result.stderr
        png = capture.read_bytes()
        assert png.startswith(b"\x89PNG\r\n\x1a\n")
        assert struct.unpack(">II", png[16:24]) == (420, 318)
        assert len(png) > 1000, "The graphical frame is empty"
        env.pop("KRYON_CAPTURE_PATH")

        output = work / "input.bytes"
        command = "stty raw -echo; exec cat > " + shlex.quote(str(output))
        log = work / "window.log"
        with log.open("w") as stream:
            app = subprocess.Popen([binary, "--shell", str(shell), "--command", command,
                                    "--hold", "--title", "TerminalInputFixture", "--geometry", "40x12"],
                                   env=env, stdout=stream, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 10
                window = None
                while time.monotonic() < deadline:
                    assert app.poll() is None, log.read_text()
                    found = subprocess.run(["xdotool", "search", "--onlyvisible", "--pid", str(app.pid)],
                                           env=env, capture_output=True, text=True, timeout=3)
                    if found.returncode == 0 and found.stdout.strip() and output.exists():
                        window = found.stdout.splitlines()[0]
                        break
                    time.sleep(0.05)
                assert window, ("The owned Terminal window or child did not become ready",
                                output.exists(), log.read_text())
                run(["xdotool", "windowfocus", "--sync", window], env)
                run(["xdotool", "type", "--clearmodifiers", "--delay", "40", "Ziran"], env)
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline and output.read_bytes() != b"Ziran":
                    time.sleep(0.05)
                assert output.read_bytes() == b"Ziran", (output.read_bytes(), log.read_text())
                run(["xset", "r", "rate", "250", "12"], env)
                run(["xdotool", "keydown", "ctrl", "keydown", "a"], env)
                time.sleep(0.15)
                early = output.read_bytes()[5:]
                assert early == b"\x01", ("Held key flooded the child", early)
                time.sleep(0.6)
                run(["xdotool", "keyup", "a", "keyup", "ctrl"], env)
                time.sleep(0.15)
                repeated = output.read_bytes()[5:]
                assert 2 <= len(repeated) <= 12 and set(repeated) == {1}, repeated
                before = output.read_bytes()
                run(["xdotool", "key", "F10"], env)
                time.sleep(0.15)
                run(["xdotool", "key", "Escape"], env)
                time.sleep(0.15)
                assert app.poll() is None, "Escape closed the Terminal window"
                assert output.read_bytes() == before, "Menu input reached the terminal child"
                close_window(window, app.pid, env)
                assert app.wait(timeout=5) == 0, log.read_text()
            finally:
                if app.poll() is None:
                    app.terminate()
                    try:
                        app.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        app.kill()
                        app.wait(timeout=3)
    print("Terminal executable: CLI, real graphics, child input, held/repeated keys, menu ownership and owned-window close passed")


if __name__ == "__main__":
    main()
