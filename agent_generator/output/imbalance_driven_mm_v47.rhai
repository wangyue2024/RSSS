let initialized = false;
let panic_threshold = 0;
let lot_size = 0;
let max_std_dev = 0;
let base_spread = 0;
let imbalance_mult = 0;
let spread_mult = 0;

fn on_tick() {
    if !initialized {
        panic_threshold = rng.rand_int(-200_000, -50_000);
        max_std_dev = rng.rand_int(300_000, 600_000);
        base_spread = rng.rand_int(2_000, 10_000);
        imbalance_mult = rng.rand_int(500, 2_000);
        spread_mult = rng.rand_int(50, 200);
        
        let max_cap = account.total_equity * 5 / 100;
        let max_shares = max_cap / market.price;
        if max_shares > 0 {
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 1;
        }
        
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if market.std_dev > max_std_dev { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if lot_size <= 0 { return; }
    
    let imbalance = market.order_imbalance;
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    
    let price_adjust = imbalance * imbalance_mult / 1000;
    let adj_mid = mid_price + price_adjust;
    
    let volatility_spread = market.std_dev * spread_mult / 10000;
    let total_spread = base_spread + volatility_spread;
    let half_spread = total_spread / 2;
    
    let bid_price = adj_mid - half_spread + 1;
    let ask_price = adj_mid + half_spread;
    
    if bid_price < 1 { bid_price = 1; }
    if ask_price < 1 { ask_price = 1; }
    if ask_price <= bid_price { ask_price = bid_price + 1; }
    
    if account.cash >= bid_price * lot_size {
        orders.submit_limit_buy(bid_price, lot_size);
    }
    
    if account.stock >= lot_size {
        orders.submit_limit_sell(ask_price, lot_size);
    }
}