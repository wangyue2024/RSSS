let initialized = false;
let target_shares = 100000;
let bought_shares = 0;
let base_lot_size = 1000;
let current_lot_size = 1000;
let last_trade_loss = false;
let avg_cost = 0;
let total_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        if target_shares <= 0 {
            target_shares = 100000;
        }
        if base_lot_size <= 0 {
            base_lot_size = 1000;
        }
        current_lot_size = base_lot_size;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fill_cnt = my_orders.fill_count();
    let has_fills = false;
    let any_loss = false;
    let j = 0;
    while j < fill_cnt {
        let fill_side = my_orders.fill_side(j);
        if fill_side == 0 {
            has_fills = true;
            let fill_price = my_orders.fill_price(j);
            let fill_amount = my_orders.fill_amount(j);
            
            let prev_avg = if bought_shares > 0 { avg_cost } else { 0 };
            let cost_before = total_cost;
            total_cost += fill_price * fill_amount;
            bought_shares += fill_amount;
            
            if bought_shares > 0 {
                avg_cost = total_cost / bought_shares;
            }
            
            if fill_price > market.price {
                any_loss = true;
            }
        }
        j += 1;
    }
    
    if has_fills {
        last_trade_loss = any_loss;
    }

    if bought_shares >= target_shares {
        return;
    }

    let lookback = 20;
    let total_vol = 0;
    let count = 0;
    let k = 0;
    while k < lookback && k < market.history_len() {
        total_vol += market.history_volume(k);
        count += 1;
        k += 1;
    }
    let avg_vol = if count > 0 { total_vol / count } else { 1000 };
    
    let high_volume = market.volume > avg_vol;
    
    let multiplier = 1;
    if high_volume {
        multiplier = multiplier * 2;
    }
    if last_trade_loss {
        multiplier = multiplier * 2;
    }
    
    current_lot_size = base_lot_size * multiplier;
    
    let remaining = target_shares - bought_shares;
    if current_lot_size > remaining {
        current_lot_size = remaining;
    }
    
    let max_by_cash = account.cash / market.price;
    if current_lot_size > max_by_cash {
        current_lot_size = max_by_cash;
    }
    
    if current_lot_size <= 0 {
        return;
    }
    
    let buy_price = market.bid_price_0;
    if buy_price > 0 && current_lot_size > 0 {
        orders.submit_limit_buy(buy_price, current_lot_size);
    }
}