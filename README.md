# Shift Ledger / 工时账本

Shift Ledger 是一个本地优先的个人工时账本 Flutter App，当前首发目标是 Android APK。

它面向个人记录、核算和备份工时数据，不是企业考勤系统；不做账号、审批、团队管理、定位、人脸识别、通知、广告或实时云同步。

## 当前定位

- **个人账本**：核心问题是“我哪天上了什么班、上了多久、按什么规则估算收入”。
- **本地优先**：无账号也能新增、查看、编辑、删除、统计、导出和本地备份。
- **Android-first Flutter**：代码保持 Flutter 跨平台基础，但当前交付和验证以 Android 为主。
- **数字可信**：工时、加班、夜班、补贴、扣款、收入估算和规则快照必须可追溯。

## 已实现功能

### 工时记录

- 新增、查看、编辑、删除工时记录。
- 支持一天多段工时。
- 支持跨天夜班，例如 22:00-06:00。
- 支持普通班、加班、夜班、临时班。
- 支持地点/岗位、备注、补贴、扣款。
- 编辑日期时会保留目标日期已有记录，并按目标日期刷新计薪规则快照。

### 规则与模板

- 班次模板：标准班、加班、夜班，也可编辑/新增/删除模板。
- 计薪规则：按小时、按天、按月。
- 规则生效日期：历史记录保存创建/编辑时的规则快照，避免新规则改写旧账。
- 加班规则：阈值、倍率、休息日倍率、加班基准小时工资。
- 夜班规则：固定补贴、按小时补贴、倍率模式。
- 发薪周期：自然月、每月固定起始日、自定义范围。

### 日历与汇总

- 日历月视图和列表视图。
- 使用 `table_calendar` 承载日历网格。
- 今日跳转、年月选择、日历标记和无障碍语义。
- 汇总范围：本月、本周、年度、发薪周期、自定义。
- 汇总下钻：出勤、偏长、备注、补贴、扣款、加班、明细展开。

### 导出与备份

- CSV 导出：包含归属日期、开始/结束日期时间、跨天标记、休息、净工时、普通/加班/夜班、规则名称、规则类型、规则快照、收入拆分、补贴、扣款、备注。
- 本地备份/恢复：备份记录、模板、规则和非敏感设置。
- 外部保存：CSV/JSON 导出通过系统保存面板，不硬写公共 Downloads 作为唯一方案。
- App 私有恢复副本：创建备份时同时保留 App 私有备份，用于“从最近本地备份恢复”。
- 坚果云 WebDAV：支持配置、手动备份、手动恢复、远端列表查看。
- 自动云备份：可选开启；最小间隔 1 小时、每天最多 6 次、同内容跳过；WebDAV 应用授权密码不进入普通备份。

## 当前技术实现

- Flutter / Dart，Material 3。
- 状态管理：`ChangeNotifier` + `LedgerState`。
- 本地持久化：JSON snapshot + `LocalLedgerRepository`。
- 敏感信息：WebDAV 应用授权密码使用 `flutter_secure_storage` 保存。
- 日历：`table_calendar`。
- 日期/时间选择：项目薄封装 + Flutter/Cupertino picker。
- 文件保存：`flutter_file_dialog` 系统保存面板。
- WebDAV：Dart `HttpClient`，Basic Auth，PUT/GET/PROPFIND。
- 自动备份 hash：`crypto` SHA-256。

## 项目结构

```text
lib/
  main.dart                         # App 入口、主题、持久化和自动备份调度
  src/app/ledger_state.dart         # 账本状态与业务状态变更
  src/domain/models.dart            # 纯 Dart 领域模型与序列化
  src/services/                     # 计薪、CSV、备份、本地仓库、WebDAV、自动备份
  src/ui/                           # 页面、组件、选择器、编辑 sheet、主题
test/
  domain/                           # 计薪与规则快照测试
  services/                         # CSV/备份/WebDAV/自动备份服务测试
  widget/                           # 主流程、设置、日历、自动备份调度 widget 测试
```

## 本地开发与验证

```bash
flutter pub get
flutter analyze
flutter test
```

构建 Android APK：

```bash
flutter build apk --release
```

按 ABI 生成更小安装包：

```bash
flutter build apk --release --split-per-abi
```

当前完成任何行为变更前，至少需要通过：

```bash
flutter analyze
flutter test
```

涉及 Android 安装包时再运行对应 `flutter build apk` 命令。

## 明确不做

- 不做企业审批、员工管理、排班发布、团队后台。
- 不做定位、人脸识别、打卡防作弊。
- 不做账号体系、广告、实时云同步、多端冲突合并。
- 不做通知提醒、桌面小组件、系统日历同步、PDF 月报。
- 不做复杂税务、社保、个税、公司薪资日历或法定节假日工资条。

## 许可

本项目使用 PolyForm Noncommercial License 1.0.0。

- 非商业使用：允许。
- 商业使用：不在公开许可范围内，必须先获得项目所有者书面授权。
- 授权商业使用仍需保留项目名称和开源项目地址说明。

详见 `LICENSE` 和 `NOTICE`。
