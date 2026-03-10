let initialized = false;
let lot_size = 0;
let stop_loss_offset = 5000;
let breakout_active = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_cap = account.total_equity * 5 / 100;
        if market.price > 0 {
            let max_shares = five_percent_cap / market.price;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
            } else {
                lot_size = 0;
            }
        }
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let vol_threshold = market.price * 5 / 100;
    if market.std_dev > vol_threshold {
        return;
    }
    
    if account.stock > 0 {
        let stop_price = account.avg_cost - stop_loss_offset;
        if market.price < stop_price {
            orders.submit_market_sell(account.stock);
            breakout_active = false;
        }
    }
    
    if market.price > market.high_20 && !breakout_active && account.stock == 0 {
        if lot_size > 0 {
            orders.submit_market_buy(lot_size);
            breakout_active = true;
        }
    }
}