# HONOR MagicBook Pro 14 2026（ZQC-P，主板 M1050）Ubuntu 26.04 适配说明

本仓库是 [danilrwx/honor-magicbook-pro-14-2026-ubuntu](https://github.com/danilrwx/honor-magicbook-pro-14-2026-ubuntu)
的分支，保留完整上游历史，在此之上记录了**这一台机器**从 Windows 11 迁到
Ubuntu 26.04 时真正生效的修改、部署文档和恢复工具。目的只有一个：万一需要
重新部署，能照着做完，不必重新调查一遍。

机器身份：产品码 `ZQC-P`，主板版本 `M1050`，SKU `C233`，BIOS 1.12，
Secure Boot 开启，参考内核 `7.0.0-43-generic`。

[英文 README](README.md) 描述的是"这套修复在受支持机型上的状态"；本页只描述
这台机器上**审计到的**状态。两者不一致时，以下面的表为准。

---

## 快速部署（顺序不要改）

```sh
git clone git@github.com:miuzujia2018-stack/honor-magicbook-pro-14-2026-ubuntu26.git
cd honor-magicbook-pro-14-2026-ubuntu26

sudo python3 tools/honor-acpi-preflight.py     # 只读：确认固件表是原始/已打过/不匹配
sudo bash tools/install-honor-input-fix.sh     # 输入设备覆盖层，本机验证过的那套路
sudo SKIP_INPUT=1 bash apply_patch.sh          # 其余全部步骤
sudo reboot                                    # 蓝屏 MokManager：Enroll MOK，一次性密码 0000

bash tools/audit-m1050-ubuntu.sh               # 只读审计，脱敏
```

为什么要这个顺序：本机的触控板、触摸屏和键盘是**手工**修的（早期 initrd ACPI
覆盖 + `i8042.dumbkbd=1`），早于 `apply_patch.sh` 自己的步骤 2；这台机器上
`/usr/lib/firmware/acpi` 根本不存在，说明走的一直是手工那条路。所以先手工装、
再用 `SKIP_INPUT=1` 让后续步骤别去动它。直接跑 `sudo bash apply_patch.sh`
是上游路线，本机没试过。

`apply_patch.sh` 会下载内核源码（约 260 MB）并编译几分钟。MOK 不在 MokManager
里注册，Secure Boot 就只认发行版自带模块，显示修复等于没装。

**这套流程从未在空盘上完整执行过。** 下一次真 reinstall 才是它的第一次验证。

---

## 这台机器当前的实际状态

依据是 `bash tools/audit-m1050-ubuntu.sh` 在内核 `7.0.0-43-generic` 上的输出。

| 项目 | 状态 | 依据 |
|---|---|---|
| 触控板 / 触摸屏 / 键盘 | 工作 | `ACPI: Table Upgrade: override [SSDT- HONOR-I2C_DEVT]`，`FTSC1000:00`、`TOPS0102:00` 已枚举；由手工覆盖层提供 |
| 启动花屏（Panther Lake CDCLK） | 已修复 | 签名 `xe.ko` 覆盖层，stamp `wanted=cdclk-ptl`，本次启动无 FIFO underrun |
| 指纹 Goodix `27c6:6f94` | 工作 | 已录入并 `fprintd-verify` 返回 `verify-match`；`libfprint-2-2`、`libfprint-2-tod1` 处于 hold |
| 音频（SOF + ALC256） | 工作 | DSP 固件 2.14.1.1 启动、`sof-hda-dsp` 声卡在位、`picked fixup alc255-dell2` |
| `snd-sof` 覆盖层 | 仅在旧内核上存在 | `7.0.0-30`/`-38` 有覆盖层，`-42`/`-43` 没有：更新内核的树内代码已含该修复 |
| 内置麦克风阵列 | 工作 | `patch/dmic-array/` 的 PipeWire 源 |
| 风扇转速 | 可读 | 两个 input 分别 2308 / 1949 RPM |
| 电池充电阈值 | 生效 | EC 阈值对 70-90% |
| 性能键 / 相机键 | 工作 | `honor-hotkey-actions.service` 在监听 |
| Wi-Fi | 工作 | `wlp0s20f3` 绑定 `iwlwifi`，state=up |
| 蓝牙 / 摄像头 | 已枚举 | `hci1` 在位，`video0/1` FHD Camera；未做完整功能验证 |

## 未解决 / 未验证——不要当成已完成

| 项 | 现象 | 说明 |
|---|---|---|
| eDP DSC 色深 | stamp 仍是 `patches=cdclk-ptl` | 本仓库为 Ubuntu 7.0 内核 rebase 了 `patch/edp-dsc/…-linux-7.0.0.patch`，但运行模块里没有它，等于没生效 |
| OLED VBT 亮度下限 | `Requesting VBT firmware "honor/zqc-p-vbt.bin" failed (-2)` | 文件和 initramfs hook 都在，但驱动取不到；不要凭"文件存在"判成功，亮度下限仍是固件默认 |
| `udev-hid-bpf` 缺失 | 两条 HID-BPF udev 规则报 `No such file or directory` | mic-mute 修复显示"phantom 设备不在，等效已生效"，但触控板左边缘亮度手势需要装上该程序并实机测试 |
| 从零重装 | 无 | 见上面"快速部署"的提醒 |

---

## 本仓库在上游之外新增的东西

| 位置 | 作用 |
|---|---|
| `devices/zqc-p.conf`、`patch/fingerprint/zqc-p/M1050/` | 纠正本机指纹：上游 M1050 档案写的是 EgisTec ET171 `1c7a:05aa`（SDCP，发行版 libfprint 还不支持），实际总线是 Goodix `27c6:6f94`；附针对 1.95.1+tod1 rebase 的 `goodixmoc` patch |
| `lib/xe-build.sh` | 构建时优先选用按运行内核基线 rebase 过的 patch（`<patch>-linux-<base>.patch`），没有则回落到通用 patch |
| `patch/edp-dsc/…-linux-7.0.0.patch` | 针对 Ubuntu 26.04 内核显示驱动布局 rebase 的 DSC patch（**尚未验证生效**） |
| `patch/sof-audio/install.sh` | 优先从 `linux-source` 包取 SOF 源码（先核对包 ABI 与运行内核一致），绕开 GitHub API 限流；不匹配或非 Debian 系仍走上游 stable tree |
| `apply_patch.sh` + `README.md` + `docs/INSTALL.md` | 新增 `SKIP_INPUT=1` |
| `tools/install-honor-input-fix.sh`、`tools/honor-acpi-preflight.py`、`tools/test-honor-phantom-input.py` | 收编原本散在家目录的三个脚本：手工输入覆盖安装、只读固件表比对、触摸屏幽灵键盘集合的 EVIOCGRAB 取证。硬编码路径已改为按脚本自身位置定位 |
| `tools/audit-m1050-ubuntu.sh`、`docs/deployments/ZQC-P-M1050-ubuntu-26.04.md` | 脱敏审计脚本 + 现场报告（花屏怎么恢复、CDCLK 定向重建、已知缺口） |
| `docs/REDEPLOY.md` | 重装清单：命令顺序、MOK、验证、回滚 |

---

## 脚本维护约定

`tools/` 是唯一维护版本。家目录 `~/` 下的三个原脚本**保留但不再修改**，作为
仓库外的应急副本：机器已经正常，不值得为了整洁改动现有入口；软链接执行时
`BASH_SOURCE` 解析的真实路径可能把 `~/` 当成仓库根；仓库目录本身损坏时，外面
还得留一份能用的东西。要改就改 `tools/` 里的那份。

## 备份与回滚

- 提交前的原始状态备份：`~/backup/honor-ubuntu26-work-20261116/`
  （未提交 diff、两个新 patch、三个脚本原件）
- 输入覆盖回滚：`tools/install-honor-input-fix.sh` 每次执行会打印一个
  `/root/honor-input-backup-<时间戳>` 目录，里面有 `rollback.sh`
- 撤销本仓库全部改动：`sudo bash uninstall_patch.sh`
- 只摘掉某个内核的 `xe` 覆盖层：见
  [现场报告](docs/deployments/ZQC-P-M1050-ubuntu-26.04.md)"Removing only the
  per-kernel xe overlay"一节；操作时先进另一个已知能启动的内核
- 内核升级后：`/etc/kernel/postinst.d/95-honor-kernel-modules` 会自动重建覆盖层，
  核对 stamp 里的 `kver` 是否等于当前 `uname -r`；改过 `patch/` 或 `lib/` 后
  要重跑安装，因为钩子执行的是 root 持有的副本 `/usr/local/lib/honor/repo`，
  不是你的 checkout

## 提交内容里没有什么

不含序列号、文件系统 UUID、MAC 地址、指纹模板或数据、MOK 私钥、initramfs、
ACPI dump。唯一带本机用户名的是现场报告里 MOK 密钥的**显示名**。
`/var/lib/fprint/` 永远不要备份进任何仓库。

## 许可

上游部分按 [LICENSE](LICENSE) 的 MIT，`dump/` 里的出厂固件数据不属可授权范围，
`patch/fingerprint/`、`patch/fan/` 等第三方代码保留各自许可——细节见英文 README
的 Licence 一节。
