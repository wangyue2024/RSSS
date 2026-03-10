let initialized = false;
let stop_loss_threshold = 0;
let slope_window = 20;
let panic_flag = false;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        price - remainder + 1_000_000
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = rng.rand_int(-50_000, -10_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        panic_flag = true;
        return;
    }
    
    if panic_flag && account.stock == 0 {
        panic_flag = false;
    }
    
    if market.history_len() < slope_window { return; }
    
    let prices = [];
    let j = 0;
    while j < slope_window {
        prices.push(market.history_price(j));
        j += 1;
    }
    let slope_val = arr_slope(prices);
    
    if slope_val > 50000 && account.stock < 1000 && account.cash > 10_000_000 && !panic_flag {
        let base_price = round_to_dollar(market.price);
        let bid_price = base_price + 1;
        let max_shares = (account.cash / bid_price) * 2 / 10;
        let buy_amount = clamp_val(max_shares, 1, 100);
        orders.submit_limit_buy(bid_price, buy_amount);
    }
    
    if slope_val < -10000 && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }
}