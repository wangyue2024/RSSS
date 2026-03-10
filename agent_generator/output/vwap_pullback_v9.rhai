let initialized = false;
let lot_size_percent = 0;
let entry_threshold_bp = 0;
let exit_threshold_bp = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_percent = rng.rand_int(30, 50);
        entry_threshold_bp = rng.rand_int(200, 400);
        exit_threshold_bp = rng.rand_int(50, 150);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let vwap = market.vwap;
    let price = market.price;
    let cash = account.cash;
    let stock = account.stock;
    let pos_value = stock * price;
    
    let buy_signal = price * 10000 < vwap * (10000 - entry_threshold_bp);
    let sell_signal = price * 10000 >= vwap * (10000 - exit_threshold_bp);
    
    if buy_signal && stock == 0 {
        let max_shares = (cash * lot_size_percent) / (100 * price);
        if max_shares > 0 {
            orders.submit_limit_buy(price, max_shares);
        }
    } else if sell_signal && stock > 0 {
        orders.submit_limit_sell(vwap, stock);
    }
}