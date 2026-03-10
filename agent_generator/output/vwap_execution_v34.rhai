let initialized = false;
let fomo_triggered = false;
let target_shares = 0;
let shares_bought = 0;
let avg_entry_price = 0;
let volume_history = [];
let price_history = [];
let std_dev_threshold = 0;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        std_dev_threshold = market.price * 10000 / 1000000;
        let max_capital = account.total_equity * 5 / 100;
        let max_shares = max_capital / market.price;
        target_shares = rng.rand_int(1, max_shares);
        lot_size = rng.rand_int(1, target_shares * 10 / 100);
        if lot_size == 0 { lot_size = 1; }
    }
    
    if !market.trading_enabled { return; }
    
    volume_history.push(market.volume);
    if volume_history.len() > 20 {
        volume_history.remove(0);
    }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if market.std_dev > std_dev_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if !fomo_triggered && price_history.len() >= 3 {
        let old_price = price_history[0];
        let price_jump = market.price - old_price;
        let jump_percent = price_jump * 10000 / old_price;
        if jump_percent > 20000 {
            fomo_triggered = true;
            let remaining = target_shares - shares_bought;
            if remaining > 0 {
                orders.submit_market_buy(remaining);
            }
        }
    }
    
    if fomo_triggered { return; }
    
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_side = my_orders.fill_side(i);
        let fill_amount = my_orders.fill_amount(i);
        let fill_price = my_orders.fill_price(i);
        if fill_side == 0 {
            let cost_before = avg_entry_price * shares_bought;
            shares_bought += fill_amount;
            let new_cost = cost_before + fill_price * fill_amount;
            if shares_bought > 0 {
                avg_entry_price = new_cost / shares_bought;
            }
        }
        i += 1;
    }
    
    if shares_bought >= target_shares { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let remaining = target_shares - shares_bought;
    if remaining <= 0 { return; }
    
    let recent_vol = 0;
    if volume_history.len() > 0 {
        recent_vol = arr_mean(volume_history);
    }
    let vol_factor = 100;
    if recent_vol > 0 {
        vol_factor = market.volume * 100 / recent_vol;
        if vol_factor < 50 { vol_factor = 50; }
        if vol_factor > 200 { vol_factor = 200; }
    }
    
    let dynamic_lot = lot_size * vol_factor / 100;
    if dynamic_lot < 1 { dynamic_lot = 1; }
    let order_amount = dynamic_lot;
    if order_amount > remaining {
        order_amount = remaining;
    }
    
    let vwap_price = market.vwap;
    if vwap_price == 0 {
        vwap_price = market.price;
    }
    
    let bid_price = vwap_price * 9995 / 10000;
    if bid_price < 1 { bid_price = 1; }
    
    if order_amount > 0 {
        orders.submit_limit_buy(bid_price, order_amount);
    }
}