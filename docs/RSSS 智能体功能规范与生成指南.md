# RSSS 智能体功能规范与生成指南 (Agent Functional Spec) v0.8

本规范用于指导 LLM (DeepSeek) 生成高质量、可运行的 Rhai 策略代码。
 **核心原则** ：Agent 拥有完全的决策自由，但必须遵守市场的经济规则（费用、预热期）。

## 1. 角色定义 (Persona)

* **目标** : 最大化 `account.total_equity`。
* **环境** : 单只股票，T+0 交易， **含手续费** 。
* **约束** : 市场存在 **预热期** ，前 N 个 Tick 只能看不能动。部分 Agent 初始持有 **底仓** 。

## 2. 语法与接口调用示例 (Syntax & API Usage Example)

生成的 Rhai 代码必须符合以下结构。

```
// --- [Step 0] 惰性初始化 (Setup / Lazy Init) ---
// 模拟 "setup()" 函数：仅在第一次运行时执行
// 检查 memory 中是否有标志位，如果没有，则进行初始化
if !account.custom_memory.contains("initialized") {
    // [在这里编写你的 Setup 逻辑]
    // 例如：设置初始策略参数、记录初始资产
    account.custom_memory.put("target_pos", 0);
    account.custom_memory.put("risk_factor", 0.5);
  
    // 标记为已初始化
    account.custom_memory.put("initialized", true);
  
    // 初始化阶段通常不直接交易
    return #{ action: Action.Hold, order_type: OrderType.Market, price: 0.0, amount: 0 };
}

// --- [Step 1] 预热期检查 (Warm-up Check) ---
// 如果市场还未开放交易，强制观望
// 这段时间可以用来收集数据或计算更长周期的指标
if !market.trading_enabled {
    return #{ action: Action.Hold, order_type: OrderType.Market, price: 0.0, amount: 0 };
}

// --- [Step 2] 策略逻辑计算 ---
let state = account.custom_memory.get("state") ?? 0;

// 示例：考虑手续费的套利逻辑
// 只有当预期收益 > 手续费 * 2 时才开仓
let expected_profit = (market.price - market.ma_20) / market.price;
let cost_threshold = market.fee_rate * 2.0;

if expected_profit > cost_threshold {
    return #{
        action: Action.Buy,
        order_type: OrderType.Limit,
        price: market.price,
        amount: 100
    };
}

// --- [Step 3] 返回决策 ---
return #{
    action: Action.Hold,
    order_type: OrderType.Market,
    price: 0.0,
    amount: 0
};
```

## 3. 技术限制与系统约束 (Technical Constraints)

1. **禁止无限循环** : 严禁使用 `while(true)`。
2. **计算性能** : 优先使用 `math.*` 原生函数。
3. **内存使用** : 仅存储关键状态。
