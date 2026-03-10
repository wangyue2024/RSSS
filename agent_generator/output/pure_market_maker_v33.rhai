let initialized = false;
let panic_threshold = 0;
let base_lot_size = 0;
let current_lot_size = 0;
let last_trade_was_loss = false;
let first_20pct_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(50000, 200000);
        base_lot_size = rng.rand_int(50, 200);
        current_lot_size = base_lot_size;
        first_20pct_ticks = market.total_ticks / 5;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= first_20pct_ticks {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        let last_fill_index = fill_count - 1;
        let fill_price = my_orders.fill_price(last_fill_index);
        let fill_side = my_orders.fill_side(last_fill_index);
        
        if fill_side == 1 {
            if market.price < fill_price {
                last_trade_was_loss = true;
                current_lot_size = current_lot_size * 2;
            } else {
                last_trade_was_loss = false;
                current_lot_size = base_lot_size;
            }
        } else if fill_side == -1 {
            if market.price > fill_price {
                last_trade_was_loss = true;
                current_lot_size = current_lot_size * 2;
            } else {
                last_trade_was_loss = false;
                current_lot_size = base_lot_size;
            }
        }
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let spread = 5000;
    let buy_price = market.price - spread;
    let sell_price = market.price + spread;
    
    if buy_price > 0 {
        orders.submit_limit_buy(buy_price, current_lot_size);
    }
    
    if account.stock >= current_lot_size {
        orders.submit_limit_sell(sell_price, current_lot_size);
    }
}