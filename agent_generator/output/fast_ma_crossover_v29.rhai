let initialized = false;
let personality = 0;
let lot_pct = 0;
let prev_ma5 = 0;
let prev_ma20 = 0;
let std_dev_threshold = 100_000;

fn on_tick() {
    if !initialized {
        initialized = true;
        personality = rng.rand_int(0, 1);
        if personality == 0 {
            lot_pct = rng.rand_int(25, 50);
        } else {
            lot_pct = rng.rand_int(1, 5);
        }
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let ma5 = market.ma_5;
    let ma20 = market.ma_20;
    let cross_up = ma5 > ma20 && prev_ma5 <= prev_ma20;
    let cross_down = ma5 < ma20 && prev_ma5 >= prev_ma20;
    
    if personality == 1 && market.std_dev > std_dev_threshold {
        prev_ma5 = ma5;
        prev_ma20 = ma20;
        return;
    }
    
    if cross_down && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }
    
    if cross_up && account.stock == 0 {
        let max_spend = if personality == 0 { account.cash } else { account.total_equity };
        let spend_amount = max_spend * lot_pct / 100;
        if spend_amount > 0 && market.price > 0 {
            let buy_shares = spend_amount / market.price;
            if buy_shares > 0 {
                orders.submit_market_buy(buy_shares);
            }
        }
    }
    
    prev_ma5 = ma5;
    prev_ma20 = ma20;
}