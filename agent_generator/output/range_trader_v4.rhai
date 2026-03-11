let initialized = false;
let base_position = 100;
let offset_micros = 500;
let spread_threshold = 5000;
let last_action_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_position = rng.rand_int(80, 120);
        offset_micros = rng.rand_int(300, 700);
        spread_threshold = rng.rand_int(3000, 7000);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    if current_tick % 50 != 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let high_20 = market.high_20;
    let low_20 = market.low_20;
    let spread = high_20 - low_20;
    
    let position_multiplier = if spread < spread_threshold { 2 } else { 1 };
    let buy_amount = base_position * position_multiplier;
    let sell_amount = base_position * position_multiplier;
    
    let avg_cost = account.avg_cost;
    let current_price = market.price;
    
    if spread > 0 && low_20 > 0 {
        let buy_price = low_20 + offset_micros;
        let cost_estimate = buy_price * buy_amount;
        if account.cash >= cost_estimate {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    if account.stock >= sell_amount && current_price > avg_cost && spread > 0 {
        let sell_price = high_20 - offset_micros;
        if sell_price > avg_cost {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
    
    last_action_tick = current_tick;
}