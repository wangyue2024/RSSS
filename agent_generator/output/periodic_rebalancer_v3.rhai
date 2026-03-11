let initialized = false;
let tick_counter = 0;
let offset = 500_000;
let rebalance_interval = 10;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }
    if market.tick * 5 >= market.total_ticks { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    tick_counter += 1;
    if tick_counter < rebalance_interval { return; }
    tick_counter = 0;

    let stock_value = account.stock * market.price;
    let total_eq = account.total_equity;
    if total_eq == 0 { return; }

    let stock_ratio = (stock_value * 100) / total_eq;

    if stock_ratio > 55 {
        let target_stock_value = (total_eq * 50) / 100;
        let excess_value = stock_value - target_stock_value;
        if excess_value <= 0 { return; }
        let sell_amount = excess_value / market.price;
        if sell_amount <= 0 { return; }
        let sell_price = market.price - offset;
        if sell_price <= 0 { return; }
        orders.submit_limit_sell(sell_price, sell_amount);
    }

    if stock_ratio < 45 {
        let target_stock_value = (total_eq * 50) / 100;
        let deficit_value = target_stock_value - stock_value;
        if deficit_value <= 0 { return; }
        let buy_amount = deficit_value / market.price;
        if buy_amount <= 0 { return; }
        let max_buy_amount = account.cash / market.price;
        if buy_amount > max_buy_amount {
            buy_amount = max_buy_amount;
        }
        if buy_amount <= 0 { return; }
        let buy_price = market.price + offset;
        orders.submit_limit_buy(buy_price, buy_amount);
    }
}