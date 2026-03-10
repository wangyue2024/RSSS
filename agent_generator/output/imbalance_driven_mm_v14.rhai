let initialized = false;
let lot_size = 0;
let base_spread = 0;
let shift_factor = 0;
let max_shift = 0;

fn on_tick() {
    if !initialized {
        lot_size = rng.rand_int(40, 50);
        base_spread = rng.rand_int(500, 3000);
        shift_factor = rng.rand_int(10, 30);
        max_shift = rng.rand_int(1000, 5000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    if market.tick >= market.total_ticks / 5 { return; }
    if market.tick % 50 != 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let imbalance = market.order_imbalance;
    let shift = clamp_val(imbalance * shift_factor / 100, -max_shift, max_shift);
    let mid_price = market.price + shift;
    
    let bid_price = mid_price - base_spread;
    let ask_price = mid_price + base_spread;
    
    let max_buy_shares = (account.cash / 2) / ask_price;
    if max_buy_shares > 0 && ask_price > 0 {
        let buy_amount = max_buy_shares * lot_size / 100;
        if buy_amount > 0 {
            orders.submit_limit_buy(bid_price, buy_amount);
        }
    }
    
    let max_sell_shares = account.stock / 2;
    if max_sell_shares > 0 {
        let sell_amount = max_sell_shares * lot_size / 100;
        if sell_amount > 0 {
            orders.submit_limit_sell(ask_price, sell_amount);
        }
    }
}