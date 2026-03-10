let initialized = false;
let lot_size = 0;
let skip_counter = 0;
let base_spread = 2000;
let max_inventory = 1000;
let std_dev_threshold = 100000;
let base_spread_adjust = 500;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        let max_cap_shares = account.total_equity * 5 / 100 / market.price;
        if max_cap_shares > 0 {
            lot_size = rng.rand_int(1, max_cap_shares);
        } else {
            lot_size = rng.rand_int(1, 100);
        }
    }
    
    skip_counter += 1;
    if skip_counter < 50 { return; }
    skip_counter = 0;
    
    if market.std_dev > std_dev_threshold { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if market.bid_price_0 == 0 || market.ask_price_0 == 0 { return; }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let inventory = account.stock;
    
    let buy_spread = base_spread;
    let sell_spread = base_spread;
    
    if inventory > max_inventory {
        buy_spread = base_spread + base_spread_adjust;
        sell_spread = base_spread - base_spread_adjust;
    } else if inventory <= 0 {
        buy_spread = base_spread - base_spread_adjust;
        sell_spread = base_spread + base_spread_adjust;
    }
    
    if buy_spread < 100 { buy_spread = 100; }
    if sell_spread < 100 { sell_spread = 100; }
    
    let buy_price = mid_price - buy_spread;
    let sell_price = mid_price + sell_spread;
    
    if buy_price > 0 && lot_size > 0 {
        orders.submit_limit_buy(buy_price, lot_size);
    }
    
    if sell_price > 0 && lot_size > 0 {
        orders.submit_limit_sell(sell_price, lot_size);
    }
}