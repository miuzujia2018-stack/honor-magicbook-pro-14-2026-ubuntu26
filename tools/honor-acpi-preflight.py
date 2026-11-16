#!/usr/bin/env python3
"""Read-only comparison of firmware tables; never installs an override."""
from pathlib import Path
import hashlib

repo = Path(__file__).resolve().parents[1]
stock = (repo / 'dump/acpi/zqc-p/SSDT27_orig.aml').read_bytes()
patched = (repo / 'patch/acpi-override/zqc-p/M1010/SSDT27_TPD0.aml').read_bytes()
for key in ('sys_vendor', 'product_name', 'board_name', 'board_version', 'bios_version'):
    print(key + ':', (Path('/sys/class/dmi/id') / key).read_text().strip())
found = False
for path in sorted(Path('/sys/firmware/acpi/tables').glob('SSDT*')):
    try:
        data = path.read_bytes()
    except PermissionError:
        raise SystemExit('Cannot read firmware tables. Run this script with sudo.')
    if data[16:24].rstrip(b'\x00 ') != b'I2C_DEVT':
        continue
    found = True
    print('Table:', path.name, 'bytes:', len(data))
    print('SHA256:', hashlib.sha256(data).hexdigest())
    print('Checksum valid:', sum(data) % 256 == 0)
    print('Result:', 'EXACT_STOCK_MATCH' if data == stock else
          'ALREADY_PATCHED' if data == patched else 'MISMATCH_DO_NOT_OVERRIDE')
if not found:
    print('I2C_DEVT not found; do not force an override.')
