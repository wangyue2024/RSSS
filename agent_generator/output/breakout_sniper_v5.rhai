let initialized = false;
let base_lot_size = 0;
let stop_loss_offset = 0;
let fomo_window = 5;
let fomo_threshold_pct = 200;
let impatience_ticks = 3;
let price_history = [];
let position_active = false;
let entry_tick = 0;
let last_fomo_check = 0;

fn on_tick() {
    if !initialized {
        base_lot_size = rng.rand_int(500, 5000);
        stop_loss_offset = rng.rand_int(10000, 50000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > fomo_window {
        price_history.remove(0);
    }
    
    let current_price = market.price;
    let total_ticks = market.total_ticks;
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock > 0 {
        position_active = true;
        let stop_price = account.avg_cost - stop_loss_offset;
        if current_price <= stop_price {
            orders.submit_market_sell(account.stock);
            position_active = false;
        }
    } else {
        position_active = false;
    }
    
    if position_active { return; }
    
    let fomo_triggered = false;
    if price_history.len() == fomo_window && total_ticks > last_fomo_check {
        last_fomo_check = total_ticks;
        let old_price = price_history[0];
        let price_change = (current_price - old_price) * 10000 / old_price;
        if price_change > fomo_threshold_pct {
            fomo_triggered = true;
        }
    }
    
    let max_share_cost = account.cash * 50 / 100;
    let max_shares = max_share_cost / current_price;
    let trade_shares = base_lot_size;
    if trade_shares > max_shares {
        trade_shares = max_shares;
    }
    if trade_shares < 1 { trade_shares = 1; }
    
    if fomo_triggered {
        orders.submit_market_buy(trade_shares);
    } else if current_price > market.high_20 {
        let buy_price = market.ask_price_0;
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price, trade_shares);
        }
    }
}