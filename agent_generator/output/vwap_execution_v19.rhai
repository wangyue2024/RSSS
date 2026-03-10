let initialized = false;
let TARGET_SHARES = 10000;
let BASE_SLICE = 100;
let volume_lookback = 20;
let buy_mode = true;
let avg_buy_price = 0;
let shares_bought = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        TARGET_SHARES = rng.rand_int(8000, 12000);
        BASE_SLICE = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let account_stock = account.stock;
    let account_cash = account.cash;
    let account_avg = account.avg_cost;
    
    if buy_mode && shares_bought >= TARGET_SHARES {
        buy_mode = false;
    }
    
    if buy_mode {
        let recent_vol = 0;
        let hist_len = market.history_len();
        let lookback = if hist_len < volume_lookback { hist_len } else { volume_lookback };
        
        let j = 0;
        while j < lookback {
            recent_vol += market.history_volume(hist_len - 1 - j);
            j += 1;
        }
        
        let avg_vol = if lookback > 0 { recent_vol / lookback } else { 1000 };
        let current_vol = market.volume;
        
        let volume_ratio = if avg_vol > 0 { 
            clamp_val(current_vol * 100 / avg_vol, 50, 200) 
        } else { 100 };
        
        let slice_size = BASE_SLICE * volume_ratio / 100;
        let remaining_to_buy = TARGET_SHARES - shares_bought;
        let buy_amount = if slice_size < remaining_to_buy { slice_size } else { remaining_to_buy };
        
        if buy_amount > 0 && market.bid_price_0 > 0 {
            let limit_price = market.bid_price_0 - 1;
            if limit_price > 0 && account_cash >= limit_price * buy_amount {
                orders.submit_limit_buy(limit_price, buy_amount);
            }
        }
    } else {
        if account_stock > 0 && current_price > account_avg {
            let sell_price = market.ask_price_0 + 1;
            if sell_price > 0 && sell_price > account_avg {
                let sell_amount = if account_stock > 100 { 100 } else { account_stock };
                orders.submit_limit_sell(sell_price, sell_amount);
            }
        }
    }
    
    let fill_cnt = my_orders.fill_count();
    let k = 0;
    while k < fill_cnt {
        let fill_side = my_orders.fill_side(k);
        let fill_amount = my_orders.fill_amount(k);
        if fill_side == 0 {
            shares_bought += fill_amount;
        }
        k += 1;
    }
}