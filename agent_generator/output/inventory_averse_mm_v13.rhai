let initialized = false;
let panic_threshold = 0;
let last_fill_price = 0;
let last_fill_side = 0;
let last_trade_was_loss = false;
let base_lot_size = 100;
let current_lot_size = 100;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(1_000_000, 5_000_000);
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_idx = fill_cnt - 1;
        last_fill_price = my_orders.fill_price(last_idx);
        last_fill_side = my_orders.fill_side(last_idx);
        
        if last_fill_side == 0 {
            if market.price < last_fill_price {
                last_trade_was_loss = true;
            } else {
                last_trade_was_loss = false;
            }
        } else {
            if market.price > last_fill_price {
                last_trade_was_loss = true;
            } else {
                last_trade_was_loss = false;
            }
        }
        
        if last_trade_was_loss {
            current_lot_size = current_lot_size * 2;
            if current_lot_size > 1600 {
                current_lot_size = 1600;
            }
        } else {
            current_lot_size = base_lot_size;
        }
    }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let spread = 2_000_000;
    let half_spread = spread / 2;
    let inventory = account.stock;
    
    let bid_offset = half_spread;
    let ask_offset = half_spread;
    
    if inventory > 1000 {
        bid_offset = bid_offset + 750_000;
        ask_offset = ask_offset - 250_000;
    } else if inventory <= 0 {
        bid_offset = bid_offset - 250_000;
        ask_offset = ask_offset + 750_000;
    }
    
    if bid_offset < 50_000 { bid_offset = 50_000; }
    if ask_offset < 50_000 { ask_offset = 50_000; }
    
    let raw_bid = mid_price - bid_offset;
    let raw_ask = mid_price + ask_offset;
    
    let rounded_bid = ((raw_bid + 500_000) / 1_000_000) * 1_000_000;
    let rounded_ask = ((raw_ask + 500_000) / 1_000_000) * 1_000_000;
    
    if rounded_bid > 0 {
        orders.submit_limit_buy(rounded_bid, current_lot_size);
    }
    if rounded_ask > 0 {
        orders.submit_limit_sell(rounded_ask, current_lot_size);
    }
}