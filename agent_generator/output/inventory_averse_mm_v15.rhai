let initialized = false;
let base_spread = 0;
let base_order_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(2000, 8000);
        base_order_size = rng.rand_int(50, 200);
    }

    if !market.trading_enabled { return; }

    if market.tick % 50 != 0 { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.bid_price_0 == 0 || market.ask_price_0 == 0 { return; }

    let mid = (market.bid_price_0 + market.ask_price_0) / 2;
    let inv = account.stock;
    let avg = account.avg_cost;

    let bid_offset;
    let ask_offset;

    if inv > 1000 {
        bid_offset = -base_spread * 3 / 2;
        ask_offset = -base_spread / 2;
    } else if inv <= 0 {
        bid_offset = base_spread / 2;
        ask_offset = base_spread * 3 / 2;
    } else {
        bid_offset = -base_spread / 2;
        ask_offset = base_spread / 2;
    }

    let bid_price_raw = mid + bid_offset;
    let ask_price_raw = mid + ask_offset;

    let final_bid_price = bid_price_raw + 1;
    let final_ask_price = ask_price_raw;

    if final_bid_price > 0 {
        orders.submit_limit_buy(final_bid_price, base_order_size);
    }

    if final_ask_price > avg && final_ask_price > 0 {
        orders.submit_limit_sell(final_ask_price, base_order_size);
    }
}