let initialized = false;
let target_shares = 0;
let slice_size = 0;
let base_volume = 0;
let trades_today = 0;
let max_slippage = 10000;
let volume_window = 20;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let max_capital = account.total_equity * 5 / 100;
        let shares_at_price = max_capital / market.price;
        if shares_at_price < 1 {
            slice_size = 1;
        } else {
            slice_size = rng.rand_int(1, shares_at_price);
        }
        
        target_shares = slice_size * rng.rand_int(2, 10);
        
        let hist_len = market.history_len();
        if hist_len > 0 {
            let sum = 0;
            let count = min(hist_len, volume_window);
            let i = 0;
            while i < count {
                sum += market.history_volume(i);
                i += 1;
            }
            base_volume = sum / count;
            if base_volume == 0 {
                base_volume = 100;
            }
        } else {
            base_volume = 100;
        }
    }
    
    if !market.trading_enabled { 
        return; 
    }
    
    let two_percent_price = market.price * 2 / 100;
    if market.std_dev > two_percent_price {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_side = my_orders.fill_side(i);
        if fill_side == 0 {
            trades_today += my_orders.fill_amount(i);
        }
        i += 1;
    }
    
    if trades_today >= target_shares {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let remaining = target_shares - trades_today;
    if remaining <= 0 {
        return;
    }
    
    let volume_ratio = market.volume * 100 / base_volume;
    let volume_multiplier = clamp_val(volume_ratio, 50, 200);
    
    let dynamic_slice = slice_size * volume_multiplier / 100;
    let order_amount = min(dynamic_slice, remaining);
    
    if order_amount < 1 {
        order_amount = 1;
    }
    
    if market.bid_price_0 > 0 {
        let bid_price = market.bid_price_0 + 1;
        let max_price = market.vwap + max_slippage;
        if bid_price <= max_price {
            orders.submit_limit_buy(bid_price, order_amount);
        }
    } else if market.ask_price_0 > 0 {
        let bid_price = market.ask_price_0 - 10000;
        if bid_price > 0 {
            orders.submit_limit_buy(bid_price, order_amount);
        }
    }
}