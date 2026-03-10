let initialized = false;
let base_spread = 0;
let order_size = 0;
let max_inventory = 0;
let inventory_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(1000, 5000);
        order_size = rng.rand_int(100, 300);
        max_inventory = 1000;
        inventory_threshold = 500;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let mid_price = market.price;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    }
    
    let inventory = account.stock;
    let avg_cost = account.avg_cost;
    
    let buy_distance = base_spread;
    let sell_distance = base_spread;
    
    if inventory > inventory_threshold {
        buy_distance = base_spread * 3 / 2;
        sell_distance = base_spread / 2;
    } else if inventory <= 0 {
        buy_distance = base_spread / 2;
        sell_distance = base_spread * 3 / 2;
    }
    
    let buy_price = mid_price - buy_distance;
    let sell_price = mid_price + sell_distance;
    
    if inventory < max_inventory && buy_price > 0 {
        orders.submit_limit_buy(buy_price, order_size);
    }
    
    if inventory > -max_inventory && sell_price > avg_cost {
        orders.submit_limit_sell(sell_price, order_size);
    }
}