let initialized = false;
let delayed_price = 0;
let delayed_tick = 0;
let spread_micros = 50_000;
let order_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        return;
    }

    if !market.trading_enabled {
        return;
    }

    if market.tick >= delayed_tick + 5 {
        delayed_price = market.price;
        delayed_tick = market.tick;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if delayed_price > 0 && delayed_tick > 0 {
        let buy_price = delayed_price - spread_micros;
        let sell_price = delayed_price + spread_micros;
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price, order_amount);
        }
        orders.submit_limit_sell(sell_price, order_amount);
    }
}