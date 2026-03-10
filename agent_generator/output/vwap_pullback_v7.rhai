let initialized = false;
let threshold_bp = 0;
let target_bp = 0;
let max_position_frac = 0;
let min_pullback_bp = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        threshold_bp = rng.rand_int(80, 150);
        target_bp = rng.rand_int(30, 80);
        max_position_frac = rng.rand_int(30, 50);
        min_pullback_bp = rng.rand_int(40, 100);
    }
    
    if !market.trading_enabled { return; }
    if market.tick >= market.total_ticks / 5 { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let vwap = market.vwap;
    let price = market.price;
    let cash = account.cash;
    let stock_held = account.stock;
    let equity = account.total_equity;
    
    if vwap == 0 { return; }
    
    let diff_bp = (vwap - price) * 10000 / vwap;
    
    if stock_held == 0 && diff_bp >= threshold_bp {
        let buy_amount = (cash * max_position_frac / 100) / price;
        if buy_amount > 0 {
            orders.submit_limit_buy(price, buy_amount);
        }
    } else if stock_held > 0 && diff_bp <= min_pullback_bp {
        let sell_price = account.avg_cost * (10000 + target_bp) / 10000;
        if sell_price > 0 {
            orders.submit_limit_sell(sell_price, stock_held);
        }
    }
}