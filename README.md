# Personal Archive · 个人档案读写协议（Skill）

> 让**任意 agent** 都按同一套规矩读写你的「个人档案」：板块结构、frontmatter、
> 正文禁令、写入与维护流程，以及它与智能体记忆库之间的**双仓隔离**与单向放行标准。

这是一个**通用 Skill**（`personal-archive/SKILL.md`），可拷到任何支持 agent skill 的目录使用，
**不依赖任何特定 harness**——与 [shared-agent-memory](https://github.com/Ruanzhou9/shared-agent-memory)
同源同构，一个管「机读记忆」，一个管「人读档案」。

---

## 🎯 它解决什么问题

| 没有它 | 有它 |
|---|---|
| 每个 agent 对"档案怎么记"各写各的，体例漂移 | 一套体例：多板块、文件名即主题、必填 frontmatter |
| agent 随手把私人笔记当成"记忆"读了、写了 | **默认静默**：只有你明确要求才动档案 |
| 档案与记忆库互相抄，两边都膨胀 | **双仓隔离**：互不镜像，只放行「对 agent 有用」的内容 |
| 体例混用、索引漏挂、正文混进绝对路径 | `doctor.sh` 机检：结构 / frontmatter / 禁令 / 索引一致 |
| 不知道装没装、装对没装对 | `install.sh` 自动铺到本机全部 agent 目录，`compat-check.sh` 逐个核对 |

## 🏗️ 三层与双仓

| 层 | 位置 | 受众 | 存什么 |
|---|---|---|---|
| 原始记录 | 各 agent 自身的会话存档（留在原地） | 备查 | 全量对话与凭证 |
| **人读档案** | 本技能指向的 `archive/`（真档案通常另放，如笔记库的 `个人档案/`） | **你本人** | 叙述体摘要、按板块组织 |
| 机读记忆 | `shared-agent-memory` 指向的 `memory/` | **agent** | 结构化条目、按优先级注入 |

> **双仓**：档案与记忆是**独立仓库、兄弟关系**，都派生自原始记录。
> 只有「对 agent 有用」的档案信息才允许**单向、逐条**放行到记忆库。

## ✨ 特性

- **一份协议，全部 agent**：`install.sh` 自动发现本机 skills 目录，一条命令铺满（含软链共享）。
- **默认静默**：agent 不以"可能有帮助"为由私自翻阅或追加档案；只有你说了才动。
- **体例即规范**：`总索引` + 板块目录（当前 `画像` / `日志` / `规范` / `决策` / `财务`），
  **板块可扩展**——新板块直接建目录并登记索引，`doctor.sh` 动态识别，不必改脚本。
- **frontmatter**：必填 `title`/`type`/`created`/`updated`；`tags`/`status` 推荐（缺失只提示不报错）。
- **正文禁令**：不写机器绝对路径、最小必要脱敏（证件号/卡号/手机号不落正文）；工具品牌名可正常出现。
- **双仓隔离**：三问门控 + 可行动性 ≥ 2 的硬门槛 + 红线一票否决；agent 默认不读档案。
- **可体检**：`scripts/doctor.sh` 把硬要求变成可校验检查（体例一致、索引一致、禁令、脱敏）。
- **跨平台**：macOS / Linux 用 `install.sh`（软链），Windows 用 `install.ps1`（Junction）。

## 🚀 快速开始

### macOS / Linux（bash）

```bash
git clone https://github.com/Ruanzhou9/personal-archive-skill.git
cd personal-archive-skill

# 1) 先看看会装到哪（不做任何修改）
bash install.sh --dry-run

# 2) 装到本机全部 agent，并把 archive/ 统一指向你的真档案（推荐）
bash install.sh --update --link-archive "<你的真档案路径>"

# 3) 体检
bash scripts/doctor.sh "<你的真档案路径>"

# 4) 兼容性核对 + 推送前隐私自检
bash scripts/compat-check.sh
bash scripts/pre-push-check.sh
```

### Windows（PowerShell）

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File install.ps1 -Update -LinkArchive "D:\path\to\个人档案"
```

> Windows 侧提供安装器（Junction 链接）与体检能力；`scripts/*.sh` 若要用，请在 Git-Bash 下运行。

### 手动方式（任意平台，按你用的 agent 选其一）

把 `personal-archive/` 整个目录拷到该 agent 的技能父目录下，命名为 `personal-archive/`；
再把它的 `archive/` 指向你的真档案（软链或直接拷模板骨架）。

## 📁 目录结构

```
personal-archive-skill/
├── personal-archive/            # 技能本体（拷到 agent 技能目录的就是它）
│   ├── SKILL.md                 # 读写协议：适用范围 / 触发条件 / 调用方式 / 硬性规范
│   └── archive/                 # 档案模板骨架（空模板，不含个人数据）
│       ├── 总索引.md
│       └── 画像/ 日志/ 规范/ 决策/ 财务/
├── install.sh / install.ps1     # 一键安装（自动发现 agent 技能目录；支持软链/Junction）
└── scripts/
    ├── doctor.sh                # 档案体检：结构/frontmatter/体例一致/禁令/脱敏/索引一致/版本
    ├── compat-check.sh          # 各 agent 副本兼容性核对
    └── pre-push-check.sh        # 推送前隐私自检（路径/凭证/PII/文件名/git 作者）
```

## 📖 协议要点（详见 `SKILL.md`）

### 适用范围

**管**：档案内的一切书写动作（新增/改写/归档/刷新索引）、体例合规、
与记忆库之间的边界判定。
**不管**：机读记忆的读写（走 `shared-agent-memory`）、原始记录（留在原地）、
项目技术事实（不属档案）、公开知识。

### 触发条件

| 你说 | agent 做什么 |
|---|---|
| 「记到个人档案 / 写进档案 / 更新档案」 | 进入写入流程 |
| 「档案里是怎么写的 / 我的档案里有没有」 | 进入读取流程 |
| 「整理 / 复盘 / 归档一下档案」 | 进入维护流程 |
| 只是一次普通任务、没人提档案 | **不动档案**（不主动读、不主动写） |

### 调用方式

- **读取**：解析 ArchiveRoot → 先读 `总索引.md` 定位 → 只读需要的那几篇，不通读全档。
- **写入**：判板块 → 判粒度 → 写 frontmatter → 写正文（守禁令）→ 挂索引 → 回报改了哪几篇。
- **维护**：跑 `doctor.sh` → 按报告修 → 归档而非删除。

### ArchiveRoot 解析（唯一权威）

```
1. 环境变量 PERSONAL_ARCHIVE_ROOT 已设置 → 用它（绝对路径）
2. 否则 → 本 SKILL.md 同目录下的 ./archive
```

⚠️ 不是 CWD；禁止把 ArchiveRoot 硬编码成机器绝对路径。

### 双仓隔离（与 shared-agent-memory 的边界）

1. **互不镜像**：禁止整块搬运、禁止互为副本、禁止用记忆回写档案。
2. **只放行对 agent 有用的内容**（单向、逐条）：三问全过
   （① 会改变 agent 行为？② 不看档案只读这条能正确行动？③ 能否更抽象地表达？），
   且叠加评分卡硬门槛 **可行动性 ≥ 2**。
3. **红线一票否决**：证件号 / 银行卡号 / 完整手机号 / 详细住址 / 凭据；
   与行为无关的私密心事、情感叙述、长篇经历；档案的目录体例。
4. **冲突时以档案为事实来源**；淘汰两仓互不牵连。

## 🩺 体检与门禁

```bash
bash scripts/doctor.sh                      # 体检仓库内模板档案
bash scripts/doctor.sh "<档案目录>"          # 体检指定档案（如你的真档案）
bash scripts/doctor.sh "<档案目录>" --strict  # 有警告也算失败（适合 CI）
```

`doctor.sh` 检查：总索引与板块目录是否就位（板块动态识别）、有无临时残留文件；
frontmatter 闭合与必填字段、`type`/`status` 枚举、日期先后；
各板块编号风格是否混用；正文是否出现机器绝对路径；
是否残留证件号、银行卡号（错误）与完整手机号（警告）；
**板块篇目是否都挂进了 `总索引.md`**；SKILL.md 版本。

## 🛡️ 隐私 & 安全

- 本仓库**只发布空模板与协议**：`.gitignore` 默认忽略 `archive/` 下各板块的全部内容，
  只白名单 `.gitkeep`。你的真档案不会被误提交。
- `scripts/pre-push-check.sh` 在推送前扫描身份 / 绝对路径 / 凭证 / PII / 可疑文件名。
- 本地隐私黑名单放 `scripts/blacklist.local`（已被 `.gitignore` 忽略，只留本机）。

## 📄 License

MIT
