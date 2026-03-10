// Global variables persist across ticks
let initialized = false;
let spread_micros = 0;
let order_size = 0;

fn round_to_dollar(price_micros) {
    let half_dollar = 500_000;
    ((price_micros + half_dollar) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(10_000, 50_000);
        order_size = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled {
        return;
    }
    
    // Cancel all existing pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Calculate target prices with round number bias
    let current_price = market.price;
    
    // Buy order: round to nearest dollar below (current - spread)
    let raw_buy_price = current_price - spread_micros;
    let buy_price = round_to_dollar(raw_buy_price);
    
    // Sell order: round to nearest dollar above (current + spread)
    let raw_sell_price = current_price + spread_micros;
    let sell_price = round_to_dollar(raw_sell_price);
    
    // Place orders if valid
    if buy_price > 0 && buy_price < sell_price {
        orders.submit_limit_buy(buy_price, order_size);
        orders.submit_limit_sell(sell_price, order_size);
    }
}