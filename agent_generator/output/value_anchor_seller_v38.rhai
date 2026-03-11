let initialized = false;
let my_fair_value = 0;
let my_tick_limit = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let base_value = 100_000_000;
        let random_adj = rng.rand_int(-5, 5);
        my_fair_value = base_value * (100 + random_adj) / 100;
        my_tick_limit = market.total_ticks / 5;
    }

    if !market.trading_enabled || market.tick >= my_tick_limit {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let curr_price = market.price;
    let stock_to_sell = account.stock;

    if curr_price <= my_fair_value || stock_to_sell <= 0 {
        return;
    }

    let sell_amount;
    let price_ratio = curr_price * 100 / my_fair_value;

    if price_ratio > 110 {
        sell_amount = rng.rand_int(80, 120);
    } else if price_ratio > 105 {
        sell_amount = rng.rand_int(20, 40);
    } else {
        return;
    }

    if sell_amount > stock_to_sell {
        sell_amount = stock_to_sell;
    }

    if market.ask_price_0 > 0 {
        orders.submit_limit_sell(market.ask_price_0, sell_amount);
    } else {
        orders.submit_limit_sell(curr_price, sell_amount);
    }
}