let initialized = false;
let personality = 0;
let lot_size_pct = 0;
let lookback = 10;
let prev_slope = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        personality = rng.rand_int(0, 1);
        if personality == 0 {
            lot_size_pct = rng.rand_int(1, 5);
        } else {
            lot_size_pct = rng.rand_int(30, 50);
        }
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if personality == 0 && market.std_dev > market.price * 20 / 1000 {
        return;
    }
    
    if market.history_len() < lookback {
        return;
    }
    
    let prices = [];
    let j = 0;
    while j < lookback {
        prices.push(market.history_price(market.history_len() - lookback + j));
        j += 1;
    }
    
    let current_slope = arr_slope(prices);
    
    let cash_to_use = account.cash * lot_size_pct / 100;
    let buy_amount = cash_to_use / market.price;
    let sell_amount = account.stock * lot_size_pct / 100;
    
    if current_slope > 50000 && current_slope > prev_slope * 3 / 2 && buy_amount > 0 {
        let raw_price = market.ask_price_0;
        if raw_price == 0 { raw_price = market.price; }
        let round_price = (raw_price + 500000) / 1000000 * 1000000;
        orders.submit_limit_buy(round_price, buy_amount);
    } else if current_slope < -20000 && prev_slope > 0 && sell_amount > 0 {
        let raw_price = market.bid_price_0;
        if raw_price == 0 { raw_price = market.price; }
        let round_price = (raw_price + 500000) / 1000000 * 1000000;
        orders.submit_limit_sell(round_price, sell_amount);
    }
    
    prev_slope = current_slope;
}