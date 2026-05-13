# Shift Ledger / 工时账本

Shift Ledger 是一个本地优先的个人工时账本 Flutter App。当前首发目标是 Android APK，同时保留 Flutter 跨平台空间。

它不是企业考勤系统：不做账号、审批、团队管理、定位、人脸识别、通知或实时云同步；核心目标是让个人快速记录工时、核算收入，并能把数据安全地导出和备份。

## 当前功能

- 记录工时：新增、查看、编辑、删除工时记录。
- 一天多段：同一天可记录多段班次。
- 日历查看：支持月视图和列表视图。
- 汇总下钻：按本月、本周、年度、发薪周期、自定义周期查看工时与收入，并下钻到明细。
- 计薪规则：支持按小时、按天、按月，支持规则生效日期和历史记录快照稳定。
- 加班 / 夜班：支持加班倍率、休息日倍率、夜班规则。
- 补贴 / 扣款：记录级补贴和扣款会进入收入计算。
- CSV 导出：导出工时、规则快照和收入拆分。
- 本地备份 / 恢复：普通备份不包含 WebDAV 应用授权密码。
- 坚果云 WebDAV：支持手动备份、恢复、导入/导出列表。
- 自动云备份：可选开启；启动后延迟检查，数据变更后防抖备份，最小间隔 1 小时、每天最多 6 次，同内容不重复上传。

## 安装 APK

推荐手机下载小包（绝大多数近年 Android 手机）：

```text
release/shift-ledger-android-v1.0.0+1-arm64-v8a-release.apk
```

SHA-256：

```text
a26c049133cff58191b1e3c9dd1c4b9eddb6cf17e8023f9608aa1ba3d1e44864
```

如果不确定手机 CPU 架构，使用兼容性更强的通用安装包：

```text
release/shift-ledger-android-v1.0.0+1-release.apk
```

SHA-256：

```text
a84fa85b1f54b0116441c28d511599c906048418f0387bccb7b0971d41b5dba0
```

更多签名与安装说明见：`docs/installation/android-release.md`。

## 为什么 APK 有 40 多 MB？

这是 Flutter Android **通用 APK** 的正常体积，不是业务代码膨胀。

实际拆包结果显示，约 47.5 MiB 都在 `lib/` 原生库里，主要包含三套 CPU 架构：

| ABI | 压缩后约占 |
| --- | ---: |
| `arm64-v8a` | 16.2 MiB |
| `armeabi-v7a` | 13.8 MiB |
| `x86_64` | 17.5 MiB |

其中最大的是 Flutter 引擎 `libflutter.so` 和 Dart AOT 产物 `libapp.so`。业务功能多少对这个基础体积影响很小。

如果只给常见 Android 真机安装，可以构建按 CPU 架构拆分的 APK：

```bash
flutter build apk --release --split-per-abi
```

本机实测拆分后大小：

| 文件 | 用途 | 大小 |
| --- | --- | ---: |
| `release/shift-ledger-android-v1.0.0+1-arm64-v8a-release.apk` | 绝大多数近年 Android 手机；已提交 | 约 17.6 MB |
| `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` | 老 32 位 Android 设备 | 约 15.1 MB |
| `build/app/outputs/flutter-apk/app-x86_64-release.apk` | 模拟器 / 少量 x86 设备 | 约 19.0 MB |

当前仓库同时保留通用 APK 和 `arm64-v8a` 小包。手机下载优先用 `arm64-v8a`；遇到架构不兼容再用通用 APK。

## 开发与验收命令

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Web 预览可用：

```bash
flutter build web
python3 -m http.server 8093 -d build/web
```

说明：`flutter build web` 可能会出现 `flutter_secure_storage_web` 的 wasm dry-run warning；当前首发交付是 Android APK，该 warning 不影响 APK 安装与运行。

## 数据与安全边界

- App 本地优先，无账号依赖。
- WebDAV 应用授权密码只通过 secure storage 保存。
- 普通本地备份、WebDAV 手动备份、自动云备份都不会把应用授权密码明文写入 JSON 备份。
- 自动云备份不是实时同步，也不做多端冲突合并。
