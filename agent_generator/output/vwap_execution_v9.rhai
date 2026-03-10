let initialized = false;
let total_shares_target = 0;
let base_lot_size = 0;
let stop_loss_threshold = 0;
let volume_window = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let total_capital = account.cash + account.stock * market.price;
        let five_percent_cap = total_capital * 5 / 100;
        
        base_lot_size = rng.rand_int(1, five_percent_cap / market.price);
        if base_lot_size < 1 { base_lot_size = 1; }
        
        total_shares_target = rng.rand_int(100, 1000);
        
        stop_loss_threshold = -rng.rand_int(5000, 20000);
        
        volume_window = [];
        for i in 0..20 {
            if i < market.history_len() {
                volume_window.push(market.history_volume(i));
            }
        }
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < stop_loss_threshold && account.unrealized_pnl < 0 {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    if market.std_dev > market.price * 1 / 100 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if volume_window.len() >= 20 {
        volume_window.remove(0);
    }
    volume_window.push(market.volume);
    
    if total_shares_target <= account.stock {
        return;
    }
    
    let avg_volume = arr_mean(volume_window);
    if avg_volume == 0 { avg_volume = 1; }
    
    let volume_ratio = market.volume * 100 / avg_volume;
    
    let dynamic_lot = base_lot_size * volume_ratio / 100;
    let max_lot = base_lot_size * 150 / 100;
    let min_lot = base_lot_size * 50 / 100;
    
    let adjusted_lot = dynamic_lot;
    if adjusted_lot < min_lot { adjusted_lot = min_lot; }
    if adjusted_lot > max_lot { adjusted_lot = max_lot; }
    
    let remaining_shares = total_shares_target - account.stock;
    if adjusted_lot > remaining_shares {
        adjusted_lot = remaining_shares;
    }
    
    if adjusted_lot > 0 && market.bid_price_0 > 0 {
        orders.submit_limit_buy(market.bid_price_0, adjusted_lot);
    }
}