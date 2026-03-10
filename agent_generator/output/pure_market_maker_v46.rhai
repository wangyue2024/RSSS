let initialized = false;
let my_spread_bps = 50;
let my_order_amount = 100;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        (price / 1_000_000 + 1) * 1_000_000
    } else {
        (price / 1_000_000) * 1_000_000
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        my_spread_bps = rng.rand_int(30, 80);
        my_order_amount = rng.rand_int(50, 200);
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
    
    let bid_offset = mid_price * my_spread_bps / 10000;
    let ask_offset = mid_price * my_spread_bps / 10000;
    
    let raw_bid = mid_price - bid_offset;
    let raw_ask = mid_price + ask_offset;
    
    let rounded_bid = round_to_dollar(raw_bid);
    let rounded_ask = round_to_dollar(raw_ask);
    
    let final_bid = rounded_bid + 1;
    let final_ask = rounded_ask;
    
    let max_buy_amount = account.cash / final_bid;
    let buy_amount = if max_buy_amount < my_order_amount { max_buy_amount } else { my_order_amount };
    
    if buy_amount > 0 && final_bid > 0 {
        orders.submit_limit_buy(final_bid, buy_amount);
    }
    
    if market.price > account.avg_cost {
        let sell_amount = if account.stock < my_order_amount { account.stock } else { my_order_amount };
        if sell_amount > 0 && final_ask > 0 {
            orders.submit_limit_sell(final_ask, sell_amount);
        }
    }
}