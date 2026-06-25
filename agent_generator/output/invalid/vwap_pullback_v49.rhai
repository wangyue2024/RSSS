let initialized = false;
let vwap_threshold = 0;
let max_position_pct = 0;
let lot_size = 0;
let vol_threshold = 0;
let order_ticks_waited = {};

fn on_tick() {
    if !initialized {
        initialized = true;
        vwap_threshold = rng.rand_int(10, 50);
        max_position_pct = rng.rand_int(10, 50);
        vol_threshold = rng.rand_int(100_000, 300_000);
    }
    
    if !market.trading_enabled { return; }
    
    if market.std_dev > vol_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let current_price = market.price;
    let vwap = market.vwap;
    let vwap_diff_pct = (vwap - current_price) * 10000 / vwap;
    
    let max_shares_value = account.total_equity * max_position_pct / 10000;
    if lot_size == 0 {
        lot_size = max_shares_value / current_price;
        if lot_size < 100 {
            lot_size = 100;
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        let age = market.tick - placed_tick;
        
        if age > 3 {
            orders.submit_cancel(oid);
        } else if !order_ticks_waited.has(oid) {
            order_ticks_waited[oid] = 1;
        } else {
            order_ticks_waited[oid] = order_ticks_waited[oid] + 1;
        }
        i += 1;
    }
    
    for oid in order_ticks_waited.keys() {
        if !my_orders.pending_count().map(|i| my_orders.pending_id(i)).contains(oid) {
            order_ticks_waited.remove(oid);
        }
    }
    
    let total_shares = account.stock;
    
    if total_shares == 0 {
        if vwap_diff_pct > vwap_threshold {
            let target_buy_price = current_price + 5000;
            if target_buy_price < vwap {
                orders.submit_limit_buy(target_buy_price, lot_size);
            } else {
                orders.submit_limit_buy(vwap - 1000, lot_size);
            }
        }
    } else {
        if current_price >= vwap {
            orders.submit_limit_sell(vwap, total_shares);
        } else if vwap_diff_pct < 0 {
            let sell_price = vwap - 5000;
            if sell_price > current_price {
                orders.submit_limit_sell(sell_price, total_shares);
            }
        }
    }
}