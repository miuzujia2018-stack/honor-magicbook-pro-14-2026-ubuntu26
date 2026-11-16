# Redeploy: ZQC-P, board M1050, Ubuntu 26.04

Ordered commands that reproduce the state this machine actually runs, so a
fresh disk does not become a fresh investigation. The narrative — what broke,
how it was recovered — is
[deployments/ZQC-P-M1050-ubuntu-26.04.md](deployments/ZQC-P-M1050-ubuntu-26.04.md);
this page is the checklist only.

Reference state, audited on this unit: kernel `7.0.0-43-generic`, Secure Boot
enabled, BIOS 1.12, `linux-source-7.0.0` at the same ABI as the running kernel.

This is the state read off a working machine, not a tested restore. The
sequence below has never been run against a blank disk, so treat a fresh
install as the test it is: verify each step as it goes, and expect the open
gaps listed at the bottom rather than a complete adaptation.

## 0. Before touching the disk

- Keep one known-good kernel installed until the new one has finished a
  graphical boot. GRUB -> Advanced options is the only way back once the
  display is wrong.
- Never `dpkg --purge grub-pc` here, see [UBUNTU.md](UBUNTU.md).
- `sudo apt update` first. Each step installs the build tools it needs, so
  there is no dependency list to pre-install.

## 1. Input override, then everything else

```sh
git clone git@github.com:miuzujia2018-stack/honor-magicbook-pro-14-2026-ubuntu26.git
cd honor-magicbook-pro-14-2026-ubuntu26
sudo python3 tools/honor-acpi-preflight.py     # read-only: stock / already-patched / mismatch
sudo bash tools/install-honor-input-fix.sh
sudo SKIP_INPUT=1 bash apply_patch.sh
```

The touchpad, touchscreen and keyboard on this board were fixed by
`install-honor-input-fix.sh` before `apply_patch.sh` had a step covering them,
and that hand-installed override is what has been in use ever since:
`/usr/lib/firmware/acpi` does not exist on this machine. `SKIP_INPUT=1` keeps
step 2 and step 12 off it. `tools/honor-acpi-preflight.py` is read-only and
answers whether the live `I2C_DEVT` table is the stock one, already patched,
or something else — the installer refuses on the third case, so run it first.

Plain `sudo bash apply_patch.sh`, letting step 2 install its own table, is the
upstream route and has not been exercised on this unit.

## 2. Reboot and enrol the MOK

`apply_patch.sh` queues a machine owner key with the one-time password `0000`
(`MOK_PASSWORD=` overrides it). At the blue MokManager screen press a key — it
times out in seconds — then *Enroll MOK*, *Continue*, password. One enrolment
covers every overlay, now and after kernel updates. Without it Secure Boot
loads only the stock modules and the display fix is silently absent.

```sh
sudo reboot
```

## 3. Verify

```sh
bash tools/audit-m1050-ubuntu.sh
```

Read-only, and deliberately free of serials, filesystem ids, MACs, enrolled
finger names and key material. On this unit it ends with three warnings, which
are the known gaps below rather than a failed install:

```text
OK: no display FIFO underrun found
WARN: patched VBT was not loaded
WARN: xe stamp does not record edp-dsc
WARN: HID-BPF udev action failed during this boot
warnings: 3
```

`tools/status.sh` is not the authority for the module question: it counted any
`updates/xe.ko` as proof the DSC fix was in. The stamp is:

```sh
cat /var/lib/honor/xe-module.stamp      # wanted=cdclk-ptl  patches=cdclk-ptl
modinfo -k "$(uname -r)" -F signer xe    # the enrolled MOK name, not "None"
sudo journalctl -k -b | grep 'Table Upgrade'   # override [SSDT- HONOR-I2C_DEVT]
```

## 4. Fingerprint

The reader on this unit is Goodix `27c6:6f94`, not the EgisTec part the board
profile records, so libfprint is rebuilt from a patch and held:

```sh
apt-mark showhold                 # libfprint-2-2, libfprint-2-tod1
fprintd-enroll -f right-index-finger
fprintd-verify                    # verify-match
```

Dropping the hold lets an archive update replace the patched library and the
reader stops being recognised. Never copy `/var/lib/fprint/` anywhere.

## 5. After each kernel or libfprint update

`/etc/kernel/postinst.d/95-honor-kernel-modules` rebuilds the overlays for the
new kernel on its own; check the stamp reports the running `uname -r`.

The hooks run the root-owned copy in `/usr/local/lib/honor/repo`, not your
checkout. After editing anything under `patch/` or `lib/`, re-run the install
so the copy is refreshed:

```sh
sudo SKIP_INPUT=1 bash apply_patch.sh
```

## 6. Rollback

- One kernel's overlay, booted into another kernel: see the recovery note,
  "Removing only the per-kernel xe overlay".
- The input override: the installer prints its backup directory, which holds
  `rollback.sh` alongside the previous GRUB files.
- Everything the repository added: `sudo bash uninstall_patch.sh`.

## Known gaps, not to be reported as fixed

| Gap | Evidence |
|---|---|
| Patched OLED VBT is not loaded | `Requesting VBT firmware "honor/zqc-p-vbt.bin" failed (-2)`; the panel keeps its firmware brightness floor |
| eDP DSC preference is not installed | the rebased `patch/edp-dsc/…-linux-7.0.0.patch` exists, the stamp still reads `patches=cdclk-ptl` |
| Touchpad left-edge gesture | `/usr/bin/udev-hid-bpf` is absent, so both HID-BPF udev rules fail during boot and need the binary plus a physical test |
