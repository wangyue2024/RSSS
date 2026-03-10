let initialized = false;
let base_lot = 100;
let current_lot = 100;
let last_trade_profit = 0;
let evaluation_tick = 0;
let last_slope_short = 0;
let last_slope_long = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        evaluation_tick = market.tick % 50;
        base_lot = rng.rand_int(80, 120);
        current_lot = base_lot;
    }
    
    let morning_session = market.tick < market.total_ticks / 5;
    if !morning_session { return; }
    
    let lazy_eval = market.tick % 50 == 0;
    if !lazy_eval { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let history_len = market.history_len();
    if history_len < 30 { return; }
    
    let short_prices = [];
    let long_prices = [];
    let j = 0;
    while j < 10 {
        if j < history_len {
            short_prices.push(market.history_price(j));
        }
        j += 1;
    }
    let k = 0;
    while k < 30 {
        if k < history_len {
            long_prices.push(market.history_price(k));
        }
        k += 1;
    }
    
    let slope_short = arr_slope(short_prices);
    let slope_long = arr_slope(long_prices);
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        if fill_side == 1 {
            let current_equity = account.total_equity;
            let price_diff = market.price - account.avg_cost;
            last_trade_profit = price_diff * account.stock;
        } else if fill_side == 0 {
            let cash_change = my_orders.fill_price(last_fill_idx) * my_orders.fill_amount(last_fill_idx);
            last_trade_profit = cash_change;
        }
        
        if last_trade_profit < 0 {
            current_lot = current_lot * 2;
            if current_lot > 1000 { current_lot = 1000; }
        } else {
            current_lot = base_lot;
        }
    }
    
    let accelerating = slope_short > 0 && slope_short > last_slope_short && slope_short > slope_long;
    let panic_sell = slope_short < 0 && last_slope_short >= 0;
    
    last_slope_short = slope_short;
    last_slope_long = slope_long;
    
    if panic_sell {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    if accelerating && slope_short > 5000 {
        let buy_amount = current_lot;
        if account.cash > market.ask_price_0 * buy_amount {
            orders.submit_limit_buy(market.ask_price_0, buy_amount);
        }
    }
}