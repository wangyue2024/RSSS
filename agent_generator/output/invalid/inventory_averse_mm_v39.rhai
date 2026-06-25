let initialized = false;
let base_spread_bps = 50;
let level_increment_bps = 10;
let max_inventory = 1000;
let fomo_window = 5;
let fomo_threshold_bps = 200;
let order_size = 100;

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
    
    if market.history_len() >= fomo_window {
        let current_price = market.price;
        let past_price = market.history_price(fomo_window - 1);
        if past_price > 0 {
            let change_bps = (current_price - past_price) * 10000 / past_price;
            if change_bps > fomo_threshold_bps || change_bps < -fomo_threshold_bps {
                let buy_amount = order_size;
                if account.cash > current_price * buy_amount {
                    orders.submit_market_buy(buy_amount);
                }
                return;
            }
        }
    }
    
    let bid_exists = market.bid_price_0 > 0;
    let ask_exists = market.ask_price_0 > 0;
    let mid_price;
    if bid_exists && ask_exists {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    } else {
        mid_price = market.price;
    }
    
    if mid_price <= 0 { return; }
    
    let inventory = account.stock;
    let inventory_skew;
    if inventory > max_inventory {
        inventory_skew = 100;
    } else if inventory <= 0 {
        inventory_skew = -100;
    } else {
        inventory_skew = (inventory * 200) / max_inventory - 100;
    }
    
    let level = 0;
    while level < 5 {
        let buy_spread_bps = base_spread_bps + level * level_increment_bps + inventory_skew;
        let sell_spread_bps = base_spread_bps + level * level_increment_bps - inventory_skew;
        
        if buy_spread_bps < 5 { buy_spread_bps = 5; }
        if sell_spread_bps < 5 { sell_spread_bps = 5; }
        
        let buy_price = mid_price - (mid_price * buy_spread_bps) / 10000;
        let sell_price = mid_price + (mid_price * sell_spread_bps) / 10000;
        
        if buy_price > 0 && account.cash >= buy_price * order_size {
            orders.submit_limit_buy(buy_price, order_size);
        }
        
        if sell_price > 0 && account.stock >= order_size {
            orders.submit_limit_sell(sell_price, order_size);
        }
        
        level += 1;
    }
}