let initialized = false;
let lot_size = 0;
let dip_threshold = 0;
let max_std_dev = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_cap = account.total_equity * 5 / 100;
        let max_shares = five_percent_cap / market.price;
        if max_shares > 0 {
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 1;
        }
        dip_threshold = rng.rand_int(20000, 50000);
        max_std_dev = rng.rand_int(50000, 150000);
    }
    
    if !market.trading_enabled { 
        return; 
    }
    
    if market.std_dev > max_std_dev {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let price = market.price;
    let vwap = market.vwap;
    let price_vwap_diff = vwap - price;
    
    if price_vwap_diff > 0 && price_vwap_diff * 1_000_000 / vwap > dip_threshold && account.stock == 0 {
        let buy_price = price * 998 / 1000;
        orders.submit_limit_buy(buy_price, lot_size);
    }
    
    if account.stock > 0 && price >= vwap {
        orders.submit_market_sell(account.stock);
    }
}