#!/usr/bin/env bash
# Scoped ACPI input fix. Run from an Ubuntu terminal with sudo.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo.'; exit 1; }
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
aml="$repo/patch/acpi-override/zqc-p/M1010/SSDT27_TPD0.aml"
archive=/boot/honor-input-acpi.cpio
config=/etc/default/grub.d/99-honor-input.cfg
[[ $(cat /sys/class/dmi/id/sys_vendor) == HONOR && $(cat /sys/class/dmi/id/product_name) == ZQC-P && $(cat /sys/class/dmi/id/board_version) == M1050 ]] || { echo 'Machine mismatch.'; exit 1; }
for cmd in python3 cpio update-grub grub-script-check; do command -v "$cmd" >/dev/null; done
[[ -d /etc/default/grub.d && -f /etc/default/grub && -f /boot/grub/grub.cfg ]] || { echo 'Expected Ubuntu GRUB layout missing.'; exit 1; }
[[ ! -e $archive && ! -e $config ]] || { echo 'Fix files already exist; inspect before repeating.'; exit 1; }
python3 - "$aml" <<'PY'
import hashlib, sys
from pathlib import Path
patched=Path(sys.argv[1]).read_bytes()
assert hashlib.sha256(patched).hexdigest() == '69da48fe21e7afa43d172ccb9a5469cbbd0548e0c6cff5a806a4c63cd3b05178', 'Unexpected patch'
matches=[]
for path in Path('/sys/firmware/acpi/tables').glob('SSDT*'):
    data=path.read_bytes()
    if data[16:24] == b'I2C_DEVT': matches.append(data)
assert len(matches) == 1, 'Expected exactly one I2C_DEVT table'
assert hashlib.sha256(matches[0]).hexdigest() == '8afc6d51d3813af7e1e6f23d604a315e5224399f538424e218f51e95ccf5d59a', 'Firmware mismatch; refusing override'
assert sum(patched)%256 == 0, 'Invalid ACPI checksum'
print('Firmware and patch hashes verified.')
PY
backup="/root/honor-input-backup-$(date +%Y%m%d-%H%M%S)"
install -d -m 0700 "$backup"
cp -a /etc/default/grub "$backup/grub.default"
cp -a /etc/default/grub.d "$backup/grub.d"
cp -a /boot/grub/grub.cfg "$backup/grub.cfg"
cat > "$backup/rollback.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ $EUID == 0 ]] || exit 1
rm -f /etc/default/grub.d/99-honor-input.cfg
update-grub
rm -f /boot/honor-input-acpi.cpio
echo 'Input fix removed. Reboot when ready.'
SH
chmod 0700 "$backup/rollback.sh"
work=$(mktemp -d)
changed=0
cleanup() {
  rc=$?
  trap - EXIT
  if (( rc != 0 && changed )); then
    rm -f "$config" "$archive"
    cp -a "$backup/grub.cfg" /boot/grub/grub.cfg
    echo "Installation failed; restored previous GRUB configuration. Backup: $backup"
  fi
  rm -rf "$work"
  exit "$rc"
}
trap cleanup EXIT
install -Dm0644 "$aml" "$work/kernel/firmware/acpi/SSDT27_TPD0.aml"
(cd "$work"; printf '%s\n' kernel kernel/firmware kernel/firmware/acpi kernel/firmware/acpi/SSDT27_TPD0.aml | cpio --quiet -o -H newc) > "$work/override.cpio"
cpio -it < "$work/override.cpio" | grep -Fxq kernel/firmware/acpi/SSDT27_TPD0.aml
changed=1
install -m0644 "$work/override.cpio" "$archive"
cat > "$config" <<'SH'
# Scoped HONOR ZQC-P M1050 input fix; existing settings remain in place.
GRUB_EARLY_INITRD_LINUX_CUSTOM="honor-input-acpi.cpio ${GRUB_EARLY_INITRD_LINUX_CUSTOM:-}"
case " ${GRUB_CMDLINE_LINUX_DEFAULT:-} " in
  *' i8042.dumbkbd=1 '*) ;;
  *) GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:-} i8042.dumbkbd=1" ;;
esac
SH
update-grub
grub-script-check /boot/grub/grub.cfg
grep -E '^[[:space:]]*initrd.*honor-input-acpi.cpio' /boot/grub/grub.cfg >/dev/null
grep -E '^[[:space:]]*linux.*i8042.dumbkbd=1' /boot/grub/grub.cfg >/dev/null
echo "Installation and GRUB checks passed. Backup: $backup"
echo "Rollback: sudo bash $backup/rollback.sh"
echo 'Reboot when ready; then verify touchpad, touchscreen and keyboard.'
