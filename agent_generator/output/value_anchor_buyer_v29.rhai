let initialized = false;
let fair_value = 0;
let max_position_size = 0;
let last_prices = [];
let strategy_active = true;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        
        let total_capital = account.total_equity;
        max_position_size = total_capital * 5 / 100;
    }
    
    if !market.trading_enabled { return; }
    
    last_prices.push(market.price);
    if last_prices.len() > 5 {
        last_prices.remove(0);
    }
    
    if last_prices.len() < 5 { return; }
    
    let delayed_price = last_prices[0];
    let current_tick = market.tick;
    
    if market.std_dev > (market.price * 3 / 100) {
        strategy_active = false;
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    } else {
        strategy_active = true;
    }
    
    if !strategy_active { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let new_pending_count = my_orders.pending_count();
    if new_pending_count > 0 { return; }
    
    if delayed_price >= fair_value { return; }
    
    let available_cash = account.cash;
    let current_inventory = account.stock;
    let avg_cost = account.avg_cost;
    
    let buy_amount;
    if delayed_price < fair_value * 90 / 100 {
        buy_amount = max_position_size * 8 / 100;
    } else if delayed_price < fair_value * 95 / 100 {
        buy_amount = max_position_size * 4 / 100;
    } else {
        buy_amount = max_position_size * 2 / 100;
    }
    
    let shares_to_buy = buy_amount / delayed_price;
    if shares_to_buy <= 0 { return; }
    
    if available_cash < shares_to_buy * delayed_price { return; }
    
    if shares_to_buy > 0 {
        orders.submit_limit_buy(delayed_price, shares_to_buy);
    }
}