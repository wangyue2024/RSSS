let initialized = false;
let risk_factor = 0;
let base_spread = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        risk_factor = rng.rand_int(35, 50);
        base_spread = rng.rand_int(1500, 3000);
    }
    
    if market.tick % 50 != 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.bid_price_0 <= 0 || market.ask_price_0 <= 0 { return; }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let imbalance = market.order_imbalance;
    let imbalance_shift = imbalance * 50;
    
    let spread_adjust = if imbalance > 5000 {
        base_spread * 120 / 100
    } else if imbalance < -5000 {
        base_spread * 120 / 100
    } else {
        base_spread
    };
    
    let my_bid = mid_price - (spread_adjust / 2) + imbalance_shift;
    let my_ask = mid_price + (spread_adjust / 2) + imbalance_shift;
    
    if my_bid <= 0 || my_ask <= my_bid { return; }
    
    let max_cash_use = account.cash * risk_factor / 100;
    let buy_shares = max_cash_use / my_bid;
    
    if buy_shares > 0 {
        orders.submit_limit_buy(my_bid, buy_shares);
    }
    
    let sell_shares = account.stock;
    if sell_shares > 0 {
        orders.submit_limit_sell(my_ask, sell_shares);
    }
}