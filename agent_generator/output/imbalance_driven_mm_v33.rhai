let initialized = false;
let base_lot_size = 0;
let max_lot_size = 0;
let current_lot_size = 0;
let imbalance_threshold = 0;
let price_adjust_factor = 0;
let spread_micros = 0;
let last_trade_was_loss = false;
let prev_realized_pnl = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(50, 150);
        max_lot_size = base_lot_size * 16;
        current_lot_size = base_lot_size;
        imbalance_threshold = rng.rand_int(5, 20);
        price_adjust_factor = rng.rand_int(10, 50);
        spread_micros = rng.rand_int(100, 300);
        prev_realized_pnl = account.realized_pnl;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let realized_change = account.realized_pnl - prev_realized_pnl;
    if realized_change < 0 {
        last_trade_was_loss = true;
    } else if realized_change > 0 {
        last_trade_was_loss = false;
    }
    prev_realized_pnl = account.realized_pnl;
    
    if last_trade_was_loss {
        current_lot_size = current_lot_size * 2;
        if current_lot_size > max_lot_size {
            current_lot_size = max_lot_size;
        }
    } else {
        current_lot_size = base_lot_size;
    }
    
    let mid_price = market.price;
    let imbalance = market.order_imbalance;
    let imbalance_adj = 0;
    
    if imbalance > imbalance_threshold {
        imbalance_adj = imbalance * price_adjust_factor;
    } else if imbalance < -imbalance_threshold {
        imbalance_adj = imbalance * price_adjust_factor;
    }
    
    let adjusted_mid = mid_price + imbalance_adj;
    let half_spread = spread_micros / 2;
    
    let bid_price = adjusted_mid - half_spread + 1;
    let ask_price = adjusted_mid + half_spread;
    
    if bid_price > 0 && current_lot_size > 0 {
        orders.submit_limit_buy(bid_price, current_lot_size);
    }
    
    if ask_price > 0 && current_lot_size > 0 {
        orders.submit_limit_sell(ask_price, current_lot_size);
    }
}