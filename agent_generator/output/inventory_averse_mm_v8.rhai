let initialized = false;
let base_spread = 0;
let lot_size = 0;
let max_inventory = 1000;
let inv_target = 0;
let std_dev_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let equity_shares = account.total_equity / market.price;
        let five_pct_shares = equity_shares * 5 / 100;
        if five_pct_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, five_pct_shares);
        }
        base_spread = rng.rand_int(500, 2000);
        std_dev_threshold = rng.rand_int(20000, 50000);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.std_dev > std_dev_threshold {
        return;
    }

    let mid_price = market.price;
    let inventory = account.stock;
    let inv_diff = inventory - inv_target;

    let spread_adj = inv_diff * base_spread / max_inventory;
    let buy_spread = base_spread + spread_adj;
    let sell_spread = base_spread - spread_adj;

    if buy_spread < 100 { buy_spread = 100; }
    if sell_spread < 100 { sell_spread = 100; }

    let buy_price = mid_price - buy_spread;
    let sell_price = mid_price + sell_spread;

    if buy_price > 0 {
        orders.submit_limit_buy(buy_price, lot_size);
    }

    if sell_price > account.avg_cost && account.stock >= lot_size {
        orders.submit_limit_sell(sell_price, lot_size);
    }
}