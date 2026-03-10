let initialized = false;
let lot_size_percent = 0;
let threshold_percent = 0;
let vwap_pullback_factor = 0;
let last_order_tick = -10;
let active_order_id = -1;
let order_placed_tick = 0;
let max_wait_ticks = 3;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        lot_size_percent = rng.rand_int(40, 50);
        threshold_percent = rng.rand_int(80, 120);
        vwap_pullback_factor = rng.rand_int(70, 90);
    }
    
    let current_tick = market.tick;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed >= max_wait_ticks {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if pending_count > 0 {
        return;
    }
    
    let vwap = market.vwap;
    let price = market.price;
    
    if vwap <= 0 || price <= 0 {
        return;
    }
    
    let threshold = vwap * threshold_percent / 10000;
    let pullback_target = vwap * vwap_pullback_factor / 100;
    
    let buy_signal = price < vwap - threshold;
    let sell_signal = price >= pullback_target && account.stock > 0;
    
    if buy_signal && account.cash > 1000000 {
        let bid_price = market.bid_price_0;
        if bid_price <= 0 {
            bid_price = price;
        }
        
        let max_shares = account.cash / bid_price;
        let shares_to_buy = max_shares * lot_size_percent / 100;
        if shares_to_buy < 1 {
            shares_to_buy = 1;
        }
        
        let limit_price = bid_price + 1;
        orders.submit_limit_buy(limit_price, shares_to_buy);
        order_placed_tick = current_tick;
    } else if sell_signal && account.stock > 0 {
        let ask_price = market.ask_price_0;
        if ask_price <= 0 {
            ask_price = price;
        }
        
        let shares_to_sell = account.stock * lot_size_percent / 100;
        if shares_to_sell < 1 {
            shares_to_sell = 1;
        }
        if shares_to_sell > account.stock {
            shares_to_sell = account.stock;
        }
        
        let limit_price = ask_price;
        orders.submit_limit_sell(limit_price, shares_to_sell);
        order_placed_tick = current_tick;
    }
}