let initialized = false;
let panic_threshold = 0;
let neutral_spread = 2_000_000;
let order_size = 100;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        panic_threshold = rng.rand_int(-50_000, -10_000);
    }
    
    if market.tick % 50 != 0 { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let bid_price = if market.bid_price_0 > 0 { market.bid_price_0 } else { market.price - 1_000_000 };
    let ask_price = if market.ask_price_0 > 0 { market.ask_price_0 } else { market.price + 1_000_000 };
    let mid_price = (bid_price + ask_price) / 2;
    
    let inventory = account.stock;
    let bid_offset = neutral_spread;
    let ask_offset = neutral_spread;
    
    if inventory > 1000 {
        bid_offset = neutral_spread * 2;
        ask_offset = neutral_spread / 2;
    } else if inventory <= 0 {
        bid_offset = neutral_spread / 2;
        ask_offset = neutral_spread * 2;
    }
    
    let target_bid = mid_price - bid_offset;
    let target_ask = mid_price + ask_offset;
    
    let round_bid = ((target_bid + 500_000) / 1_000_000) * 1_000_000;
    let round_ask = ((target_ask + 500_000) / 1_000_000) * 1_000_000;
    
    if round_bid > 0 {
        orders.submit_limit_buy(round_bid, order_size);
    }
    if round_ask > 0 {
        orders.submit_limit_sell(round_ask, order_size);
    }
}