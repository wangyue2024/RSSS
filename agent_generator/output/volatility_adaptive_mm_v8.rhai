let initialized = false;
let base_spread_factor = 0;
let lot_size_factor = 0;
let price_history = [];
let reaction_delay = 5;

fn on_tick() {
    if !initialized {
        base_spread_factor = rng.rand_int(200, 500);
        lot_size_factor = rng.rand_int(30, 50);
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
    if price_history.len() > reaction_delay {
        price_history.remove(0);
    }

    if price_history.len() < reaction_delay {
        return;
    }

    let delayed_price = price_history[0];
    let vol_factor = market.std_dev;
    let spread_micros = base_spread_factor * vol_factor / 100;

    let bid_price = delayed_price - spread_micros / 2;
    let ask_price = delayed_price + spread_micros / 2;

    if bid_price <= 0 || ask_price <= 0 {
        return;
    }

    let cash_to_use = account.cash * lot_size_factor / 100;
    let buy_amount = cash_to_use / bid_price;
    let sell_amount = account.stock * lot_size_factor / 100;

    if buy_amount > 0 {
        orders.submit_limit_buy(bid_price, buy_amount);
    }
    if sell_amount > 0 {
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}