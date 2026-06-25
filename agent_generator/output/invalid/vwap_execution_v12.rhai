let buying_active = true;
let target_shares = 0;
let accumulated_shares = 0;
let cancel_threshold = 3;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if target_shares == 0 {
        let risk_multiplier = rng.rand_int(300, 500);
        let available_cash = account.cash;
        let max_trade_cash = available_cash * risk_multiplier / 1000;
        let price = market.price;
        if price > 0 {
            target_shares = max_trade_cash / price;
            if target_shares < 1 { target_shares = 1; }
        } else {
            target_shares = 100;
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > cancel_threshold {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let fill_cnt = my_orders.fill_count();
    let j = 0;
    while j < fill_cnt {
        let side = my_orders.fill_side(j);
        if side == 0 {
            accumulated_shares += my_orders.fill_amount(j);
        }
        j += 1;
    }
    
    if buying_active {
        let remaining = target_shares - accumulated_shares;
        if remaining > 0 {
            let recent_vol = 0;
            let lookback = 10;
            let hist_len = market.history_len();
            let total_vol = 0;
            let count = 0;
            let k = 0;
            while k < lookback && k < hist_len {
                total_vol += market.history_volume(k);
                count += 1;
                k += 1;
            }
            let avg_vol = if count > 0 { total_vol / count } else { 1000 };
            
            let slice_pct = if market.volume > avg_vol * 3 / 2 {
                50
            } else if market.volume < avg_vol / 2 {
                10
            } else {
                25
            };
            
            let slice = remaining * slice_pct / 100;
            if slice < 1 && remaining > 0 { slice = 1; }
            
            if slice > 0 && market.bid_price_0 > 0 {
                orders.submit_limit_buy(market.bid_price_0, slice);
            }
        } else {
            buying_active = false;
        }
    } else {
        if account.stock > 0 && market.price > account.avg_cost && market.ask_price_0 > 0 {
            orders.submit_limit_sell(market.ask_price_0, account.stock);
        }
        
        if account.stock == 0 {
            target_shares = 0;
            accumulated_shares = 0;
            buying_active = true;
        }
    }
}