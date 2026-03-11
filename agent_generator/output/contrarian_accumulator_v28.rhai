let initialized = false;
let last_decision_tick = 0;
let delayed_price = 0;
let delayed_rsi = 0;
let price_buffer = [];
let rsi_buffer = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        last_decision_tick = market.tick;
    }

    if !market.trading_enabled { return; }

    price_buffer.push(market.price);
    rsi_buffer.push(market.rsi_14);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
        rsi_buffer.remove(0);
    }

    if price_buffer.len() == 5 {
        delayed_price = price_buffer[0];
        delayed_rsi = rsi_buffer[0];
    }

    if (market.tick - last_decision_tick) < 50 { return; }

    last_decision_tick = market.tick;

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if delayed_rsi < 3000 {
        let buy_price = delayed_price * 995 / 1000;
        let buy_amount = rng.rand_int(20, 100);
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }

    if delayed_rsi > 7000 && account.stock > 0 {
        let sell_price = delayed_price * 1005 / 1000;
        let sell_amount = rng.rand_int(20, 100);
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}