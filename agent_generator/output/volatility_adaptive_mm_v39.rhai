let initialized = false;
let lot_size = 0;
let max_volatility_threshold = 0;
let spread_multiplier_base = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        let percent_capital = rng.rand_int(1, 5);
        let capital_for_stock = account.total_equity * percent_capital / 100;
        if market.price > 0 {
            lot_size = capital_for_stock / market.price;
            if lot_size < 1 { lot_size = 1; }
        } else {
            lot_size = 100;
        }
        
        max_volatility_threshold = rng.rand_int(300000, 500000);
        spread_multiplier_base = rng.rand_int(2000, 5000);
        initialized = true;
    }
    
    if market.tick % 50 != 0 { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > max_volatility_threshold { return; }
    
    let current_price = market.price;
    if current_price == 0 { return; }
    
    let volatility_factor = market.std_dev * 10000 / current_price;
    let spread_multiplier = spread_multiplier_base + volatility_factor;
    
    let buy_price = current_price - (spread_multiplier * current_price) / 1000000;
    let sell_price = current_price + (spread_multiplier * current_price) / 1000000;
    
    if buy_price > 0 && account.cash >= buy_price * lot_size {
        orders.submit_limit_buy(buy_price, lot_size);
    }
    
    if account.stock >= lot_size {
        orders.submit_limit_sell(sell_price, lot_size);
    }
}