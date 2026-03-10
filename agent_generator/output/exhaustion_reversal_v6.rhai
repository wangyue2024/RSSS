let initialized = false;
let lot_size = 0;
let recent_prices = [];
let max_lot_percent = 0;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        max_lot_percent = rng.rand_int(1, 500);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks * 1 / 5 {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > 50_000 {
        return;
    }
    
    if market.tick >= 1 {
        let last_price = market.history_price(0);
        let change_micros = market.price - last_price;
        let change_percent = change_micros * 10000 / last_price;
        if change_percent.abs() > 200 {
            fomo_triggered = true;
        }
    }
    
    if fomo_triggered {
        let cash_to_risk = account.total_equity * max_lot_percent / 10000;
        let shares = cash_to_risk / market.price;
        if shares > 0 {
            orders.submit_market_buy(shares);
        }
        return;
    }
    
    if recent_prices.len() >= 5 {
        recent_prices.remove(0);
    }
    recent_prices.push(market.price);
    
    if lot_size == 0 {
        let cash_to_risk = account.total_equity * max_lot_percent / 10000;
        lot_size = cash_to_risk / market.price;
        if lot_size < 1 {
            lot_size = 1;
        }
    }
    
    let avg_volume = 0;
    if market.history_len() >= 5 {
        let sum = 0;
        for i in 0..5 {
            sum += market.history_volume(i);
        }
        avg_volume = sum / 5;
    }
    
    let volume_threshold = avg_volume * 10 / 100;
    
    if market.high_20 > market.ma_60 && market.volume < volume_threshold && market.volume > 0 {
        orders.submit_market_sell(lot_size);
    }
}