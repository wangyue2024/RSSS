let initialized = false;
let base_spread = 50_000;
let base_lot_size = 100;
let loss_streak = 0;
let last_realized_pnl = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(30_000, 70_000);
        base_lot_size = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_pnl = account.realized_pnl;
    if current_pnl < last_realized_pnl {
        loss_streak += 1;
    } else {
        loss_streak = 0;
    }
    last_realized_pnl = current_pnl;
    
    let martingale_multiplier = 1;
    let temp = loss_streak;
    while temp > 0 {
        martingale_multiplier = martingale_multiplier * 2;
        temp -= 1;
    }
    
    let lot_size = base_lot_size * martingale_multiplier;
    if lot_size < 1 { lot_size = 1; }
    
    let mid_price = market.price;
    let buy_price = mid_price - base_spread;
    let sell_price = mid_price + base_spread;
    
    if buy_price > 0 {
        orders.submit_limit_buy(buy_price, lot_size);
    }
    
    orders.submit_limit_sell(sell_price, lot_size);
}