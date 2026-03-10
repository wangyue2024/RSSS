let initialized = false;
let base_lot_size = 100;
let current_lot_size = 100;
let prev_realized_pnl = 0;
let last_trade_was_loss = false;
let loss_streak = 0;

fn round_price(price) {
    let half_dollar = 500_000;
    let dollar = 1_000_000;
    return ((price + half_dollar) / dollar) * dollar;
}

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_realized_pnl = account.realized_pnl;
        base_lot_size = rng.rand_int(80, 120);
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let pnl_change = account.realized_pnl - prev_realized_pnl;
    if pnl_change < 0 {
        last_trade_was_loss = true;
        loss_streak += 1;
    } else if pnl_change > 0 {
        last_trade_was_loss = false;
        loss_streak = 0;
    }
    prev_realized_pnl = account.realized_pnl;
    
    if last_trade_was_loss {
        current_lot_size = base_lot_size * (1 << loss_streak);
        if current_lot_size > 10000 {
            current_lot_size = 10000;
        }
    } else {
        current_lot_size = base_lot_size;
        loss_streak = 0;
    }
    
    let imbalance = market.order_imbalance;
    let base_price = market.price;
    
    let adjustment = 0;
    if imbalance > 500 {
        adjustment = 2_000_000;
    } else if imbalance > 200 {
        adjustment = 1_000_000;
    } else if imbalance < -500 {
        adjustment = -2_000_000;
    } else if imbalance < -200 {
        adjustment = -1_000_000;
    }
    
    let target_price = base_price + adjustment;
    let rounded_price = round_price(target_price);
    
    let bid_price = rounded_price - 1_000_000;
    let ask_price = rounded_price + 1_000_000;
    
    if bid_price > 0 && current_lot_size > 0 {
        orders.submit_limit_buy(bid_price, current_lot_size);
    }
    
    if ask_price > 0 && current_lot_size > 0 {
        orders.submit_limit_sell(ask_price, current_lot_size);
    }
}