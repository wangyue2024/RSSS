let initialized = false;
let price_history = [];
let high_20_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_history.push(market.price);
    high_20_history.push(market.high_20);

    if price_history.len() > 5 {
        price_history.remove(0);
        high_20_history.remove(0);
    }

    if market.tick >= market.total_ticks / 5 {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if price_history.len() < 5 { return; }

    let delayed_price = price_history[0];
    let delayed_high_20 = high_20_history[0];

    if account.stock == 0 && delayed_price > delayed_high_20 {
        let buy_amount = account.cash / (2 * market.price);
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }

    if account.stock > 0 {
        let stop_offset = market.price * 5 / 10000;
        let stop_price = account.avg_cost - stop_offset;
        if stop_price > 0 {
            orders.submit_limit_sell(stop_price, account.stock);
        }
    }
}