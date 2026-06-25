let price_history = [];
let initialized = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    if market.tick < market.total_ticks / 5 {
        price_history.push(market.price);
        
        if price_history.len() > 5 {
            price_history.remove(0);
        }
        
        if price_history.len() == 5 {
            let delayed_price = price_history[0];
            let threshold = market.atr_14 * 3 / 2;
            let deviation = abs_val(delayed_price - market.ma_20);
            
            let pending_cnt = my_orders.pending_count();
            let i = 0;
            while i < pending_cnt {
                let placed_tick = my_orders.pending_placed_tick(i);
                if market.tick - placed_tick > 3 {
                    let oid = my_orders.pending_id(i);
                    orders.submit_cancel(oid);
                }
                i += 1;
            }
            
            if deviation > threshold {
                let trade_amount = 100;
                
                if delayed_price > market.ma_20 && account.stock >= trade_amount {
                    orders.submit_limit_sell(market.ma_20, trade_amount);
                } else if delayed_price < market.ma_20 && account.cash >= market.ma_20 * trade_amount {
                    orders.submit_limit_buy(market.ma_20, trade_amount);
                }
            }
        }
    } else {
        price_history = [];
        
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }
}