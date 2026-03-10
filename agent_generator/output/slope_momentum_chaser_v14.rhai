let initialized = false;
let lot_size = 0;
let last_trade_was_loss = false;
let last_slope = 0;
let slope_window = 20;
let SLOPE_THRESHOLD = 150;
let ACCEL_THRESHOLD = 30;
let STD_DEV_THRESHOLD = 50000;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_lot = account.total_equity * 5 / 100;
        if max_lot > 0 {
            lot_size = rng.rand_int(1, max_lot);
        } else {
            lot_size = 100;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > STD_DEV_THRESHOLD {
        return;
    }
    
    let history_len = market.history_len();
    if history_len < slope_window {
        return;
    }
    
    let prices = [];
    let j = 0;
    while j < slope_window {
        prices.push(market.history_price(j));
        j += 1;
    }
    
    let current_slope = arr_slope(prices);
    let acceleration = current_slope - last_slope;
    last_slope = current_slope;
    
    if account.stock > 0 && current_slope < 0 {
        if market.price < account.avg_cost {
            last_trade_was_loss = true;
        } else {
            last_trade_was_loss = false;
        }
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if last_trade_was_loss {
        lot_size = lot_size * 2;
        let max_lot = account.total_equity * 5 / 100;
        if lot_size > max_lot {
            lot_size = max_lot;
        }
        last_trade_was_loss = false;
    }
    
    if current_slope > SLOPE_THRESHOLD && acceleration > ACCEL_THRESHOLD && account.stock == 0 {
        if lot_size < 1 {
            lot_size = 1;
        }
        let max_shares = account.cash / market.price;
        let buy_amount = lot_size;
        if buy_amount > max_shares {
            buy_amount = max_shares;
        }
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }
}