#!/usr/bin/env python3
"""Temporarily isolate only the touchscreen's vendor keyboard collection."""
import fcntl
import os
from pathlib import Path
import select
import struct
import time

target = 'FTSC1000:00 2808:5662 UNKNOWN'
nodes = [p for p in Path('/sys/class/input').glob('event*')
         if (p / 'device/name').read_text().strip() == target]
if len(nodes) != 1:
    raise SystemExit('Expected exactly one phantom device; refusing to proceed.')
node = '/dev/input/' + nodes[0].name
fd = os.open(node, os.O_RDONLY | os.O_NONBLOCK)
event = struct.Struct('@llHHi')
try:
    print('Checking only phantom device for 5 seconds:', node, flush=True)
    deadline = time.monotonic() + 5
    count = 0
    while time.monotonic() < deadline:
        if select.select([fd], [], [], max(0, deadline-time.monotonic()))[0]:
            data = os.read(fd, event.size * 64)
            for offset in range(0, len(data), event.size):
                _, _, typ, code, value = event.unpack_from(data, offset)
                if typ == 1 and code == 248:
                    count += 1
    print('Phantom mic-mute events in 5 seconds:', count, flush=True)
    fcntl.ioctl(fd, 0x40044590, 1)  # EVIOCGRAB; only this exact vendor node
    print('Phantom input isolated for 45 seconds. Try typing in another window now.', flush=True)
    print('Touchpad, touchscreen and real keyboards remain available. Ctrl+C ends early.', flush=True)
    time.sleep(45)
except KeyboardInterrupt:
    pass
finally:
    os.close(fd)  # Automatically releases the grab, even on interruption.
    print('Test ended; original input routing restored.', flush=True)
