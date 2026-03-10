let initialized = false;
let target_shares = 100000;
let base_slice = 500;
let slice_history = [];
let order_ages = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        let seed = rng.rand_int(80, 120);
        target_shares = target_shares * seed / 100;
        base_slice = base_slice * seed / 100;
    }
    
    if !market.trading_enabled { return; }
    
    // High-Frequency Canceler: Cancel orders older than 3 ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Update volume history
    if slice_history.len() >= 20 {
        slice_history.remove(0);
    }
    slice_history.push(market.volume);
    
    // Calculate volume ratio (current vs average)
    let vol_ratio = 10000;
    if slice_history.len() > 0 {
        let total = 0;
        let idx = 0;
        while idx < slice_history.len() {
            total += slice_history[idx];
            idx += 1;
        }
        let avg_vol = total / slice_history.len();
        if avg_vol > 0 {
            vol_ratio = market.volume * 10000 / avg_vol;
        }
    }
    
    // Calculate dynamic slice size
    let dynamic_slice = base_slice * vol_ratio / 10000;
    let slice_size = clamp_val(dynamic_slice, base_slice / 2, base_slice * 2);
    
    // Calculate remaining shares to buy
    let current_position = account.stock;
    let remaining = target_shares - current_position;
    
    // Stubborn Holder: Only consider selling if above avg cost
    if current_position > 0 && market.price > account.avg_cost {
        let sell_size = current_position * 10 / 100;
        if sell_size > 0 {
            let ask_price = market.ask_price_0;
            if ask_price == 0 {
                ask_price = market.price * 101 / 100;
            }
            orders.submit_limit_sell(ask_price, sell_size);
        }
    }
    
    // Buy logic
    if remaining > 0 {
        let buy_amount = clamp_val(slice_size, 1, remaining);
        if account.cash > market.price * buy_amount {
            let bid_price = market.bid_price_0;
            if bid_price == 0 {
                bid_price = market.price * 99 / 100;
            } else {
                bid_price = bid_price + 100;
            }
            orders.submit_limit_buy(bid_price, buy_amount);
        }
    }
}