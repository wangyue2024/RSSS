let initialized = false;
let target_position = 50_000;
let slice_size = 500;
let interval_ticks = 10;
let next_tick_to_trade = 0;
let accumulated_shares = 0;
let risk_multiplier = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_multiplier = rng.rand_int(1, 5);
        slice_size = slice_size * risk_multiplier;
        interval_ticks = rng.rand_int(1, 5);
        next_tick_to_trade = market.tick + interval_ticks;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick >= next_tick_to_trade && accumulated_shares < target_position {
        let remaining_to_target = target_position - accumulated_shares;
        let order_amount = slice_size;
        if order_amount > remaining_to_target {
            order_amount = remaining_to_target;
        }
        
        if order_amount > 0 {
            let cash_per_trade = account.cash * 5000 / 10000;
            let max_shares_by_cash = cash_per_trade / market.price;
            if max_shares_by_cash < order_amount {
                order_amount = max_shares_by_cash;
            }
            
            if order_amount > 0 {
                let round_price = (market.price / 1_000_000) * 1_000_000;
                let bid_price = round_price + 1;
                orders.submit_limit_buy(bid_price, order_amount);
            }
        }
        
        next_tick_to_trade = market.tick + interval_ticks;
    }
    
    let fill_count = my_orders.fill_count();
    let j = 0;
    while j < fill_count {
        let fill_side = my_orders.fill_side(j);
        if fill_side == 0 {
            accumulated_shares = accumulated_shares + my_orders.fill_amount(j);
        }
        j += 1;
    }
}