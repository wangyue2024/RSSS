let initialized = false;
let base_spread = 0;
let order_size = 0;
let inventory_threshold = 0;

fn round_to_dollar(price) {
    let half_dollar = 500_000;
    ((price + half_dollar) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(2_000_000, 5_000_000);
        order_size = rng.rand_int(50, 200);
        inventory_threshold = 1000;
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
    
    let buy_distance = base_spread / 2;
    let sell_distance = base_spread / 2;
    
    if inventory > inventory_threshold {
        buy_distance = buy_distance * 3 / 2;
        sell_distance = sell_distance / 2;
    } else if inventory <= 0 {
        buy_distance = buy_distance / 2;
        sell_distance = sell_distance * 3 / 2;
    }
    
    let target_buy_price = mid_price - buy_distance;
    let target_sell_price = mid_price + sell_distance;
    
    let rounded_buy = round_to_dollar(target_buy_price);
    let rounded_sell = round_to_dollar(target_sell_price);
    
    if rounded_buy > 0 && rounded_buy < market.ask_price_0 {
        orders.submit_limit_buy(rounded_buy, order_size);
    }
    
    if rounded_sell > 0 && rounded_sell > market.bid_price_0 {
        orders.submit_limit_sell(rounded_sell, order_size);
    }
}