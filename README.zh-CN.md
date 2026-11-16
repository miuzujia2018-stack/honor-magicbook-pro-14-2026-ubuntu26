# 在 HONOR MagicBook 上运行 Linux

> 本文是 [README.md](README.md) 的简体中文对应版本，章节与英文原文逐节对齐。
> 本分支在**一台具体机器**上的实际状态与差异，见文末
> [本分支：这台机器的实际状态](#本分支这台机器的实际状态与上文的差异)。

让 HONOR MagicBook 笔记本在 Linux 下可用的修复：为触控板和触摸屏打过补丁的
ACPI 表、为音频和传感器准备的内核模块 quirk、实现触控板手势的 HID-BPF 程序、
一个真正生效的电池充电阈值，以及 Fn 功能键。

在 **MagicBook Pro 14 2026（`ZQC-P`，主板 `M1010`）** 上构建并验证。
另有十六个主板修订被识别但全部未启用：Pro 系列的其余机型、第二个 `ZQC-P`
修订，以及其他 MagicBook 产品线中与它共享平台或共享某个零件的六台机器。
见[机型](#机型)和 [docs/hardware/](docs/hardware/)。

```sh
sudo ./apply_patch.sh
sudo reboot
```

`apply_patch.sh` 先识别机器，认不出来就停手。`uninstall_patch.sh` 撤销全部
改动。`tools/status.sh` 每个修复输出一行，已生效的显示绿色。

在开启 Secure Boot 的 Ubuntu 上，重新构建的模块用 machine owner key 签名，
你需要在下次启动时注册一次该密钥；见 [docs/UBUNTU.md](docs/UBUNTU.md)。

---

## 状态

| 方面 | 状态 | 修复 |
|---|---|---|
| 触控板、触摸屏、内置键盘 | 工作 | [`patch/acpi-override/`](patch/acpi-override/) — 打过补丁的 SSDT27 加上 `i8042.dumbkbd=1`。**机器可用的前提** |
| 麦克风自己静音、mic-mute 指示灯闪烁 | 工作 | [`patch/micmute/`](patch/micmute/) — 针对触摸屏厂商自定义 collection 的 HID-BPF 修正 |
| 指纹识别 Goodix `27c6:6f94` | 工作 | [`patch/fingerprint/`](patch/fingerprint/) — `libfprint` 两行 ID 补丁 |
| 耳机麦克风（3.5 mm 接口） | 工作 | [`patch/headset-mic/`](patch/headset-mic/) — 以 modprobe 选项启用发行版自带的 `alc255-dell2` model，无需重新构建 |
| 内置麦克风听起来空洞、像隔着一层 | 工作 | [`patch/dmic-array/`](patch/dmic-array/) — 阵列实际送来的是两个麦克风加 DSP 波束的反相副本，应用会把四路一起混；一份 PipeWire 配置改为默认输出那两个麦克风（走 WebRTC） |
| OLED 最低亮度过低、亮度步进不均 | 工作 | [`patch/oled-backlight/`](patch/oled-backlight/) — 打过补丁的 VBT 抬高固件的背光下限 |
| 鼠标指针后面跟着一条淡淡的宽横带 | 工作 | [`patch/psr-band/`](patch/psr-band/) — PSR2 的 selective update 只能刷新整行扫描线，于是每次局部更新都是一条通宽带；这里把 PSR 限制到没有该现象的 PSR1 |
| 触控板左边缘滑动（亮度手势） | 工作 | [`patch/touchpad-edge/`](patch/touchpad-edge/) — HID-BPF 把厂商手势报告转换成亮度键。右边缘（音量）走 EC，无需干预即可用 |
| 启动时花屏，内核 7.1.6 及更新版本 | 工作 | [`patch/cdclk-ptl/`](patch/cdclk-ptl/) — 用 Panther Lake 需要的上游 CDCLK 修复重新构建 `xe.ko`。该修复已于 2026-08-21 进入 `drm-intel-next`，预计随 Linux 7.3 发布并有稳定分支回移 |
| 屏幕被以每通道 6 bit 驱动，渐变有条带 | 工作 | [`patch/edp-dsc/`](patch/edp-dsc/) — 链路带宽不足 8 bpc，而驱动是先降色深再考虑压缩；一个内核补丁让它在 eDP 上优先使用 DSC，并可回退到原行为 |
| 电池充电阈值不起作用 | 工作 | [`patch/battery/`](patch/battery/) — EC 只执行 HONOR 自己的预设阈值对，其他值（包括桌面环境设置的）都被存下但忽略 |
| 性能键和相机键没反应 | 工作 | [`patch/hotkey-actions/`](patch/hotkey-actions/) — 一个小服务响应桌面环境忽略的那些按键 |
| 部分 Fn 键失效，dmesg 里 `Unknown key pressed` | 工作 | [`patch/hotkeys/`](patch/hotkeys/) — 把 HONOR 的按键码补进 `huawei-wmi` 键表 |
| 风扇转速读数 | 工作 | [`patch/fan/`](patch/fan/) — `honor-ec-sensors` |
| 风扇转速控制 | 不可用 | 所有由系统侧设置 duty cycle 的路径都被测过，EC 一概不理。EC 的*曲线*可以通过 `\IFCI` 选择，已做测量但**故意不随包发布**——它十三张表中有一张会把风扇直接关掉。见 [`patch/fan/README.md`](patch/fan/README.md) |
| SOF DSP 挂起/恢复 panic | 预防性 | [`patch/sof-audio/`](patch/sof-audio/) — 上游 IPC4 回移；本机上从未复现该竞态。已合入上游并随 Linux 7.2 发布 |
| 修复被软件包更新还原 | 已处理 | [`patch/auto-rebuild/`](patch/auto-rebuild/) — 包管理器钩子，负责重建它们 |
| Caps Lock 指示灯 | Linux 7.2 起工作 | 它原本是 `i8042.dumbkbd=1` 的连带损失。针对本机的上游 `atkbd` quirk 已进入 **7.2** 并排队进入 **7.1.10**；在那种内核上应当去掉这个参数。见 [`patch/keyboard-atkbd/`](patch/keyboard-atkbd/) |
| Fn+F7 麦克风静音键本身 | 开箱可用 | 树内 `huawei-wmi`，什么都不用装 |

扬声器、耳机输出、摄像头、Wi-Fi 和蓝牙除了 ACPI 覆盖之外不需要任何额外处理。
有一份关于 BIOS 1.09 机器的报告称扬声器会因同一个表加载失败而失效；本机
BIOS 1.10，codec 挂在 HDA 上，不受影响。见
[关于扬声器的分歧](docs/hardware/zqc-p.md#the-speakers-disagreement)。

---

## 机型

可信度按**主板修订**计算，不按产品型号。HONOR 会把同一个产品码出成好几台机器：
`ZQC-P` 在这里是主板 `M1010`，在别处是主板 `M1050`，而且 CPU 不同；`FMB-P`
跨三个 SKU 有五个修订。因此一个 profile 为每个修订单独设一节，各有自己的
状态，而没有被实测过的修订绝不会继承别的修订的结论。

十二个产品码下的十七个主板修订都会被识别。每台机器是什么、已知什么、每条结论
出自谁、要怎样才能升级其状态：**[docs/hardware/](docs/hardware/)**。那里才是
记录本身，本页不重复。

这十七个里只有两个启用任何修复。按安装顺序，**加粗**表示该修复会实际运行，
普通字体表示 profile 里列了但它拒绝运行——它会报名字、并说明缺的是哪个值，
不会静默跳过：

| 主板 | 修复 |
|---|---|
| `ZQC-P` `M1010` | **acpi-override** · **psr-band** · **oled-backlight** · **cdclk-ptl** · **edp-dsc** · **headset-mic** · **sof-audio** · **micmute** · **touchpad-edge** · **fan** · **fingerprint** · **battery** · **hotkeys** · **hotkey-actions** · **dmic-array** · **auto-rebuild** |
| `ZQC-P` `M1050` | **acpi-override** · **psr-band** · **oled-backlight** · **cdclk-ptl** · **edp-dsc** · **headset-mic** · **sof-audio** · **micmute** · **touchpad-edge** · **fan** · **fingerprint** · **battery** · **hotkeys** · **hotkey-actions** · **auto-rebuild** |

状态低于 `verified` 的主板只获得 tier A 子集，而 `apply_patch.sh` 在没有
`ALLOW_UNVERIFIED=1` 时拒绝在这种主板上启动。其余主板一个修复都没有，这是
刻意的，原因和状态词的含义都写在
[docs/hardware/README.md](docs/hardware/README.md#what-the-status-words-mean)。

上面两行内容相同，不等于它们背后的证据相同。逐项依赖什么，写在
[ZQC-P 页面](docs/hardware/zqc-p.md#what-the-verified-on-this-section-rests-on)。

该表由 profile 生成，若与 profile 出现漂移 `tools/selftest.sh` 会失败。

---

## 安装

```bash
git clone <本仓库> HONOR_ZQC-P_M1010
cd HONOR_ZQC-P_M1010
sudo ./apply_patch.sh
sudo reboot
```

全部流程就这些。它是幂等的，会把替换掉的每个文件备份进带时间戳的目录，而
ACPI 覆盖之后的每一步只告警不中止，因此某步构建不出来不会拖累其余步骤。

每个修复也都能单独执行，重复运行同样安全：

```sh
sudo bash patch/touchpad-edge/install.sh
```

### 它会先检查机器

`apply_patch.sh` 在动任何东西之前先读 DMI，并在 [`devices/`](devices/) 里寻找
匹配的 profile，找不到就停。步骤 2 要安装的 ACPI 表来自某一台具体机器的固件，
而一张外来 SSDT 不是那种"安静地失败"的修复。

每个修复的安装脚本自己也做同样的检查，所以直接跑 `patch/fan/install.sh`
和经由 `apply_patch.sh` 一样受约束；profile 没列出的修复，两条路都不装。

脚本里没有写死任何与型号相关的东西。实际装的零件 ID 从 profile 取，取回后
再对总线做一次确认。某个修复在某台机器上运行所需的东西——EC 转速计偏移、
背光下限、EC 实际支持的阈值对——跟该修复放在一起，位于
`patch/<fix>/<model>/<board>/recipe.conf`，目录名与 profile 指向同一台机器。
给某个修复增加一台机器，就是在那里写一个文件。

profile 的每个主板节都带一个 `status`，只有 `verified` 会解锁全部内容。低于
该状态时 `apply_patch.sh` 会停住，除非你传 `ALLOW_UNVERIFIED=1`，那时它只跑
那些不会把别的机器常量带过来的修复。状态词各自允许什么，见
[`docs/hardware/README.md`](docs/hardware/README.md#what-the-status-words-mean)。

有两个主板节是 `verified`：`ZQC-P` `M1010`（本项目就是在该机器上做的）和
`ZQC-P` `M1050`（依据是一台 `M1050` 提交的 dump、一整套 ACPI 表和安装日志）。
检测会报告它判定为哪块主板；当判定结果与 profile 描述的不一致时，它会明说。

### 可选变量

| 变量 | 作用 |
|---|---|
| `SKIP_INPUT=1` | 保留已有的触控板/触摸屏 ACPI 覆盖、键盘 workaround 和触控板边缘手势设置 |
| `SKIP_OLED=1` | 让 OLED 背光下限保持固件默认值 |
| `SKIP_EDGE=1` | 不启用触控板左边缘亮度手势 |
| `SKIP_FAN=1` | 不读取风扇 RPM |
| `SKIP_FINGERPRINT=1` | 不重建 `libfprint`（耗时最长的步骤） |
| `SKIP_HEADSET=1` | 不为 3.5 mm 耳机麦克风设置 codec model 选项 |
| `SKIP_SOF=1` | 不重建 `snd-sof`（预防性的 DSP 恢复修复） |
| `SKIP_DMIC=1` | 内置麦克风阵列保持为四路原始声道 |
| `VBT_MIN=<n>` | 背光下限，单位 n/255，默认 12。请先用 `patch/oled-backlight/measure-floor.sh` 量你自己的值 |
| `SKIP_CDCLK=1` | `xe.ko` 重建时不含 Panther Lake cdclk 修复 |
| `SKIP_DSC=1` | 重建时不含 DSC 优先级修复。两者只在 profile 列出时运行；构建会下载发行版内核源码（约 260 MB）并编译几分钟，两者同时需要时只构建一次 |
| `CHARGE_PRESET="40 70"` | 采用哪个电池充电预设。只有 EC 真正执行的阈值对有效，见 [`patch/battery/README.md`](patch/battery/README.md) |
| `FORCE_ACPI=1` | 即使你机器的 `I2C_DEVT` 表并非该补丁所依据的那张，也强行安装 ACPI 覆盖。这种不一致意味着 BIOS 更新改写了它，或者这是另一台机器；请先读 [docs/RESEARCH.md](docs/RESEARCH.md) |
| `ALLOW_UNVERIFIED=1` | 在 profile 状态不是 `verified` 的主板上运行，仅限那些自己推导输入的修复 |
| `GUARD_ZERO=1` | 增加一条 udev 规则，把对背光写 `0` 的操作反弹为 `1`。写 0 会让屏幕熄灭而不是变暗，任何 VBT 值都拦不住。默认关闭 |

逐步流程、如何确认生效、其他引导加载器的注意事项：**[docs/INSTALL.md](docs/INSTALL.md)**。

---

## 各个修复

每个修复在 [`patch/`](patch/) 下有独立目录和独立 README，说明坏在哪、量到了
什么、哪些思路被排除。索引见 [`patch/README.md`](patch/README.md)。

| | |
|---|---|
| [`acpi-override/`](patch/acpi-override/) | 打过补丁的 SSDT：触控板、触摸屏、键盘 |
| [`oled-backlight/`](patch/oled-backlight/) | 屏幕固件的最低亮度低到无法均匀渲染 |
| [`psr-band/`](patch/psr-band/) | 鼠标指针后跟着一淡淡通宽横带 |
| [`cdclk-ptl/`](patch/cdclk-ptl/) | 内核 7.1.6 及更新版本上启动花屏 |
| [`edp-dsc/`](patch/edp-dsc/) | 内屏被以每通道 6 bit 驱动 |
| [`battery/`](patch/battery/) | EC 静默忽略的充电阈值 |
| [`hotkeys/`](patch/hotkeys/) · [`hotkey-actions/`](patch/hotkey-actions/) | 没有去向的 Fn 键，以及有去向却没人处理 |
| [`micmute/`](patch/micmute/) · [`headset-mic/`](patch/headset-mic/) · [`dmic-array/`](patch/dmic-array/) · [`sof-audio/`](patch/sof-audio/) | 音频 |
| [`touchpad-edge/`](patch/touchpad-edge/) | 左边缘滑动 → 亮度 |
| [`fan/`](patch/fan/) · [`fingerprint/`](patch/fingerprint/) | 传感器、生物识别 |
| [`auto-rebuild/`](patch/auto-rebuild/) | 让上面的修复在软件包更新后仍然生效 |

---

## 文档

| | |
|---|---|
| [docs/INSTALL.md](docs/INSTALL.md) | 每一步、验证方法、其他引导加载器 |
| [docs/REDEPLOY.md](docs/REDEPLOY.md) | 在一台已知良好的 ZQC-P `M1050` / Ubuntu 26.04 上按顺序重建的命令清单 |
| [docs/deployments/ZQC-P-M1050-ubuntu-26.04.md](docs/deployments/ZQC-P-M1050-ubuntu-26.04.md) | 现场报告：`M1050` 在 Ubuntu 26.04 内核 7.0.0-38 上的恢复过程 |
| [docs/hardware/](docs/hardware/) | 每个型号一页：它是什么、什么能用、什么不能用、以及是谁弄清楚的 |
| [docs/TESTING.md](docs/TESTING.md) | 如果你有一台没人拥有的机型，该试什么、该报告什么 |
| [docs/SUPPORT.md](docs/SUPPORT.md) | 这里的"支持"意味着什么，问题该往哪提 |
| [docs/LIMITATIONS.md](docs/LIMITATIONS.md) | 什么不工作、为什么，包括风扇行为 |
| [docs/NPU.md](docs/NPU.md) | 神经网络加速器：开箱可用、值多少、以及 `sensors` 为什么看不到它 |
| [docs/ADDING-A-MODEL.md](docs/ADDING-A-MODEL.md) | dump → profile → verified 的逐步做法 |
| [docs/RESEARCH.md](docs/RESEARCH.md) | ACPI 覆盖是怎么推出来的，以及在别处重做一遍的方法 |
| [docs/WINDOWS-DUMP.md](docs/WINDOWS-DUMP.md) | 制作出厂系统侧 dump，用来回答"为什么 Windows 下能用" |
| [dump/](dump/) | 所有修复所依据的固件表与出厂系统导出 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 安装脚本的约定，如何提交补丁 |

---

## 有一台没被覆盖的机型？

**跟踪地点在 [Issue #11](https://github.com/rs0x29a/Linux-on-HONOR-MagicBook-14-Pro-2026-AI_ZQC-P_M1010/issues/11)。**
那里列着每个机型现在的位置、一份 dump 必须包含什么、哪些数值不能从机器上直接
读出来而必须在机器上实测。目前只有 `ZQC-P` 主板 `M1010` 是 verified，其他都在
等拥有该机器的人。

一条只读命令能产出编写 profile 所需的全部内容：

```sh
sudo bash tools/collect-hwinfo.sh
```

它只读 sysfs，绝不接触序列号属性，输出一个约 200 KB 的归档。

如果触控板完全不存在，那是 ACPI 表没能加载，修复它需要固件本身：

```sh
sudo bash tools/dump-acpi.sh
```

拿到结果怎么处理见 [docs/RESEARCH.md](docs/RESEARCH.md)，如果你还留着出厂系统，
见 [docs/WINDOWS-DUMP.md](docs/WINDOWS-DUMP.md)。用"Hardware dump for a
new model"模板把它附到 issue 上，另见 [docs/ADDING-A-MODEL.md](docs/ADDING-A-MODEL.md)。

---

## 致谢

- Linux 内核文档：
  [`Documentation/admin-guide/acpi/initrd_table_override.rst`](https://docs.kernel.org/admin-guide/acpi/initrd_table_override.html)
- ACPI 6.5 规范 §6.4.3.6 *I²C Serial Bus Connection Resource* 与 §9.18.1.4
  *_DSM Specific Object*
- 微软 HID-over-I²C 协议规范（UUID
  `3CDFF6F7-4267-4555-AD05-B30A3D8938DE`）——解释了 `i2c-hid-acpi` 用来发现
  HID 描述符寄存器地址的 `_DSM` 调用。**本补丁不需要它**，因为 OEM SSDT 已经在
  `\_SB.PC00.I2C1.TPD0._DSM` 里正确实现了。

### 本分支的来源

本页是一个 fork。不属于我们的那部分写在这里，而不是悄悄带过去：

- [danilrwx/honor-magicbook-pro-14-2026-ubuntu](https://github.com/danilrwx/honor-magicbook-pro-14-2026-ubuntu)
  是本仓库的基础。`patch/`、`devices/`、`lib/`、`dump/` 以及大部分 `docs/`
  都是那个仓库的成果，并且**保留完整 git 历史**而非压缩成一个提交，所以
  `git blame` 仍能追到原作者。本分支适用的许可条款也就是它的条款，包括下面的
  两点例外。
- [miuzujia2018-stack/honor-magicbook-pro-14-2026-ubuntu](https://github.com/miuzujia2018-stack/honor-magicbook-pro-14-2026-ubuntu)
  的 `m1050-ubuntu-7.0.0-38` 分支贡献了现场报告和
  `tools/audit-m1050-ubuntu.sh`，是以提交形式 merge 进来的，不是复制文件。
- 本分支在其之上增加了什么，见
  [docs/REDEPLOY.md](docs/REDEPLOY.md)，以及本页末尾一节
  [本分支：这台机器的实际状态](#本分支这台机器的实际状态与上文的差异)。

本仓库携带了哪些他人成果——EgisTec SDCP 补丁、
[thesofproject/linux PR 5762](https://github.com/thesofproject/linux/pull/5762)
的 SOF IPC4 回移、这些热键码最终源出的树外 `Huawei-WMI` 驱动、以及对同一颗
Goodix `27c6:6f94` 指纹模块的逆向工作——都记录在
[docs/hardware/README.md](docs/hardware/README.md#related-work) 的 Related work
表里，各机型页面还逐项写明了每条结论出自谁。本页不重复那份记录。

需要说清的一点：本分支为指纹加的那枚 `goodixmoc` 补丁，只是把 `27c6:6f94`
写进发行版 `libfprint` 驱动的 ID 表并沿用 `0x6A94` 的 12 阶段录入流程，
**没有取自上述逆向仓库**；该仓库的价值在于独立确认了同一颗模块的行为。
`recipe.conf` 里的 `origin=` 字段写的就是这个来源。

---

## 许可

MIT，见 [LICENSE](LICENSE)，另有两点例外。

**[`dump/`](dump/) 不在本项目的授权范围内。** 那是从机器上原样读出的出厂数据：
固件自己的 ACPI 表、PnP 设备列表，以及从出厂系统做的限定范围注册表导出。
[`patch/acpi-override/`](patch/acpi-override/) 里那张修正后的表同样如此——
它就是那张固件表，只把一条语句挪了位置。

**他人的代码保留其许可。** [`patch/fingerprint/`](patch/fingerprint/) 下的
补丁是第三方成果，作者信息保持完整，各自的出处写在旁边的 `recipe.conf` 里；
[`patch/fan/`](patch/fan/) 里的内核模块和 [`patch/keyboard-atkbd/`](patch/keyboard-atkbd/)
里的补丁为 GPL-2.0。

---

## 本分支：这台机器的实际状态（与上文的差异）

上文是上游 README 的对应翻译，描述的是"这套修复在受支持机型上的状态"。本节
只讲**这一台机器**审计到的结果：`ZQC-P` / 主板 `M1050` / SKU `C233` /
BIOS 1.12 / Secure Boot 开启 / 参考内核 `7.0.0-43-generic`。依据是
`bash tools/audit-m1050-ubuntu.sh` 的输出。

### 与上文不同的三件事

| 上文声称 | 本机实测 |
|---|---|
| eDP DSC「工作」 | 未生效。`/var/lib/honor/xe-module.stamp` 仍是 `patches=cdclk-ptl`；本分支为 Ubuntu 7.0 内核 rebase 了 `patch/edp-dsc/…-linux-7.0.0.patch`，但运行模块里没有它 |
| OLED 背光「工作」 | 未加载。`Requesting VBT firmware "honor/zqc-p-vbt.bin" failed (-2)`；补丁 VBT 文件和 initramfs hook 都在，但驱动取不到，下限仍是固件默认值——不要凭"文件存在"判定成功 |
| 触控板左边缘手势「工作」 | 待验证。`/usr/bin/udev-hid-bpf` 不存在，两条 HID-BPF udev 规则本次启动都报 `No such file or directory`；mic-mute 侧显示"phantom 设备不在，等效已生效"，左边缘手势需要装上该程序后实机测试 |

其余各项（ACPI 输入覆盖、CDCLK 花屏修复、指纹 `27c6:6f94`、`alc255-dell2`
耳机麦克风、`dmic-array`、风扇读数、阈值 70-90%、性能键与相机键、Wi-Fi）在本机
审计中工作，与上文一致。`snd-sof` 覆盖层只存在于 `7.0.0-30`/`-38`，`-42`/`-43`
没有——更新内核的树内代码已含该修复。

### 重装顺序与 `SKIP_INPUT=1` 的由来

本机的触控板、触摸屏和键盘是**手工**修的（限定范围的早期 initrd ACPI 覆盖 +
`i8042.dumbkbd=1`），早于 `apply_patch.sh` 自己的步骤 2；这台机器上
`/usr/lib/firmware/acpi` 不存在，说明一直走的是手工那条路。因此重装顺序是
"先手工装输入覆盖，再用 `SKIP_INPUT=1` 跑其余步骤"，而不是直接
`sudo bash apply_patch.sh`（那是上游路线，本机未试）。完整命令、MOK 注册、
验证与回滚见 **[docs/REDEPLOY.md](docs/REDEPLOY.md)**。

**该顺序从未在空盘上完整执行过**，下一次真实重装才是对它的验证。

### 本分支相对上游新增

| 位置 | 作用 |
|---|---|
| `devices/zqc-p.conf`、`patch/fingerprint/zqc-p/M1050/` | 纠正本机指纹：上游 `M1050` 档案写的是 EgisTec ET171 `1c7a:05aa`（说 SDCP，而发行版 `libfprint` 尚不支持该协议），本机总线实际是 Goodix `27c6:6f94`；附针对 1.95.1+tod1 rebase 的 `goodixmoc` 补丁 |
| `lib/xe-build.sh` | 构建时优先选择按运行内核基线 rebase 过的 `<patch>-linux-<base>.patch`，没有则回落到通用补丁 |
| `patch/edp-dsc/…-linux-7.0.0.patch` | 针对 Ubuntu 26.04 内核显示驱动布局 rebase 的 DSC 补丁（**尚未验证生效**） |
| `patch/sof-audio/install.sh` | 优先从 `linux-source` 包取 SOF 源码（先核对包 ABI 与运行内核一致），避开 GitHub API 限流；ABI 不匹配或非 Debian 系时仍走上游 stable tree |
| `apply_patch.sh` + 两份 README + `docs/INSTALL.md` | 新增 `SKIP_INPUT=1` |
| `tools/install-honor-input-fix.sh`、`tools/honor-acpi-preflight.py`、`tools/test-honor-phantom-input.py` | 收编原本散在家目录的三个脚本：手工输入覆盖安装、只读固件表比对、触摸屏幽灵键盘集合的 EVIOCGRAB 取证。硬编码路径已改为按脚本自身位置定位 |
| `tools/audit-m1050-ubuntu.sh`、`docs/deployments/ZQC-P-M1050-ubuntu-26.04.md` | 脱敏审计脚本 + 现场报告（花屏如何恢复、CDCLK 定向重建、已知缺口） |

### 脚本维护约定

`tools/` 是唯一维护版本。家目录下的三个原脚本保留但不再修改，作为仓库外的
应急副本：机器已正常工作，不值得为整洁改动现有入口；经由软链接执行时
`BASH_SOURCE` 解析出的真实路径可能把 `~/` 当成仓库根；仓库目录本身损坏时，
外面还得留一份能用的东西。

### 备份与回滚

- 提交前的原始状态备份：`~/backup/honor-ubuntu26-work-20261116/`（未提交 diff、
  两个新补丁、三个脚本原件）
- 输入覆盖回滚：`tools/install-honor-input-fix.sh` 每次执行会打印一个
  `/root/honor-input-backup-<时间戳>` 目录，里面有 `rollback.sh`
- 撤销本仓库全部改动：`sudo bash uninstall_patch.sh`
- 只摘掉某个内核的 `xe` 覆盖层：见[现场报告](docs/deployments/ZQC-P-M1050-ubuntu-26.04.md)
  "Removing only the per-kernel xe overlay"，操作时先进一个已知能启动的内核
- 内核升级后：`/etc/kernel/postinst.d/95-honor-kernel-modules` 自动重建覆盖层，
  核对 stamp 的 `kver` 是否等于当前 `uname -r`；改过 `patch/` 或 `lib/` 后要
  重跑安装，因为钩子执行的是 root 持有的副本 `/usr/local/lib/honor/repo`，
  不是你的 checkout

### 提交内容里没有什么

不含序列号、文件系统 UUID、MAC 地址、指纹模板或数据、MOK 私钥、initramfs、
ACPI dump。唯一带本机用户名的是现场报告里 MOK 密钥的**显示名**。
`/var/lib/fprint/` 永远不要备份进任何仓库。
