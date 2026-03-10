let initialized = false;
let base_spread = 0;
let vol_factor = 0;
let order_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(8000, 12000);
        vol_factor = rng.rand_int(30, 70);
        order_size = rng.rand_int(80, 120);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    } else {
        mid_price = market.price;
    }

    let volatility = market.std_dev;
    let dynamic_spread = base_spread + (volatility * vol_factor) / 1000;

    let raw_bid = mid_price - dynamic_spread / 2;
    let raw_ask = mid_price + dynamic_spread / 2;

    let round_bid = ((raw_bid + 500_000) / 1_000_000) * 1_000_000;
    let round_ask = ((raw_ask + 500_000) / 1_000_000) * 1_000_000;

    if round_bid > 0 && round_bid < round_ask {
        orders.submit_limit_buy(round_bid, order_size);
    }

    if round_ask > 0 {
        orders.submit_limit_sell(round_ask, order_size);
    }
}