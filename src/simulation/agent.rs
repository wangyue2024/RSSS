//! Agent 运行时状态与生命周期管理

use std::sync::Arc;

use rhai::{Scope, AST};

use crate::scripting::api::{AccountView, ActionMailbox, AgentAction, AgentOrderBook};
use crate::scripting::rng::AgentRng;

/// Agent 运行时状态
///
/// 包含经济状态 (cash/stock)、Rhai 运行时 (AST/Scope/RNG)、订单跟踪。
pub struct AgentState {
    pub id: u32,

    // — 经济状态 —
    pub cash: i64,
    pub stock: i64,
    pub locked_cash: i64,  // 挂单冻结的资金 (微元)
    pub locked_stock: i64, // 挂单冻结的股票量
    pub total_cost: i64,   // 累计买入成本 (微元)
    pub realized_pnl: i64,

    // — Rhai 运行时 —
    pub ast: Arc<AST>,
    pub scope: Scope<'static>,
    pub rng: AgentRng,
    pub initialized: bool,

    // — 订单跟踪 —
    pub order_book: Arc<AgentOrderBook>,
}

impl AgentState {
    /// 创建新 Agent
    pub fn new(
        id: u32,
        ast: Arc<AST>,
        global_seed: u64,
        initial_cash: i64,
        initial_stock: i64,
    ) -> Self {
        Self {
            id,
            cash: initial_cash,
            stock: initial_stock,
            locked_cash: 0,
            locked_stock: 0,
            total_cost: 0,
            realized_pnl: 0,
            ast,
            scope: Scope::new(),
            rng: AgentRng::new(global_seed, id),
            initialized: false,
            order_book: Arc::new(AgentOrderBook::default()),
        }
    }

    /// 计算当前持仓均价 (微元), 无持仓返回 0
    pub fn avg_cost(&self) -> i64 {
        if self.stock > 0 {
            self.total_cost / self.stock
        } else {
            0
        }
    }

    /// 构建只读账户快照
    pub fn build_account_view(&self, market_price: i64) -> AccountView {
        let avg = self.avg_cost();
        AccountView {
            cash: self.cash,
            stock: self.stock,
            total_equity: self.cash + self.stock * market_price,
            avg_cost: avg,
            unrealized_pnl: if self.stock > 0 {
                self.stock * (market_price - avg)
            } else {
                0
            },
            realized_pnl: self.realized_pnl,
        }
    }

    /// 执行一个 Tick 的脚本调用
    pub fn run_tick(
        &mut self,
        engine: &rhai::Engine,
        market: Arc<crate::scripting::api::MarketState>,
    ) {
        let account = self.build_account_view(market.price);

        // 注入只读数据
        self.scope.set_value("market", market);
        self.scope.set_value("account", account);
        self.scope
            .set_value("my_orders", Arc::clone(&self.order_book));
        self.scope.set_value("orders", ActionMailbox::new(self.id));

        // 首次: 执行顶层代码 + 注入 RNG
        if !self.initialized {
            self.scope.push("rng", self.rng.clone());
            let _ = engine.run_ast_with_scope(&mut self.scope, &self.ast);
            self.initialized = true;
        }

        // 执行 on_tick (用 Dynamic 接收任意返回值)
        if let Err(e) = engine.call_fn::<rhai::Dynamic>(&mut self.scope, &self.ast, "on_tick", ()) {
            eprintln!("Agent {} script error: {}", self.id, e);
        }

        // 修复：断开 Rhai Scope 对 my_orders (Arc<AgentOrderBook>) 的持有
        // 防止后续在 Phase 5 落单或成交时，Arc::make_mut 触发灾难性的 O(N) 深拷贝克隆 (保留 pending/history)
        self.scope.set_value("my_orders", ());

        // 回收 RNG 状态
        if let Some(rng) = self.scope.get_value::<AgentRng>("rng") {
            self.rng = rng;
        }
    }

    /// 取回本 Tick 的 actions
    pub fn take_actions(&mut self) -> Vec<AgentAction> {
        self.scope
            .get_value::<ActionMailbox>("orders")
            .map(|m| m.actions)
            .unwrap_or_default()
    }
}
