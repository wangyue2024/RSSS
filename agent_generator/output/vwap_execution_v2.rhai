let initialized = false;
let target_total_shares = 50000;
let total_bought = 0;
let base_order_size = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_order_size = rng.rand_int(800, 1200);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Update total_bought from fills
    let fill_cnt = my_orders.fill_count();
    let j = 0;
    while j < fill_cnt {
        let fill_side = my_orders.fill_side(j);
        let fill_amt = my_orders.fill_amount(j);
        if fill_side == 0 {
            total_bought += fill_amt;
        }
        j += 1;
    }
    
    // Calculate remaining to buy
    let remaining_to_buy = target_total_shares - total_bought;
    if remaining_to_buy <= 0 {
        return;
    }
    
    // Dynamic slicing based on recent volume
    let recent_volumes = [];
    let history_len = market.history_len();
    let lookback = 5;
    let k = 0;
    while k < lookback && k < history_len {
        recent_volumes.push(market.history_volume(k));
        k += 1;
    }
    
    let avg_recent_volume = arr_mean(recent_volumes);
    let volume_factor = if avg_recent_volume > 0 {
        market.volume * 100 / avg_recent_volume
    } else {
        100
    };
    
    let dynamic_size = base_order_size * volume_factor / 100;
    let buy_amount = clamp_val(dynamic_size, 100, remaining_to_buy);
    
    // Determine bid price with off-by-one quirk
    let intended_price = if market.bid_price_0 > 0 {
        market.bid_price_0
    } else {
        market.price - 10000
    };
    
    let bid_price = intended_price + 1;
    
    // Place buy order if we have cash
    let max_affordable = account.cash / bid_price;
    if max_affordable > 0 && buy_amount > 0 {
        let final_buy_amount = if buy_amount > max_affordable { max_affordable } else { buy_amount };
        orders.submit_limit_buy(bid_price, final_buy_amount);
    }
    
    // Sell only at profit (diamond hands)
    if market.price > account.avg_cost && account.stock > 0 {
        let sell_amount = if account.stock > 1000 { 1000 } else { account.stock };
        let ask_price = if market.ask_price_0 > 0 {
            market.ask_price_0
        } else {
            market.price + 10000
        };
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}