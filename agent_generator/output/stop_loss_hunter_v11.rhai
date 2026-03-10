let initialized = false;
let panic_threshold = 0;
let cluster_threshold = 0;
let discount_percent = 0;
let recovery_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(50000, 200000);
        cluster_threshold = rng.rand_int(1000, 5000);
        discount_percent = rng.rand_int(50, 150);
        recovery_ticks = 0;
    }
    
    if !market.trading_enabled { return; }
    
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
    
    if recovery_ticks > 0 {
        recovery_ticks -= 1;
        return;
    }
    
    let sell_opportunity = false;
    if market.price > account.avg_cost && account.stock > 0 {
        let volume_below = 0;
        for lvl in 0..5 {
            let bid_price = market[`bid_price_${lvl}`];
            let bid_vol = market[`bid_vol_${lvl}`];
            if bid_price > 0 && bid_price < market.price && bid_price > account.avg_cost {
                volume_below += bid_vol;
            }
        }
        
        if volume_below > cluster_threshold {
            sell_opportunity = true;
            let sell_amount = account.stock * 30 / 100;
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
                recovery_ticks = 5;
            }
        }
    }
    
    if !sell_opportunity && account.cash > 0 {
        let target_price = market.price * (10000 - discount_percent) / 10000;
        if target_price > 0 {
            let max_buy = account.cash / target_price;
            if max_buy > 0 {
                orders.submit_limit_buy(target_price, max_buy);
            }
        }
    }
}