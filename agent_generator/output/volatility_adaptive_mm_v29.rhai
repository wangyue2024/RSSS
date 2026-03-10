let initialized = false;
let data_queue = [];
let OLD_TICK_COUNT = 5;
let MIN_SPREAD = 1000;
let MAX_SPREAD = 100000;
let BASE_SPREAD = 2000;
let VOL_MULTIPLIER = 3;
let ORDER_SIZE = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    data_queue.push([market.price, market.std_dev]);
    
    if data_queue.len() > OLD_TICK_COUNT {
        data_queue.remove(0);
    }
    
    if data_queue.len() == OLD_TICK_COUNT {
        let old_data = data_queue[0];
        let old_price = old_data[0];
        let old_std_dev = old_data[1];
        
        let volatility_component = old_std_dev * VOL_MULTIPLIER;
        let total_spread = BASE_SPREAD + volatility_component;
        
        let spread = total_spread;
        if spread < MIN_SPREAD {
            spread = MIN_SPREAD;
        }
        if spread > MAX_SPREAD {
            spread = MAX_SPREAD;
        }
        
        let half_spread = spread / 2;
        let bid_price = old_price - half_spread;
        let ask_price = old_price + half_spread;
        
        let required_cash = bid_price * ORDER_SIZE;
        if account.cash >= required_cash {
            orders.submit_limit_buy(bid_price, ORDER_SIZE);
        }
        
        if account.stock >= ORDER_SIZE && ask_price > account.avg_cost {
            orders.submit_limit_sell(ask_price, ORDER_SIZE);
        }
    }
}