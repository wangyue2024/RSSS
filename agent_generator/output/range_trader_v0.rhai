let initialized = false;
let lot_size = 0;
let delayed_prices = [];
let current_tick_store = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        let capital_5percent = account.total_equity * 5 / 100;
        let max_shares = capital_5percent / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
    }
    
    current_tick_store = market.tick;
    delayed_prices.push(market.price);
    if delayed_prices.len() > 5 {
        delayed_prices.remove(0);
    }
    
    if market.std_dev > market.price * 5 / 100 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if delayed_prices.len() < 5 { return; }
    let delayed_price = delayed_prices[0];
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let range_spread = market.high_20 - market.low_20;
    let current_position_size = abs_val(account.stock);
    let max_allowed = account.total_equity * 5 / 100 / market.price;
    
    if max_allowed < 1 { return; }
    
    let spread_factor = 1000000;
    if range_spread > 0 {
        spread_factor = (range_spread * 1000000) / market.price;
    }
    
    let adjusted_lot = lot_size;
    if spread_factor < 10000 {
        adjusted_lot = lot_size * 2;
    }
    if adjusted_lot > max_allowed {
        adjusted_lot = max_allowed;
    }
    if adjusted_lot < 1 {
        adjusted_lot = 1;
    }
    
    let buy_price = market.low_20 + 1;
    let sell_price = market.high_20;
    
    if delayed_price <= market.low_20 + range_spread * 10 / 100 {
        orders.submit_limit_buy(buy_price, adjusted_lot);
    }
    
    if delayed_price >= market.high_20 - range_spread * 10 / 100 {
        orders.submit_limit_sell(sell_price, adjusted_lot);
    }
}