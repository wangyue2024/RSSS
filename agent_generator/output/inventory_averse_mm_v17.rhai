let initialized = false;
let lot_size = 0;
let max_inventory = 1000;
let base_spread = 0;
let skew_factor = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(5000, 20000);
        base_spread = rng.rand_int(20000, 50000);
        skew_factor = rng.rand_int(5000, 20000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let inventory = account.stock;
    
    let bid_offset = base_spread;
    let ask_offset = base_spread;
    
    if inventory > max_inventory {
        bid_offset = base_spread + skew_factor;
        ask_offset = base_spread - skew_factor;
        if ask_offset < 1000 { ask_offset = 1000; }
    } else if inventory <= 0 {
        bid_offset = base_spread - skew_factor;
        ask_offset = base_spread + skew_factor;
        if bid_offset < 1000 { bid_offset = 1000; }
    }
    
    let buy_price = mid_price - bid_offset;
    let sell_price = mid_price + ask_offset;
    
    if buy_price > 0 {
        let max_buy_shares = (account.cash * 50) / (100 * buy_price);
        let buy_amount = lot_size;
        if buy_amount > max_buy_shares { buy_amount = max_buy_shares; }
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    if sell_price > 0 && account.stock > 0 {
        let sell_amount = lot_size;
        if sell_amount > account.stock { sell_amount = account.stock; }
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}