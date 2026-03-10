let initialized = false;
let price_history = [];
let volume_history = [];
let last_trade_was_loss = false;
let base_lot_size = 1000;
let current_lot_size = 1000;
let delayed_ticks = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_history.push(market.price);
    volume_history.push(market.volume);
    
    if price_history.len() > delayed_ticks {
        price_history.remove(0);
        volume_history.remove(0);
    }
    
    if price_history.len() < delayed_ticks { return; }
    
    let old_price = price_history[0];
    let old_volume = volume_history[0];
    let old_ma_60 = market.ma_60;
    
    let has_exhaustion_signal = false;
    if old_price > old_ma_60 && old_volume < 1000 {
        has_exhaustion_signal = true;
    }
    
    if account.stock > 0 {
        let current_pnl_percent = (market.price - account.avg_cost) * 10000 / account.avg_cost;
        if current_pnl_percent > 200 || current_pnl_percent < -100 {
            orders.submit_market_sell(account.stock);
            if current_pnl_percent < 0 {
                last_trade_was_loss = true;
            } else {
                last_trade_was_loss = false;
            }
        }
    }
    
    if has_exhaustion_signal && account.stock == 0 {
        if last_trade_was_loss {
            current_lot_size = current_lot_size * 2;
        } else {
            current_lot_size = base_lot_size;
        }
        
        let max_affordable = account.cash / market.price;
        let trade_amount = current_lot_size;
        if trade_amount > max_affordable {
            trade_amount = max_affordable;
        }
        
        if trade_amount > 0 {
            orders.submit_market_sell(trade_amount);
        }
    }
}