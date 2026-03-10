let initialized = false;
let panic_threshold = 0;
let vol_threshold = 0;
let price_threshold = 0;
let hunting_mode = 0;
let target_buy_price = 0;
let sell_amount = 0;
let attack_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(500000, 2000000);
        vol_threshold = rng.rand_int(5000, 25000);
        price_threshold = rng.rand_int(10000, 50000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        hunting_mode = 0;
        return;
    }
    
    if hunting_mode == 1 {
        if market.price <= target_buy_price || market.tick - attack_tick > 20 {
            let buy_amount = account.cash / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            hunting_mode = 0;
        }
        return;
    }
    
    let total_bid_vol = market.bid_vol_0 + market.bid_vol_1 + market.bid_vol_2 + market.bid_vol_3 + market.bid_vol_4;
    let avg_bid_price = (market.bid_price_0 * market.bid_vol_0 + market.bid_price_1 * market.bid_vol_1 + 
                         market.bid_price_2 * market.bid_vol_2 + market.bid_price_3 * market.bid_vol_3 + 
                         market.bid_price_4 * market.bid_vol_4) / (total_bid_vol + 1);
    
    if total_bid_vol > vol_threshold && abs_val(market.price - avg_bid_price) < price_threshold {
        sell_amount = total_bid_vol * 70 / 100;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
            hunting_mode = 1;
            target_buy_price = market.price * 98 / 100;
            attack_tick = market.tick;
        }
    }
}