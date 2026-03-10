let initialized = false;
let base_spread = 0;
let inv_skew_factor = 0;
let panic_threshold = 0;
let fixed_order_qty = 0;
let max_inv_abs = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(2000, 8000);
        inv_skew_factor = rng.rand_int(5, 20);
        panic_threshold = -rng.rand_int(50000, 200000);
        fixed_order_qty = rng.rand_int(50, 200);
        max_inv_abs = rng.rand_int(800, 1500);
    }

    if !market.trading_enabled { return; }

    let pnl = account.unrealized_pnl;
    if pnl < panic_threshold {
        let stock = account.stock;
        if stock > 0 {
            orders.submit_market_sell(stock);
        }
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = market.price;
    let inventory = account.stock;
    let inv_clamped = clamp_val(inventory, -max_inv_abs, max_inv_abs);

    let spread_adj = inv_clamped * inv_skew_factor;
    let half_spread = base_spread / 2;

    let buy_offset = half_spread + spread_adj;
    let sell_offset = half_spread - spread_adj;

    let buy_price = mid_price - buy_offset;
    let sell_price = mid_price + sell_offset;

    if buy_price < 1 { buy_price = 1; }
    if sell_price < 1 { sell_price = 1; }

    let cash_avail = account.cash;
    let stock_avail = account.stock;

    let buy_qty = fixed_order_qty;
    let buy_cost = buy_qty * buy_price;
    if buy_cost > cash_avail && cash_avail > 0 {
        buy_qty = cash_avail / buy_price;
        if buy_qty < 1 { buy_qty = 0; }
    }
    if buy_qty > 0 {
        orders.submit_limit_buy(buy_price, buy_qty);
    }

    let sell_qty = fixed_order_qty;
    if sell_qty > stock_avail {
        sell_qty = stock_avail;
    }
    if sell_qty > 0 {
        orders.submit_limit_sell(sell_price, sell_qty);
    }
}