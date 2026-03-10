let initialized = false;
let base_lot_size = 0;
let risk_factor = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(5000, 20000);
        risk_factor = rng.rand_int(40, 60);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.price <= 0 { return; }
    
    let volatility = market.std_dev;
    let base_spread = 5000;
    let spread_adjustment = volatility * 3 / 2;
    let dynamic_spread = base_spread + spread_adjustment;
    let half_spread = dynamic_spread / 2;
    
    let mid_price = market.price;
    let bid_price_raw = mid_price - half_spread;
    let ask_price_raw = mid_price + half_spread;
    
    let bid_price = bid_price_raw + 1;
    let ask_price = ask_price_raw;
    
    let cash_available = account.cash;
    let stock_available = account.stock;
    
    let max_buy_shares = cash_available / ask_price;
    let buy_shares = max_buy_shares * risk_factor / 100;
    if buy_shares > base_lot_size {
        buy_shares = base_lot_size;
    }
    
    let sell_shares = stock_available * risk_factor / 100;
    if sell_shares > base_lot_size {
        sell_shares = base_lot_size;
    }
    
    if buy_shares > 0 && bid_price > 0 {
        orders.submit_limit_buy(bid_price, buy_shares);
    }
    
    if sell_shares > 0 && ask_price > 0 {
        orders.submit_limit_sell(ask_price, sell_shares);
    }
}