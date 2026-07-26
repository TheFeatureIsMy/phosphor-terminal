# web3-aesthetic-systems

一个可移植的 Claude skill：六套完整、production-ready 的 Web3 / crypto / fintech 视觉美学系统，用于 dashboard、交易终端、数据密集型产品 UI、DeFi 应用。

每套都是一门完整的设计语言（配色 / 字体 / 布局 DNA / signature / 动效 / 图标 / 何时用 / 禁忌），锚定一个真实产品血统，绝非「换个颜色」。

## 六套一览

| # | 系统 | 血统 | 主色 | 适合 |
|---|---|---|---|---|
| ① | LEDGER 链上账本 | Etherscan | `#2FBF71` | 记录 / 日志 / 交易流 / 信号流 |
| ② | DEPTH 深度驾驶舱 | Bloomberg / dYdX | `#F5A623` | 交易终端 / 密集数据 / 订单簿 |
| ③ | PROTOCOL 机构 DeFi | Uniswap / Base | `#3D5AFE` | 消费级 DeFi / 引导 / 组合（唯一浅色） |
| ④ | SPATIAL 策略星图 | 节点图谱 / React Flow | `#5CE6A8` | 拓扑 / 关系 / Agent·信号图谱 |
| ⑤ | BRUTALIST 生猛 | Blur / Blast | `#E5FF00` | 告警 / 发射 / memecoin / 强注意力 |
| ⑥ | RWA 机构衬线 | Ondo / Ethena | `#C9A86A` | 资产报告 / 机构 / 面向 LP |

## 文件结构

```
web3-aesthetic-systems/
├── SKILL.md                    # 主手册（12 节：选择器/六套规格/SwiftUI 移植/主题切换/质量底线/反 AI 味）
├── tokens.json                 # 机器可读 token（精确 hex/字体/圆角/禁忌），agent 可直接读取
└── references/
    └── examples/               # 7 个自包含 HTML 参考实现
        ├── 01-ledger.html      # 每套一张完整 dashboard
        ├── 02-depth.html
        ├── 03-protocol.html
        ├── 04-spatial.html
        ├── 05-brutalist.html
        ├── 06-rwa.html
        └── theme-switcher.html # 主题实时切换演示（一套布局切 5 套 token）
```

## 如何安装到别的项目

把整个 `web3-aesthetic-systems/` 文件夹拷到目标项目的 skill 目录即可，二选一：
- Claude Code / 项目级：`<项目>/.claude/skills/web3-aesthetic-systems/`
- 用户级（跨项目共享）：`~/.claude/skills/web3-aesthetic-systems/`

拷完即用，无外部依赖。examples 里的 HTML 用 Google Fonts CDN，双击即可在浏览器打开。

## 特别之处

- **跨框架**：SKILL.md §8 有完整的 web→SwiftUI 移植地图，同一套系统能在网页和 Apple 平台落地。
- **可做主题切换**：§9 讲清 token 层（可实时切）vs 结构层（换不出来）的边界，附最小 token 契约。
- **反 AI 味**：§11 明确禁掉紫色渐变、mesh、玻璃滥用、同布局换色等常见 AI 生成痕迹。
