let initialized = false;
let base_position = 1000;
let spread_threshold = 500000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { 
        return; 
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let spread = market.high_20 - market.low_20;
    let position_size = base_position;
    if spread < spread_threshold {
        position_size = base_position * 2;
    }
    
    let buy_price = market.low_20 + 1;
    let sell_price = market.high_20;
    
    if buy_price < sell_price {
        orders.submit_limit_buy(buy_price, position_size);
        orders.submit_limit_sell(sell_price, position_size);
    }
}