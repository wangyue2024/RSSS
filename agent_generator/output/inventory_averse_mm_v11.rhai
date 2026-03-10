let initialized = false;
let inv_target = 0;
let inv_max = 1000;
let base_spread = 100_000;
let base_size = 100;
let round_factor = 1_000_000;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Optional randomization of parameters
        // inv_max = 500 + rng.rand_int(0, 1000);
        // base_spread = 50_000 + rng.rand_int(0, 150_000);
        // base_size = 50 + rng.rand_int(0, 150);
    }

    if !market.trading_enabled {
        return;
    }

    // Cancel all existing orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let inventory = account.stock;
    // Inventory skew factor: -100 to 100 percent
    let inv_skew = clamp_val((inventory * 100) / inv_max, -100, 100);

    // Determine base mid price from order book
    let mid_price;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    } else {
        mid_price = market.price;
    }

    // Calculate raw spreads with inventory skew
    // Positive inventory -> sell closer (narrower spread), buy farther (wider spread)
    let buy_spread_raw = base_spread * (100 + inv_skew) / 100;
    let sell_spread_raw = base_spread * (100 - inv_skew) / 100;

    // Round to nearest dollar (1,000,000 micros)
    let buy_price_raw = mid_price - buy_spread_raw;
    let sell_price_raw = mid_price + sell_spread_raw;

    let buy_price = ((buy_price_raw + 500_000) / round_factor) * round_factor;
    let sell_price = ((sell_price_raw + 500_000) / round_factor) * round_factor;

    // Diamond hands rule: only sell above average cost
    let avg_cost = account.avg_cost;
    let can_sell = sell_price > avg_cost;

    // Adjust order sizes based on inventory skew
    let buy_size = base_size * (100 - inv_skew) / 100;
    let sell_size = base_size * (100 + inv_skew) / 100;

    // Ensure minimum size of 1
    if buy_size < 1 { buy_size = 1; }
    if sell_size < 1 { sell_size = 1; }

    // Place limit orders if prices are valid (positive)
    if buy_price > 0 && buy_size > 0 {
        orders.submit_limit_buy(buy_price, buy_size);
    }

    if sell_price > 0 && sell_size > 0 && can_sell {
        orders.submit_limit_sell(sell_price, sell_size);
    }
}