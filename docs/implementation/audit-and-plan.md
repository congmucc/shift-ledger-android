# Shift Ledger 审计与实现计划

## 1. 全域审计结论

### 当前状态
- 仓库位于 `/Users/eason/Desktop/project/shift-ledger-android`，当前 `main` 无提交，只有 `.gitignore`、`PRD.html`、`DESIGN.md`、`PROTOTYPE.html` 与 `.vscode/settings.json`。
- 本地 Flutter 可用：Flutter 3.41.9 stable，Dart 3.11.5，JDK 17 可用。
- 项目目录未实际包含 `AGENTS.md` 文件；本轮按会话注入的 AGENTS 协作四原则执行，不额外改写项目协作规则。

### 基准文件判断
- `PRD.html` 明确产品边界：个人工时账本、本地优先、Android-first Flutter、不做企业考勤/通知/实时云同步/GPS/审批等。
- `DESIGN.md` 明确视觉：暖色纸面、安静金融感、日历优先、数字可信、低压私密；底部导航五视觉位置：首页 / 日历 / 中间新增 / 汇总 / 设置。
- `PROTOTYPE.html` 明确交互意图：首页今日工作台、日历网格/列表、汇总下钻、设置中的规则与备份、弹层式新增/编辑/删除/计薪规则。
- `.gitignore` 已覆盖 Flutter、Android、构建产物、签名密钥、`.env` 与本地验证产物；暂不需要扩大忽略范围。

### 冲突与取舍
- PRD 建议 Drift + SQLite / Riverpod，但当前目标是从空仓库交付可运行闭环。为避免生成代码和迁移复杂度，MVP 采用 `ChangeNotifier + JSON 本地存储`，用 repository/service 边界保留替换 Drift 的空间。这符合“本地优先”和“不过度设计”。
- PRD 要求坚果云 WebDAV 手动备份/导入/导出，并要求敏感密码不能进普通备份。MVP 实现 WebDAV 配置和手动 PUT/GET/PROPFIND；应用密码仅保存在运行期配置与本地设置中，普通备份导出时剔除 `appPassword`。
- PRD 要求 Flutter Android APK，同时保持跨平台空间。初始化以 Android 为首发交付目标，业务/UI 代码不写 Android 专属逻辑；文件选择/安全存储等能力先用可替换的服务接口与标准库落地。
- PROTOTYPE 是静态展示，不包含完整表单状态机。工程实现采用可运行 Flutter 表单：新增/编辑 day sheet、分段编辑、删除确认、规则编辑、导出/备份操作反馈。

### 阻塞判断
- 无阻塞实现的问题。
- 风险点：完整 Drift/安全存储/文件选择会拉长周期；本轮优先交付可运行、可测试、可安装闭环，并在服务边界处记录后续替换点。

## 2. 成功标准映射

- App 可启动，视觉遵守 `DESIGN.md` 的暖纸面账本风格。
- 底部导航五视觉位置：首页 / 日历 / 中间新增 / 汇总 / 设置。
- 新增、查看、编辑、删除工时记录；支持一天多段和删除当天记录。
- 支持按小时 / 按天 / 按月计薪规则；支持生效日期、记录覆盖、规则快照稳定。
- 支持加班、夜班、补贴、扣款，且汇总可区分普通/加班/夜班。
- 日历支持月网格与列表视图；点击日期查看/编辑当天记录。
- 汇总支持月/周/年度/发薪周期/自定义入口，并能下钻出勤、备注、加班、异常、补贴、扣款列表。
- 支持 CSV 导出。
- 支持本地备份/恢复。
- 支持坚果云 WebDAV 手动备份、导入、导出；普通备份不明文包含应用密码。
- 验收命令：`flutter analyze`、`flutter test`、本地运行 smoke、`flutter build apk`。

## 3. 最小实现架构

```text
lib/
  main.dart                         # App 入口、主题、导航壳
  src/app/                          # AppState、页面导航、示例种子数据
  src/domain/                       # WorkEntry、PayRule、Summary 等纯 Dart 模型
  src/services/                     # 计薪、CSV、备份、WebDAV、repository
  src/ui/                           # 页面、组件、表单 sheet、下钻 sheet
test/
  domain/                           # 计薪与快照稳定测试
  services/                         # CSV/备份/WebDAV 数据处理测试
  widget/                           # 导航、CRUD、导出备份入口 widget 测试
```

边界原则：领域计算不依赖 Flutter UI；本地存储、CSV、备份、WebDAV 是服务层；UI 只调 AppState，不直接拼计算逻辑。

## 4. 实施步骤与提交点

1. **基线提交**：提交已有 PRD/DESIGN/PROTOTYPE/.gitignore 与本计划。
2. **Flutter 初始化**：运行 `flutter create --platforms=android --project-name shift_ledger --org app.shiftledger .`，提交生成工程。
3. **领域模型与计薪测试优先**：先写计薪、跨天、规则快照、按小时/天/月、加班/夜班、补贴/扣款测试，再实现 `domain` 与 `pay_calculator`。
4. **存储/导出/备份服务**：先写 CSV 与备份脱敏测试，再实现 JSON repository、CSV exporter、backup service、WebDAV client。
5. **AppState 与种子数据**：实现本地加载/保存、默认模板/规则、记录 CRUD、汇总下钻数据源。
6. **UI 闭环**：实现主题、底部导航、首页、日历、汇总、设置、添加/编辑/删除 sheet、计薪规则 sheet、WebDAV sheet。
7. **Widget/验收测试**：覆盖启动导航、创建 09:00-18:00 记录、多段加班、删除、CSV/备份入口。
8. **最终验收与修复**：跑 analyze/test/run/build apk，按结果做最小修复，最终提交并确认 main clean。

## 5. 暂不做/降级项

- 不做通知、桌面小组件、系统日历导入导出、PDF、实时云同步、GPS、人脸、审批、团队管理。
- 不做复杂公司薪资日历、税务社保个税、冲突合并。
- Drift/SQLite、Riverpod、flutter_secure_storage 可作为后续替换增强；当前先用清晰边界的 JSON 本地存储与 ChangeNotifier，避免空仓库首版过度设计。
