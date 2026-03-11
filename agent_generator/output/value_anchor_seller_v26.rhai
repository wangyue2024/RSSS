let initialized = false;
let fair_value_micros = 0;
let panic_threshold = 0;
let small_sell_amount = 100;
let aggressive_sell_amount = 500;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value_micros = 100_000_000 + rng.rand_int(-5_000_000, 5_000_000);
        panic_threshold = -1 * rng.rand_int(10_000_000, 30_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let current_price = market.price;
    
    if current_price > fair_value_micros * 110 / 100 {
        let sell_qty = aggressive_sell_amount;
        if sell_qty > account.stock {
            sell_qty = account.stock;
        }
        if sell_qty > 0 {
            orders.submit_limit_sell(current_price, sell_qty);
        }
    } else if current_price > fair_value_micros * 105 / 100 {
        let sell_qty = small_sell_amount;
        if sell_qty > account.stock {
            sell_qty = account.stock;
        }
        if sell_qty > 0 {
            orders.submit_limit_sell(current_price, sell_qty);
        }
    }
}