let initialized = false;
let risk_multiplier = 0;
let base_position = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_multiplier = rng.rand_int(25, 50);
        base_position = rng.rand_int(100, 500);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let range_width = market.high_20 - market.low_20;
    let spread_threshold = 50000;
    let pos_multiplier = 1;
    
    if range_width < spread_threshold {
        pos_multiplier = 2;
    }
    
    let max_shares_cash = (account.cash * risk_multiplier) / (100 * market.price);
    let max_shares = if base_position > max_shares_cash { max_shares_cash } else { base_position };
    let position = max_shares * pos_multiplier;
    
    if position < 1 { return; }
    
    let buy_price = market.low_20 + 1;
    let sell_price = market.high_20 - 1;
    
    if market.low_20 > 0 && buy_price > 0 {
        orders.submit_limit_buy(buy_price, position);
    }
    
    if market.high_20 > 0 && sell_price > buy_price && account.stock >= position {
        orders.submit_limit_sell(sell_price, position);
    }
}