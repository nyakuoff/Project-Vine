#!/usr/bin/env python3
"""Vine launcher: settings for running the macOS Roblox client on Linux, and Launch / Stop.

Settings are written to ~/.config/vine/vine.conf (KEY=value lines) and read by
tests/run-roblox-darling.sh, which does the actual launch; the same names also work as environment
variables on the command line. Needs PySide6 (Qt 6).
"""
import os, shlex, subprocess, sys
from pathlib import Path
from PySide6.QtCore import QProcess, QTimer, QUrl, Qt
from PySide6.QtGui import QDesktopServices, QFontDatabase, QIcon, QPixmap
from PySide6.QtWidgets import (QApplication, QCheckBox, QComboBox, QDoubleSpinBox, QFormLayout, QGroupBox,
                               QHBoxLayout, QLabel, QPlainTextEdit, QPushButton, QSpinBox, QVBoxLayout, QWidget)

ROOT = Path(__file__).resolve().parent
CONF = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'vine' / 'vine.conf'

# key: (label, kind, default, help, choices for 'choice': [(value, text), ...])
SETTINGS = {
    'VINE_DISPLAY': ('Window', 'choice', 'desktop', 'Where Roblox opens.',
                     [('desktop', 'On the desktop'), ('', 'Hidden test display (screenshots in logs/screens)')]),
    'VINE_RENDERER': ('Renderer', 'choice', 'gl', "Roblox's OpenGL renderer on the native driver, or through Mesa Zink "
                      'on the Vulkan driver (experimental; the macOS client has no Vulkan renderer of its own).',
                      [('gl', 'OpenGL (native driver)'), ('zink', 'Vulkan (Zink, experimental)')]),
    'VINE_MOUSE_SENSITIVITY': ('Camera sensitivity', 'float', '1.0', 'Scales mouse movement while the camera holds the mouse.', None),
    'VINE_FPS_OVERLAY': ('Frame rate overlay', 'bool', '0', "Mesa's frame rate / frame time overlay in the corner.", None),
    'VINE_SESSION_MINUTES': ('Time limit', 'int', '0', 'Stop Roblox after this many minutes (0: no limit).', None),
    'VINE_GL_FULL_RENDERER': ('Antialiasing on AMD', 'invbool', '0', "Hide \"AMD\" from Roblox's GPU name so it does not apply "
                              "a workaround for Apple's AMD driver that turns antialiasing off.", None),
    'VINE_DARLING_AUDIO': ('Audio', 'choice', '0', "Play game audio on the host (pacat), or through Darling's own audio "
                           '(crashes now and then).', [('0', 'Host playback (recommended)'), ('1', "Darling's audio")]),
    'VINE_RBXTRANSPORT': ('Game network protocol', 'choice', '0', "RakNet works under Darling; Roblox's newer RbxTransport "
                          'is disconnected after ~10 s (error 256).', [('0', 'RakNet (recommended)'), ('1', 'RbxTransport')]),
    'VINE_NO_THROTTLE_PATCH': ('Fast start-up', 'invbool', '0', "Remove Roblox's start-up render throttle (finding credited "
                               'to MacOBlox; changes Vine\'s copy of the client only).', None),
    'VINE_TRACE_UDP': ('Network trace', 'bool', '0', 'Log game UDP traffic (diagnostics).', None),
}
SECTIONS = [('Game', ['VINE_DISPLAY', 'VINE_RENDERER', 'VINE_MOUSE_SENSITIVITY', 'VINE_FPS_OVERLAY', 'VINE_SESSION_MINUTES']),
            ('Compatibility', ['VINE_GL_FULL_RENDERER', 'VINE_DARLING_AUDIO', 'VINE_RBXTRANSPORT', 'VINE_NO_THROTTLE_PATCH']),
            ('Diagnostics', ['VINE_TRACE_UDP'])]


def load():
    values = {k: v[2] for k, v in SETTINGS.items()}
    if CONF.exists():
        for line in CONF.read_text().splitlines():
            k, _, v = line.partition('=')
            if k in SETTINGS:
                values[k] = v
    return values


def save(values):
    CONF.parent.mkdir(parents=True, exist_ok=True)
    tmp = CONF.with_suffix('.tmp')
    tmp.write_text(''.join(f'{k}={values[k]}\n' for k in SETTINGS))
    tmp.replace(CONF)


def roblox_running():
    return subprocess.run(['pgrep', '-f', '^/Applications/RobloxPlayer.app/Contents/MacOS/RobloxPlayer$'],
                          capture_output=True).returncode == 0


class Window(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle('Vine')
        self.setWindowIcon(QIcon(str(ROOT / 'assets/vine-logo.png')))
        self.values = load()
        self.inputs = {}
        layout = QVBoxLayout(self)
        # The text logo is white: on a dark banner it reads in light and dark themes alike.
        banner = QLabel(alignment=Qt.AlignCenter)
        banner.setStyleSheet('background: #111; border-radius: 6px; padding: 8px;')
        pix = QPixmap(str(ROOT / 'assets/vine-logo-text.png'))
        if not pix.isNull():
            banner.setPixmap(pix.scaledToHeight(64, Qt.SmoothTransformation))
            layout.addWidget(banner)
        for title, keys in SECTIONS:
            box = QGroupBox(title)
            form = QFormLayout(box)
            for k in keys:
                label, kind, _, tip, choices = SETTINGS[k]
                w = self.make_input(kind, self.values[k], choices)
                w.setToolTip(tip)
                lab = QLabel(label); lab.setToolTip(tip)
                form.addRow(lab, w)
                self.inputs[k] = (kind, w, choices)
            layout.addWidget(box)

        row = QHBoxLayout()
        self.launch = QPushButton('Launch Roblox'); self.launch.clicked.connect(self.on_launch)
        self.stop = QPushButton('Stop'); self.stop.clicked.connect(self.on_stop)
        prof = QPushButton('Profile (20 s)'); prof.setToolTip('Sample where Roblox spends its time (tests/profile.sh); run it during lag.')
        prof.clicked.connect(self.on_profile)
        logs = QPushButton('Logs folder'); logs.clicked.connect(lambda: QDesktopServices.openUrl(QUrl.fromLocalFile(str(ROOT / 'logs'))))
        for b in (self.launch, self.stop, prof, logs):
            row.addWidget(b)
        layout.addLayout(row)
        self.status = QLabel()
        layout.addWidget(self.status)
        self.out = QPlainTextEdit(readOnly=True)
        self.out.setFont(QFontDatabase.systemFont(QFontDatabase.FixedFont))
        self.out.setMaximumBlockCount(2000)
        self.out.setMinimumHeight(160)
        layout.addWidget(self.out)

        self.procs = {}
        self.timer = QTimer(self, interval=1000, timeout=self.refresh)
        self.timer.start()
        self.refresh()

    def make_input(self, kind, value, choices):
        if kind == 'choice':
            w = QComboBox()
            for v, text in choices:
                w.addItem(text, v)
            i = w.findData(value)
            w.setCurrentIndex(i if i >= 0 else 0)
        elif kind in ('bool', 'invbool'):
            w = QCheckBox()
            w.setChecked((value == '1') != (kind == 'invbool'))
        elif kind == 'float':
            w = QDoubleSpinBox(decimals=2, minimum=0.1, maximum=10.0, singleStep=0.05)
            w.setValue(float(value or 1))
        else:
            w = QSpinBox(minimum=0, maximum=24 * 60, suffix=' min')
            w.setSpecialValueText('No limit')
            w.setValue(int(value or 0))
        return w

    def collect(self):
        for k, (kind, w, _) in self.inputs.items():
            if kind == 'choice':
                self.values[k] = w.currentData()
            elif kind == 'bool':
                self.values[k] = '1' if w.isChecked() else '0'
            elif kind == 'invbool':
                self.values[k] = '0' if w.isChecked() else '1'
            elif kind == 'float':
                self.values[k] = f'{w.value():.2f}'
            else:
                self.values[k] = str(w.value())
        return self.values

    def run(self, argv, title):
        """Run argv in the background (one task per title), streaming its output into the window."""
        if self.busy(title):
            self.out.appendPlainText(f'({title} is already running)')
            return
        self.out.appendPlainText(f'$ {" ".join(shlex.quote(a) for a in argv)}')
        p = QProcess(self)
        p.setProcessChannelMode(QProcess.MergedChannels)
        p.setWorkingDirectory(str(ROOT))
        p.readyReadStandardOutput.connect(
            lambda: self.out.appendPlainText(bytes(p.readAllStandardOutput()).decode(errors='replace').rstrip()))
        p.finished.connect(lambda code, _s: (self.out.appendPlainText(f'({title} finished, exit {code})'), self.refresh()))
        self.procs[title] = p
        p.start(argv[0], argv[1:])
        self.refresh()

    def busy(self, title):
        p = self.procs.get(title)
        return p is not None and p.state() != QProcess.NotRunning

    def on_launch(self):
        save(self.collect())
        minutes = int(self.values['VINE_SESSION_MINUTES'] or 0)
        self.run([str(ROOT / 'tests/run-roblox-darling.sh'), str(minutes * 60 if minutes > 0 else 7 * 24 * 3600)], 'Roblox')

    def on_stop(self):
        # Stopping the Darling container ends Roblox; the launcher then cleans up (audio player, logs).
        self.run([str(ROOT / 'tests/darling-ns.sh'), '--stop'], 'Stop')

    def on_profile(self):
        if not roblox_running():
            self.out.appendPlainText('(Roblox is not running)')
            return
        self.run([str(ROOT / 'tests/profile.sh')], 'Profile')

    def refresh(self):
        running = roblox_running()
        launching = self.busy('Roblox')
        self.launch.setEnabled(not running and not launching)
        self.stop.setEnabled(running)
        self.status.setText('Roblox is running' if running else
                            'Launcher working (starting or cleaning up)…' if launching else 'Roblox is not running')

    def closeEvent(self, e):
        save(self.collect())
        super().closeEvent(e)


if __name__ == '__main__':
    app = QApplication(sys.argv)
    app.setApplicationName('Vine')
    w = Window()
    w.resize(560, 720)
    w.show()
    sys.exit(app.exec())
