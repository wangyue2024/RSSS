let initialized = false;
let stop_loss_threshold = 0;
let base_spread_bp = 0;
let order_size = 0;
let fomo_check_ticks = 0;
let panic_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(50000, 200000);
        base_spread_bp = rng.rand_int(8, 15);
        order_size = rng.rand_int(80, 120);
        fomo_check_ticks = rng.rand_int(3, 7);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if panic_triggered {
        return;
    }
    
    if account.unrealized_pnl <= stop_loss_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        panic_triggered = true;
        return;
    }
    
    if market.history_len() >= fomo_check_ticks {
        let old_price = market.history_price(fomo_check_ticks - 1);
        if old_price > 0 {
            let price_change = market.price - old_price;
            let threshold = old_price * 200 / 10000;
            if price_change > threshold {
                let buy_amount = order_size * 2;
                orders.submit_market_buy(buy_amount);
                return;
            }
        }
    }
    
    let mid_price = market.price;
    if mid_price == 0 { return; }
    
    let volatility_scale = market.std_dev * 10000 / mid_price;
    let spread_multiplier = 100 + volatility_scale * 3;
    let spread_bp = base_spread_bp * spread_multiplier / 100;
    
    let half_spread = mid_price * spread_bp / (2 * 10000);
    let bid_price = mid_price - half_spread;
    let ask_price = mid_price + half_spread;
    
    if account.cash >= bid_price * order_size {
        orders.submit_limit_buy(bid_price, order_size);
    }
    
    if account.stock >= order_size {
        orders.submit_limit_sell(ask_price, order_size);
    }
}