let initialized = false;
let recent_prices = [];
let last_slope = 0;
let lot_size = 100;
let prev_realized_pnl = 0;
let trade_history = [];
let losing_streak = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    recent_prices.push(market.price);
    if recent_prices.len() > 15 {
        recent_prices.remove(0);
    }
    
    let current_realized = account.realized_pnl;
    let realized_change = current_realized - prev_realized_pnl;
    prev_realized_pnl = current_realized;
    
    if realized_change < 0 {
        losing_streak += 1;
        lot_size = lot_size * 2;
        lot_size = clamp_val(lot_size, 50, 5000);
    } else {
        losing_streak = 0;
        lot_size = 100;
    }
    
    if recent_prices.len() < 15 {
        return;
    }
    
    let delayed_window = [];
    let j = 0;
    while j < 10 {
        delayed_window.push(recent_prices[j]);
        j += 1;
    }
    
    if delayed_window.len() < 10 {
        return;
    }
    
    let slope = arr_slope(delayed_window);
    
    if slope > 5000 && slope > last_slope && account.cash > 5000000 {
        let buy_amount = lot_size;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    } else if slope < -3000 && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }
    
    last_slope = slope;
}