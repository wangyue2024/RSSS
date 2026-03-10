let initialized = false;
let base_half_spread = 0;
let order_size = 0;
let max_inventory = 1000;
let morning_ticks = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        morning_ticks = market.total_ticks / 5;
        base_half_spread = micros(0, 2);
        order_size = 100;
    }
    
    if market.tick >= morning_ticks { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let mid_price = 0;
    let has_bid = market.bid_price_0 > 0;
    let has_ask = market.ask_price_0 > 0;
    
    if has_bid && has_ask {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    } else if has_bid {
        mid_price = market.bid_price_0;
    } else if has_ask {
        mid_price = market.ask_price_0;
    } else {
        mid_price = market.price;
    }
    
    let inventory = account.stock;
    let inventory_ratio = 0;
    if inventory > max_inventory {
        inventory_ratio = 50;
    } else if inventory < -max_inventory {
        inventory_ratio = -50;
    } else {
        inventory_ratio = (inventory * 50) / max_inventory;
    }
    
    let buy_adjust = (base_half_spread * inventory_ratio) / 100;
    let sell_adjust = (base_half_spread * inventory_ratio) / 100;
    
    let buy_price = mid_price - base_half_spread - buy_adjust;
    let sell_price = mid_price + base_half_spread - sell_adjust;
    
    buy_price = max(buy_price, 1);
    sell_price = max(sell_price, 1);
    
    if account.cash >= buy_price * order_size {
        orders.submit_limit_buy(buy_price, order_size);
    }
    
    if account.stock >= order_size {
        orders.submit_limit_sell(sell_price, order_size);
    }
}