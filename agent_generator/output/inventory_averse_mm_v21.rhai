let initialized = false;
let base_spread_micros = 2000;
let order_size = 100;
let max_inventory_skew = 5000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let inventory = account.stock;
    let mid_price = market.price;
    
    let inv_factor = clamp_val(inventory, -1000, 1000);
    let skew_micros = inv_factor * 5;
    
    let bid_distance = base_spread_micros / 2 + skew_micros;
    let ask_distance = base_spread_micros / 2 - skew_micros;
    
    let bid_price = mid_price - bid_distance + 1;
    let ask_price = mid_price + ask_distance;
    
    if bid_price > 0 && bid_price < ask_price {
        orders.submit_limit_buy(bid_price, order_size);
    }
    
    if ask_price > bid_price {
        orders.submit_limit_sell(ask_price, order_size);
    }
}