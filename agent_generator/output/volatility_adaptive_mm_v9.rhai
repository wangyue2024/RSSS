let initialized = false;
let base_spread_bps = 20;
let volatility_factor = 5;
let order_size = 100;
let last_action_tick = -50;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread_bps = rng.rand_int(15, 30);
        volatility_factor = rng.rand_int(4, 8);
        order_size = rng.rand_int(80, 120);
    }

    if !market.trading_enabled { return; }

    let tick = market.tick;
    if tick - last_action_tick < 50 { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let volatility = market.std_dev;
    let spread_bps = base_spread_bps + (volatility_factor * volatility) / 100_000;
    let half_spread = (mid_price * spread_bps) / 10000;

    let raw_bid = mid_price - half_spread;
    let raw_ask = mid_price + half_spread;

    let round_to = 1_000_000;
    let bid_price = ((raw_bid + round_to / 2) / round_to) * round_to;
    let ask_price = ((raw_ask + round_to / 2) / round_to) * round_to;

    let max_buy_amount = account.cash / ask_price;
    let actual_buy = if order_size < max_buy_amount { order_size } else { max_buy_amount };
    if actual_buy > 0 && ask_price > 0 {
        orders.submit_limit_buy(ask_price, actual_buy);
    }

    let max_sell_amount = account.stock;
    let actual_sell = if order_size < max_sell_amount { order_size } else { max_sell_amount };
    if actual_sell > 0 {
        orders.submit_limit_sell(bid_price, actual_sell);
    }

    last_action_tick = tick;
}