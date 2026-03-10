let initialized = false;
let lot_size = 0;
let base_spread = 300000;
let inventory_threshold = 1000;
let max_std_dev = 1500000;
let tick_counter = 0;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        price - remainder + 1_000_000
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !initialized {
        let max_shares = account.total_equity * 5 / 100 / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
        initialized = true;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    tick_counter += 1;
    if tick_counter % 50 != 0 {
        return;
    }
    
    if market.std_dev > max_std_dev {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let inventory = account.stock;
    
    let spread_adjust = 0;
    if inventory > inventory_threshold {
        spread_adjust = 100000;
    } else if inventory <= 0 {
        spread_adjust = -100000;
    }
    
    let buy_price_raw = mid_price - base_spread - spread_adjust;
    let sell_price_raw = mid_price + base_spread - spread_adjust;
    
    let buy_price = round_to_dollar(buy_price_raw);
    let sell_price = round_to_dollar(sell_price_raw);
    
    if buy_price < sell_price && buy_price > 0 {
        let cash_needed = buy_price * lot_size;
        if cash_needed <= account.cash {
            orders.submit_limit_buy(buy_price, lot_size);
        }
        
        if account.stock >= lot_size {
            orders.submit_limit_sell(sell_price, lot_size);
        }
    }
}