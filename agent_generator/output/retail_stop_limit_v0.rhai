let state = 0;
let entry_tick = 0;
let tp_order_id = -1;
let sl_order_id = -1;
let avg_cost_entry = 0;
let initialized = false;
let trade_size = 0;
let take_profit_price = 0;
let stop_price = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        trade_size = rng.rand_int(5, 20);
    }
    
    if state == 0 {
        let chance = rng.rand_int(0, 10000);
        if chance < 10 {
            orders.submit_market_buy(trade_size);
            entry_tick = market.tick;
            state = 1;
        }
        return;
    }
    
    if state == 1 {
        if account.stock == 0 {
            state = 0;
            tp_order_id = -1;
            sl_order_id = -1;
            return;
        }
        
        avg_cost_entry = account.avg_cost;
        
        let round_unit = 1_000_000;
        take_profit_price = ((avg_cost_entry * 105) / 100 + round_unit / 2) / round_unit * round_unit;
        stop_price = (avg_cost_entry * 98) / 100;
        
        if my_orders.pending_count() == 0 {
            if take_profit_price > avg_cost_entry {
                tp_order_id = orders.submit_limit_sell(take_profit_price, account.stock);
            }
            state = 2;
        }
        return;
    }
    
    if state == 2 {
        if account.stock == 0 {
            state = 0;
            tp_order_id = -1;
            sl_order_id = -1;
            return;
        }
        
        if market.price <= stop_price && market.price > 0 {
            let count = my_orders.pending_count();
            let i = 0;
            while i < count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            orders.submit_market_sell(account.stock);
            state = 0;
            return;
        }
        
        let tp_active = false;
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            if my_orders.pending_id(i) == tp_order_id {
                tp_active = true;
                break;
            }
            i += 1;
        }
        
        if !tp_active && account.stock > 0 {
            if take_profit_price > avg_cost_entry {
                tp_order_id = orders.submit_limit_sell(take_profit_price, account.stock);
            }
        }
    }
}