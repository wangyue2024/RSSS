let initialized = false;
let personality = 0;
let base_lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        personality = rng.rand_int(0, 1);
        
        if personality == 0 {
            let max_capital_5_percent = account.total_equity * 5 / 100;
            let max_shares = max_capital_5_percent / market.price;
            if max_shares < 1 {
                base_lot_size = 1;
            } else {
                base_lot_size = rng.rand_int(1, max_shares);
            }
        } else {
            let max_cash_50_percent = account.cash * 50 / 100;
            let max_shares = max_cash_50_percent / market.price;
            if max_shares < 1 {
                base_lot_size = 1;
            } else {
                base_lot_size = rng.rand_int(1, max_shares);
            }
        }
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if personality == 0 {
        if market.std_dev * 100 > 200 * market.price {
            return;
        }
    }
    
    let current_lot_size = base_lot_size;
    
    let spread = market.high_20 - market.low_20;
    if spread * 10000 / market.price < 50 {
        current_lot_size = current_lot_size * 2;
    }
    
    if current_lot_size < 1 {
        return;
    }
    
    let offset = market.price / 10000;
    let buy_price = market.low_20 + offset;
    let sell_price = market.high_20 - offset;
    
    if buy_price < sell_price {
        if account.cash >= buy_price * current_lot_size {
            orders.submit_limit_buy(buy_price, current_lot_size);
        }
        
        if account.stock >= current_lot_size {
            orders.submit_limit_sell(sell_price, current_lot_size);
        }
    }
}