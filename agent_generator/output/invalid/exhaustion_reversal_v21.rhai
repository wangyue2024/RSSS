let initialized = false;
let recent_prices = [];
let recent_volumes = [];
let panic_threshold = 0;
let std_dev_threshold = 0;
let lot_size = 0;
let fomo_window = 5;
let fomo_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        let max_lot = account.total_equity * 5 / 100;
        if max_lot < 1 { max_lot = 1; }
        lot_size = rng.rand_int(1, max_lot);
        panic_threshold = -rng.rand_int(10_000, 50_000);
        std_dev_threshold = rng.rand_int(100_000, 500_000);
        initialized = true;
    }
    
    recent_prices.push(market.price);
    recent_volumes.push(market.volume);
    if recent_prices.len() > fomo_window {
        recent_prices.remove(0);
        recent_volumes.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if recent_prices.len() == fomo_window {
        let old_price = recent_prices[0];
        let new_price = recent_prices[fomo_window - 1];
        if (new_price - old_price) * 100 > old_price * 2 {
            orders.submit_market_buy(lot_size);
            fomo_triggered = true;
            return;
        }
    }
    
    if fomo_triggered { return; }
    
    if market.std_dev > std_dev_threshold { return; }
    
    let exhaustion_condition = market.price > market.ma_60;
    if recent_volumes.len() == fomo_window && exhaustion_condition {
        let sum = 0;
        let j = 0;
        while j < fomo_window {
            sum += recent_volumes[j];
            j += 1;
        }
        let avg_vol = sum / fomo_window;
        if market.volume * 10 < avg_vol {
            if account.stock >= lot_size {
                orders.submit_limit_sell(market.bid_price_0, lot_size);
            } else {
                orders.submit_market_sell(account.stock);
            }
        }
    }
}