let initialized = false;
let base_lot = 100;
let current_lot = base_lot;
let last_trade_loss = false;
let prev_price = 0;
let price_window = [];
let fomo_triggered = false;
let fomo_cooldown = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(80, 120);
        current_lot = base_lot;
        prev_price = market.price;
        price_window.push(prev_price);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    price_window.push(market.price);
    if price_window.len() > 5 {
        price_window.remove(0);
    }
    
    let jump_check = false;
    if price_window.len() == 5 {
        let old_price = price_window[0];
        if old_price > 0 {
            let change = ((market.price - old_price) * 100_000_000) / old_price;
            if change > 2_000_000 || change < -2_000_000 {
                jump_check = true;
            }
        }
    }
    
    if jump_check && !fomo_triggered && fomo_cooldown == 0 {
        fomo_triggered = true;
        fomo_cooldown = 20;
    }
    
    if fomo_cooldown > 0 {
        fomo_cooldown -= 1;
    }
    
    if fomo_triggered {
        fomo_triggered = false;
        if account.cash > market.price * current_lot {
            orders.submit_market_buy(current_lot);
        }
        return;
    }
    
    let vwap = market.vwap;
    let price = market.price;
    
    if vwap == 0 {
        return;
    }
    
    let vwap_diff = ((price - vwap) * 100_000_000) / vwap;
    
    if account.stock == 0 {
        if last_trade_loss {
            current_lot = current_lot * 2;
            if current_lot > base_lot * 8 {
                current_lot = base_lot * 8;
            }
            last_trade_loss = false;
        } else {
            current_lot = base_lot;
        }
        
        if vwap_diff < -500_000 && account.cash > price * current_lot {
            orders.submit_limit_buy(price, current_lot);
        }
    } else {
        let avg = account.avg_cost;
        if avg > 0 && price < avg {
            last_trade_loss = true;
        }
        
        if vwap_diff >= 100_000 {
            orders.submit_limit_sell(price, account.stock);
        }
    }
    
    prev_price = price;
}