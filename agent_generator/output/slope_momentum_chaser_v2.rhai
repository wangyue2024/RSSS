let initialized = false;
let decision_tick = 0;
let last_slope = 0;
let last_decision = 0;
let position_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        decision_tick = market.tick;
        position_size = 50000;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick % 50 != 0 {
        return;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let history_len = market.history_len();
    if history_len < 5 {
        return;
    }
    
    let price_arr = [];
    let j = 0;
    while j < 5 {
        let idx = history_len - 1 - j;
        if idx >= 0 {
            price_arr.push(market.history_price(idx));
        }
        j += 1;
    }
    
    let current_slope = arr_slope(price_arr);
    
    let should_buy = false;
    let should_sell = false;
    
    if current_slope > 2000 && current_slope > last_slope * 110 / 100 {
        should_buy = true;
    }
    
    if current_slope < 0 && last_slope > 0 {
        if market.price > account.avg_cost && account.stock > 0 {
            should_sell = true;
        }
    }
    
    if should_buy && account.cash > market.price * 100 {
        let max_buy = account.cash / market.price;
        let buy_amount = max_buy;
        if buy_amount > position_size {
            buy_amount = position_size;
        }
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }
    
    if should_sell && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }
    
    last_slope = current_slope;
    last_decision = market.tick;
}