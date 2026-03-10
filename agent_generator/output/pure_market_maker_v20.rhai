let initialized = false;
let volatility_threshold = 0;
let lot_size = 0;
let target_spread_micros = 0;
let max_position = 0;

fn round_to_nearest_dollar(price_micros) {
    let remainder = price_micros % 1_000_000;
    if remainder >= 500_000 {
        price_micros - remainder + 1_000_000
    } else {
        price_micros - remainder
    }
}

fn on_tick() {
    if !initialized {
        volatility_threshold = rng.rand_int(50_000, 200_000);
        let equity_percent = rng.rand_int(10, 50);
        lot_size = (account.total_equity * equity_percent) / (100 * market.price);
        if lot_size < 1 { lot_size = 1; }
        target_spread_micros = rng.rand_int(20_000, 100_000);
        max_position = lot_size * 5;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > volatility_threshold { return; }
    if abs_val(account.stock) >= max_position { return; }
    
    let mid_price = market.price;
    let buy_price_raw = mid_price - target_spread_micros;
    let sell_price_raw = mid_price + target_spread_micros;
    
    let buy_price = round_to_nearest_dollar(buy_price_raw);
    let sell_price = round_to_nearest_dollar(sell_price_raw);
    
    if buy_price > 0 && account.stock < max_position {
        orders.submit_limit_buy(buy_price, lot_size);
    }
    if sell_price > 0 && account.stock > -max_position {
        orders.submit_limit_sell(sell_price, lot_size);
    }
}