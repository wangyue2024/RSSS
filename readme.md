# RSSS — Rust Stock Simulation System

RSSS 是一个基于纯 Rust 构建的极高性能、微观结构驱动的**计算金融框架**。基于混合运行时（Rust + Rhai 脚本）架构，实现在单机节点下，对上千个 AI（如 LLM 生成的策略代码）实施毫秒级、免锁（Lock-Free）、极小延迟（Zero-Copy）的高频撮合量化回测。

##  核心架构亮点

- **混合运行时 (Hybrid Runtime)**：撮合、清算、多线程调度完全由 Host 端 (Rust) 处理；轻量级的交易逻辑策略由 Guest 端 (Rhai) 在严格的沙箱隔离下动态解释执行。
- **确定性与随机乱序模拟**：采用 Fisher-Yates 同步 Shuffle 技术。Agent 的下单请求到达主机后会被随机“打乱”后进入盘口，以数学概率模拟真实世界由于物理网络拓扑导致的“排队滑点(Slippage)”。配合Seedable固定种子实现比特级回测结果复现 (Bit-wise Reproducible)。
- **金融级定点数 (Zero Float)**：拒绝任何 `f64`。整个市场内数据，包括计算因子全都按 $10^6$ (Micros) 表示的 `i64` 流转。
- **影子撤单机制 (Shadow Cancellation)**：系统 OrderBook 底层为 `BTreeMap`+`VecDeque` 混合结构。辅加 `HashMap` 倒排索引，将从百万级订单阵列中执行“查询并撤单”的过程时间复杂度极致优化至 **O(1)**。
- **并发状态免拷贝零开销**：行情 `MarketState` 作为全局单例包裹在 `Arc` 下。每一次 Tick 更新后分发给上千个 Agent，无堆拷贝负担。

##  源码目录导读

所有核心组件高度解耦且边界清晰，汇聚在 `src` 目录下：

| 模块 / 文件 | 职能定义 |
| :--- | :--- |
| **`main.rs` / `lib.rs`** | CLI 应用入口。负责解析参数、调度多线程（仿真主线程、UI渲染线程、后台异步落地IO线程）。 |
| **`domain/`** | 顶层只依赖标准库的最原子数据抽象层。定义紧密内存对齐的 32 Byte `Order` 实休，核心 `Price` 和 `Vol` NewType 封装。及其防溢出金融运算底层接口。 |
| **`engine/`** | **核心撮合黑盒**。仅收单和抛事件。以价格优先、时间优先为绝对准则。不碰资金处理，内部执行复杂而高效的“队列维护”及“防对敲”剔除。 |
| **`scripting/`** | Rust 算力底座与动态脚本语言的数据通讯协议桥接。定义注入沙盒中的 API `MarketState` 和 `AccountView`。暴露原生 C 性能级别的数组测速模块 `math.rs` 供脚本调用。 |
| **`simulation/`** | **推演环境层（上帝视角）**。`world.rs` 负责宏大的主流程控制(Tick生命周期)。通过 Rayon 并行唤醒 Agents 计算，采集结果完成洗牌，并通过 `settlement.rs` （结算模块）对事件执行严谨的资金与持卡解冻/扣压核算。|
| **`record/`** | IO 黑匣子。通过异步信道隔离主架构，使用 `BufWriter` 将海量成交明细全量导出，不阻塞运算节律。 |
| **`tui/`** | 命令行炫酷控制台界面。依靠 `Crossterm` / `ratatui`。独立频率渲染 L2 行情、K线快照及百名高频交易员资产 PnL 前列榜单。 |

##  编译与运行指南

### 环境依赖
- 安装最新稳定的 Rust 工具链 (edition 2021) 至少 Rust 1.70+

### 基本运行模式

编译并在 release 下运行（高频仿真系统**极度推荐使用 `--release` 参数**获取最大性能）：

```bash
cargo run --release
cargo run --release -- --ticks 10000 --cash 10000 --stock 100
```

系统会自动拉取项目根目录下 `agent_generator/output/` 内所有扩展名为 `.rhai` 的脚本。

### 核心可选参数 (`--help` 查看全部)

| 参数项 | 说明 | 默认值 |
| :--- | :--- | :--- |
| `[SCRIPT PATH]` | 不加 `--` 的第一参数视作目标脚本存放路径。 | `agent_generator\output` |
| `--agents N` | 并行跑动多少个实体 Agent (自动复数分配目标目录下的脚本) | 1000 |
| `--ticks N` | 仿真持续的总体帧数 | 10000 |
| `--seed N` | 计算一致性的绝对源头基础种子 | 42 |
| `--warmup N` | 屏蔽交易指令的“开盘前算子准备期”时钟长 | 100 |
| `--fee N` | 双边撮合税，基点万分（bps）。如 `3` 为万三 | 3 |
| `--no-tui` | 启用脱机极速运算后台模式 (极大提高单机跑测 TPS) | `false` |
| `--validate F` | 测试单点脚本生命周期或批量文件夹沙盒安全试跑 | 无 |

### TUI 界面
启动后将看到终端绘图 (TUI开启时)：
- 左侧涵盖当前的 L2 Snapshot。
- 右侧为 Agent 的净资产波动排名。
- 输入 `q` 退出进程。 

##  Rhai 策略开发说明

脚本层拥有对独立作用域（Scope）内存修改的天然继承性能力。全局无需建立外部存储，直接利用顶层变量编写初始化常态变量：

```rhai
// 这部分（外层）仅在系统刚启动向 Agent 植入环境时运行一次
let start_pos = account.stock;
let risk_tolerance = 20_000;  // 2% 定义为止损微元单位

// 此函数是仿真体系的回调接入核心。引擎每次 Tick 唤醒必须。
fn on_tick() {
    // 1. 安全合规：度过预热禁令期
    if !market.trading_enabled { return; }

    // 2. 态势计算 (纯整数计算)
    let spread = market.vwap - market.price;
    let threshold = market.price * market.fee_rate_bps * 10 / 100_000;
    
    // 3. 多分支开单挂起决策
    if spread > threshold {
        // 利用 Rust 注入的高速邮箱对象落单 
        // buy: (价格 micros, 容量) -> 返回该次生成的订单临时ID (并非绝对最终ID)
        let buy_id = orders.submit_limit_buy(market.price, 25);
    }
}
```
**注意：** 因为没有小数点，务必留意基准价格微差比的等式扩大和向下截断效应。
