let initialized = false;
let entry_price = 0;
let tp_order_id = -1;
let sl_order_id = -1;
let trade_active = false;
let fomo_triggered = false;
let last_eval_tick = -100;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_eval_tick = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let price = market.price;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if !trade_active && market.history_len() >= 5 {
        let price_now = market.price;
        let price_5_ago = market.history_price(4);
        let change = price_now - price_5_ago;
        let change_pct = change * 10000 / price_5_ago;
        
        if change_pct > 200 {
            fomo_triggered = true;
        }
    }
    
    if current_tick % 50 == 0 && current_tick != last_eval_tick {
        last_eval_tick = current_tick;
        
        if !trade_active {
            if fomo_triggered {
                let buy_amount = 100;
                orders.submit_market_buy(buy_amount);
                entry_price = account.avg_cost;
                
                let tp_price = entry_price + entry_price * 5 / 100;
                tp_order_id = orders.submit_limit_sell(tp_price, buy_amount);
                
                trade_active = true;
                fomo_triggered = false;
            } else if rng.rand_bool(2) {
                let buy_amount = 100;
                orders.submit_market_buy(buy_amount);
                entry_price = account.avg_cost;
                
                let tp_price = entry_price + entry_price * 5 / 100;
                tp_order_id = orders.submit_limit_sell(tp_price, buy_amount);
                
                trade_active = true;
            }
        } else {
            let stock_held = account.stock;
            if stock_held > 0 {
                let sl_price = entry_price - entry_price * 2 / 100;
                if price <= sl_price {
                    orders.submit_market_sell(stock_held);
                    trade_active = false;
                    entry_price = 0;
                    tp_order_id = -1;
                    sl_order_id = -1;
                }
            } else {
                trade_active = false;
                entry_price = 0;
                tp_order_id = -1;
                sl_order_id = -1;
            }
        }
    }
}