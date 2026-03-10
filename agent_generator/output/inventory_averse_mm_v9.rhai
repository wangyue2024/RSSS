let initialized = false;
let order_amount = 1000;
let high_inventory_threshold = 1000;
let base_spread = 500000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let inventory = account.stock;
    let mid_price = market.price;
    let spread_adjust = 200000;
    
    let raw_bid_price;
    let raw_ask_price;
    
    if inventory > high_inventory_threshold {
        raw_bid_price = mid_price - base_spread - spread_adjust;
        raw_ask_price = mid_price + base_spread - spread_adjust / 2;
    } else if inventory <= 0 {
        raw_bid_price = mid_price - base_spread + spread_adjust / 2;
        raw_ask_price = mid_price + base_spread + spread_adjust;
    } else {
        raw_bid_price = mid_price - base_spread;
        raw_ask_price = mid_price + base_spread;
    }
    
    let round_to = 1000000;
    let bid_price = ((raw_bid_price + round_to / 2) / round_to) * round_to;
    let ask_price = ((raw_ask_price + round_to / 2) / round_to) * round_to;
    
    if bid_price > 0 && ask_price > bid_price {
        orders.submit_limit_buy(bid_price, order_amount);
        orders.submit_limit_sell(ask_price, order_amount);
    }
}