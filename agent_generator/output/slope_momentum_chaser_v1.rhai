let initialized = false;
let panic_threshold = 0;
let lookback = 20;
let max_order_age = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(5_000, 20_000);
        lookback = 20;
        max_order_age = 3;
    }

    if !market.trading_enabled { return; }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > max_order_age {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let hist_len = market.history_len();
    if hist_len < lookback { return; }

    let prices = [];
    let idx = 0;
    while idx < lookback {
        prices.push(market.history_price(idx));
        idx += 1;
    }

    let current_slope = arr_slope(prices);
    if current_slope > 1_000 {
        let buy_amount = account.cash * 30 / (100 * market.price);
        if buy_amount > 0 {
            let bid_price = market.bid_price_0;
            if bid_price > 0 {
                orders.submit_limit_buy(bid_price, buy_amount);
            }
        }
    } else if current_slope < -500 && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }
}