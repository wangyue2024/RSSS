let initialized = false;
let price_history = [];
let morning_ticks = 0;
let sell_cooldown = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        morning_ticks = market.total_ticks / 5;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    if current_tick >= morning_ticks { return; }
    
    if sell_cooldown > 0 {
        sell_cooldown -= 1;
    }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() < 5 { return; }
    
    let delayed_price = price_history[0];
    let delayed_volume = market.history_volume(current_tick - 5);
    
    let avg_volume = {
        if current_tick > 25 {
            let sum = 0;
            for i in 0..20 {
                sum += market.history_volume(current_tick - 5 - i);
            }
            sum / 20
        } else {
            1_000_000
        }
    };
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let near_zero_volume = delayed_volume * 100 < avg_volume;
    let price_above_ma = delayed_price > market.ma_60;
    
    if price_above_ma && near_zero_volume && sell_cooldown == 0 {
        if account.stock > 0 && market.price > account.avg_cost {
            let sell_amount = account.stock * 10 / 100;
            if sell_amount > 0 {
                orders.submit_limit_sell(market.price, sell_amount);
                sell_cooldown = 5;
            }
        }
    }
}