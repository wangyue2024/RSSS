let initialized = false;
let spread_micros = 0;
let lot_pct = 0;
let last_cancel_tick = -1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(500, 3000);
        lot_pct = rng.rand_int(30, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    if current_tick - last_cancel_tick > 5 {
        last_cancel_tick = current_tick;
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }
    
    let mid_price = market.price;
    if mid_price == 0 { return; }
    
    let bid_price = mid_price - spread_micros + 1;
    let ask_price = mid_price + spread_micros;
    
    let max_buy_shares = (account.cash * lot_pct) / (100 * ask_price);
    if max_buy_shares > 0 && bid_price > 0 {
        orders.submit_limit_buy(bid_price, max_buy_shares);
    }
    
    let max_sell_shares = (account.stock * lot_pct) / 100;
    if max_sell_shares > 0 {
        orders.submit_limit_sell(ask_price, max_sell_shares);
    }
}