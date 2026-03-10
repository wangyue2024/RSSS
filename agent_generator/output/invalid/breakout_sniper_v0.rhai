let initialized = false;
let panic_threshold = 0;
let stop_offset = 0;
let price_buffer = [];
let high_buffer = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = rng.rand_int(-30_000, -10_000);
        stop_offset = rng.rand_int(5_000, 15_000);
    }

    if !market.trading_enabled { return; }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if account.stock > 0 {
        let stop_price = account.avg_cost - stop_offset;
        if market.price < stop_price {
            orders.submit_market_sell(account.stock);
            return;
        }
    }

    price_buffer.push(market.price);
    high_buffer.push(market.high_20);
    if price_buffer.len() > 5 {
        price_buffer.remove_at(0);
        high_buffer.remove_at(0);
    }

    if price_buffer.len() == 5) {
        let old_price = price_buffer[0];
        let old_high = high_buffer[0];
        if old_price > old_high && account.stock == 0) {
            let buy_amount = (account.cash * 70 / 100) / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    }
}