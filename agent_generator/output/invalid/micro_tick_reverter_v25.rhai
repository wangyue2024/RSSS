let initialized = false;
let order_offset = 0;
let trade_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        order_offset = rng.rand_int(1000, 10000);
        trade_amount = rng.rand_int(10, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.history_len() == 0 { return; }
    
    let prev_price = market.history_price(market.history_len() - 1);
    let current_price = market.price;
    
    if current_price < prev_price {
        let raw_buy_price = current_price - order_offset;
        let rounded_price = (raw_buy_price / 1_000_000) * 1_000_000;
        
        if rounded_price > 0 && rounded_price < current_price {
            let cost = rounded_price * trade_amount;
            if cost <= account.cash {
                orders.submit_limit_buy(rounded_price, trade_amount);
            }
        }
    } else if current_price > prev_price {
        if account.stock >= trade_amount {
            let raw_sell_price = current_price + order_offset;
            let rounded_price = (raw_sell_price / 1_000_000) * 1_000_000;
            
            if rounded_price > current_price {
                orders.submit_limit_sell(rounded_price, trade_amount);
            }
        }
    }
}