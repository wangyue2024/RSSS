let initialized = false;
let lot_size = 0;
let slope_lookback = 20;
let momentum_threshold = 25000;
let panic_threshold = -15000;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_capital_5pct = account.total_equity * 5 / 100;
        if max_capital_5pct > 0 && market.price > 0 {
            let max_shares = max_capital_5pct / market.price;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
            } else {
                lot_size = 1;
            }
        }
    }
    
    if !market.trading_enabled { return; }
    
    let risk_threshold = market.price * 2 / 100;
    if market.std_dev > risk_threshold {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let old_orders = [];
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(j);
        if market.tick - placed_tick >= 3 {
            old_orders.push(my_orders.pending_id(j));
        }
        j += 1;
    }
    for oid in old_orders {
        orders.submit_cancel(oid);
    }
    
    if market.history_len() < slope_lookback { return; }
    
    let price_history = [];
    let k = 0;
    while k < slope_lookback {
        price_history.push(market.history_price(k));
        k += 1;
    }
    let current_slope = math.slope(price_history);
    
    if current_slope < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if current_slope > momentum_threshold {
        if account.cash > market.price && lot_size > 0 {
            let has_buy_pending = false;
            let pending_c = my_orders.pending_count();
            let m = 0;
            while m < pending_c {
                if my_orders.pending_side(m) == 0 {
                    has_buy_pending = true;
                    break;
                }
                m += 1;
            }
            if !has_buy_pending {
                let buy_price = market.ask_price_0;
                orders.submit_limit_buy(buy_price, lot_size);
            }
        }
    }
}