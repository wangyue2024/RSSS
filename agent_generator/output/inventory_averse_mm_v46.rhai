let initialized = false;
let base_spread = 20000;
let order_size = 100;
let max_inventory = 1000;
let skew_factor = 500;
let min_spread = 5000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { 
        return; 
    }
    
    let current_tick = market.tick;
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    if mid_price <= 0 {
        mid_price = market.price;
    }
    
    let inventory = account.stock;
    let spread_adjust = 0;
    
    if inventory > max_inventory {
        spread_adjust = ((inventory - max_inventory) * skew_factor) / 100;
    } else if inventory < 0 {
        spread_adjust = ((0 - inventory) * skew_factor) / 100;
    }
    
    let buy_spread = base_spread + spread_adjust;
    let sell_spread = base_spread - spread_adjust;
    
    if sell_spread < min_spread {
        sell_spread = min_spread;
    }
    if buy_spread < min_spread {
        buy_spread = min_spread;
    }
    
    let bid_price = mid_price - buy_spread;
    let ask_price = mid_price + sell_spread;
    
    if bid_price > 0 && ask_price > 0 && bid_price < ask_price {
        orders.submit_limit_buy(bid_price, order_size);
        orders.submit_limit_sell(ask_price, order_size);
    }
}