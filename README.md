# Shift Ledger / 工时账本

Shift Ledger 是一个本地优先的个人工时账本 Flutter App，首发 Android APK。

它面向个人记录和核算工时，不是企业考勤系统；不做账号、审批、团队管理、定位、人脸识别、通知或实时云同步。

## 功能

- 新增、查看、编辑、删除工时记录。
- 支持一天多段工时。
- 日历月视图和列表视图。
- 汇总统计和明细下钻。
- 按小时 / 按天 / 按月计薪规则。
- 支持规则生效日期和历史记录快照稳定。
- 支持加班、夜班、补贴、扣款。
- 支持 CSV 导出。
- 支持本地备份 / 恢复。
- 支持坚果云 WebDAV 手动备份、恢复、导入/导出列表。
- 支持可选自动云备份：最小间隔 1 小时、每天最多 6 次、同内容跳过。

## 下载 APK

GitHub Release：

https://github.com/congmucc/shift-ledger-android/releases/tag/v1.0.0%2B1

推荐 Android 手机下载：

```text
shift-ledger-android-v1.0.0+1-arm64-v8a-release.apk
```

这个包适合绝大多数近年 Android 手机，体积更小。

如果安装时提示架构不兼容，再下载通用包：

```text
shift-ledger-android-v1.0.0+1-release.apk
```

本仓库内对应文件：

```text
release/shift-ledger-android-v1.0.0+1-arm64-v8a-release.apk
release/shift-ledger-android-v1.0.0+1-release.apk
```

校验值见同目录 `.sha256` 文件。

## 本地开发

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

按 ABI 生成更小的安装包：

```bash
flutter build apk --release --split-per-abi
```

## 许可

本项目使用 PolyForm Noncommercial License 1.0.0。

- 非商业使用：允许。
- 商业使用：不在公开许可范围内，必须先获得项目所有者书面授权。
- 授权商业使用仍需保留项目名称和开源项目地址说明。

详见 `LICENSE` 和 `NOTICE`。
