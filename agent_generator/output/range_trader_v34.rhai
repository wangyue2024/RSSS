let initialized = false;
let lot_size = 0;
let risk_averse = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_averse = rng.rand_bool(50);
        
        if risk_averse {
            let max_capital = account.total_equity;
            let five_percent = max_capital * 5 / 100;
            let base_lot = five_percent / market.price;
            lot_size = rng.rand_int(1, base_lot);
        } else {
            let max_capital = account.cash;
            let fifty_percent = max_capital * 50 / 100;
            let base_lot = fifty_percent / market.price;
            lot_size = rng.rand_int(base_lot / 2, base_lot);
        }
        
        if lot_size < 1 { lot_size = 1; }
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if risk_averse {
        let std_dev_threshold = market.price * 5 / 100;
        if market.std_dev > std_dev_threshold {
            return;
        }
    }
    
    let spread = market.high_20 - market.low_20;
    let position_multiplier = 1000000 / (spread + 1000);
    let adjusted_lot = lot_size * position_multiplier / 1000;
    
    if adjusted_lot < 1 { return; }
    
    let offset = spread * 10 / 100;
    if offset < 1000 { offset = 1000; }
    
    let buy_price = market.low_20 + offset + 1;
    let sell_price = market.high_20 - offset;
    
    let max_buy = account.cash / buy_price;
    let max_sell = account.stock;
    
    let buy_lot = adjusted_lot;
    if buy_lot > max_buy { buy_lot = max_buy; }
    
    let sell_lot = adjusted_lot;
    if sell_lot > max_sell { sell_lot = max_sell; }
    
    if buy_lot > 0 {
        orders.submit_limit_buy(buy_price, buy_lot);
    }
    
    if sell_lot > 0 {
        orders.submit_limit_sell(sell_price, sell_lot);
    }
}