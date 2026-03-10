let initialized = false;
let panic_threshold = 0;
let price_history = [];
let decision_ticks = [];
let last_evaluation_tick = -100;
let position_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(5_000, 25_000);
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        let cancel_count = my_orders.pending_count();
        let i = 0;
        while i < cancel_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        orders.submit_market_sell(account.stock);
        return;
    }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if market.tick % 50 == 0 && price_history.len() >= 5 {
        last_evaluation_tick = market.tick;
        
        let cancel_count = my_orders.pending_count();
        let i = 0;
        while i < cancel_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let delayed_price = price_history[0];
        
        if market.ma_20 != 0 && market.std_dev != 0 {
            let upper_band = market.ma_20 + 2 * market.std_dev;
            let lower_band = market.ma_20 - 2 * market.std_dev;
            
            if lower_band > 0 && delayed_price > lower_band {
                orders.submit_limit_buy(lower_band, position_size);
            }
            
            if upper_band > 0 && delayed_price < upper_band {
                orders.submit_limit_sell(upper_band, position_size);
            }
        }
    }
}