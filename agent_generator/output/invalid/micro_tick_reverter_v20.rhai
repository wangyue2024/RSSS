let initialized = false;
let trade_amount = 0;
let buy_offset = 0;
let sell_offset = 0;
let active_tick_mod = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_amount = 100;
        buy_offset = 5000;
        sell_offset = 5000;
        active_tick_mod = rng.rand_int(0, 49);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick % 50 == active_tick_mod {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        if market.history_len() >= 1 {
            let prev_price = market.history_price(0);
            let current_price = market.price;
            
            if current_price < prev_price && account.cash > current_price * trade_amount {
                let bid_price = current_price - buy_offset + 1;
                if bid_price > 0 {
                    orders.submit_limit_buy(bid_price, trade_amount);
                }
            } else if current_price > prev_price && account.stock >= trade_amount && current_price > account.avg_cost {
                let ask_price = current_price + sell_offset + 1;
                orders.submit_limit_sell(ask_price, trade_amount);
            }
        }
    }
}