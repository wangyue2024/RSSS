let initialized = false;
let lot_size = 0;
let last_bid_price = 0;
let last_ask_price = 0;
let std_dev_threshold = 150_000;
let base_spread = 20_000;
let max_position = 0;

fn round_to_dollar(price) {
    let rounded = ((price + 500_000) / 1_000_000) * 1_000_000;
    return rounded;
}

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_cap = account.total_equity * 5 / 100;
        let price = market.price;
        if price > 0 {
            let shares = risk_cap / price;
            lot_size = clamp_val(shares, 100, 10000);
        } else {
            lot_size = 100;
        }
        max_position = lot_size * 10;
    }
    
    if !market.trading_enabled { return; }
    
    if market.std_dev > std_dev_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    let imbalance = market.order_imbalance;
    let mid_price = market.price;
    
    let imbalance_shift = 0;
    if imbalance > 100 {
        imbalance_shift = 50_000;
    } else if imbalance > 50 {
        imbalance_shift = 25_000;
    } else if imbalance < -100 {
        imbalance_shift = -50_000;
    } else if imbalance < -50 {
        imbalance_shift = -25_000;
    }
    
    let bid_offset = -base_spread + imbalance_shift;
    let ask_offset = base_spread + imbalance_shift;
    
    let raw_bid = mid_price + bid_offset;
    let raw_ask = mid_price + ask_offset;
    
    let bid_price = round_to_dollar(raw_bid);
    let ask_price = round_to_dollar(raw_ask);
    
    if bid_price >= ask_price {
        ask_price = bid_price + 1_000_000;
    }
    
    if bid_price <= 0 || ask_price <= 0 {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if bid_price != last_bid_price && account.cash >= bid_price * lot_size {
        let position_limit_ok = account.stock < max_position;
        if position_limit_ok {
            orders.submit_limit_buy(bid_price, lot_size);
            last_bid_price = bid_price;
        }
    }
    
    if ask_price != last_ask_price && account.stock >= lot_size {
        let position_limit_ok = account.stock > -max_position;
        if position_limit_ok {
            orders.submit_limit_sell(ask_price, lot_size);
            last_ask_price = ask_price;
        }
    }
}