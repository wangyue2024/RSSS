let initialized = false;
let last_prices = [];
let tick_offset = 5;
let morning_only = true;
let trade_amount = 100;
let price_offset = 100000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if morning_only {
        if market.tick >= market.total_ticks / 5 {
            return;
        }
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    last_prices.push(market.price);
    
    if last_prices.len() > tick_offset + 1 {
        last_prices.remove(0);
    }
    
    if last_prices.len() > tick_offset {
        let old_price = last_prices[last_prices.len() - tick_offset - 1];
        let new_price = last_prices[last_prices.len() - tick_offset];
        
        if new_price < old_price {
            let buy_price = new_price - price_offset;
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, trade_amount);
            }
        } else if new_price > old_price {
            let sell_price = new_price + price_offset;
            if sell_price > 0 {
                orders.submit_limit_sell(sell_price, trade_amount);
            }
        }
    }
}