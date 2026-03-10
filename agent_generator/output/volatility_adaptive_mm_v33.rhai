let initialized = false;
let base_spread_bps = 50;
let order_amount = 100;
let lookback_ticks = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders first
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    // FOMO check - price jumped >2% in short window
    if market.history_len() > lookback_ticks {
        let past_price = market.history_price(lookback_ticks);
        if past_price > 0 {
            let change = market.price - past_price;
            let change_pct = change * 10000 / past_price;
            if change_pct > 200 {
                orders.submit_market_buy(order_amount);
                return;
            }
        }
    }
    
    // Get mid price from order book
    let mid_price;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    } else {
        mid_price = market.price;
    }
    
    // Calculate volatility-adjusted spread
    let base_vol = 50000;
    let vol_ratio;
    if base_vol > 0 {
        vol_ratio = market.std_dev * 100 / base_vol;
    } else {
        vol_ratio = 100;
    }
    
    let spread_bps;
    if vol_ratio < 50 {
        spread_bps = base_spread_bps * 60 / 100;
    } else if vol_ratio < 150 {
        spread_bps = base_spread_bps * (100 + (vol_ratio - 50)) / 100;
    } else {
        spread_bps = base_spread_bps * 300 / 100;
    }
    
    if spread_bps < 10 { spread_bps = 10; }
    if spread_bps > 500 { spread_bps = 500; }
    
    // Calculate bid/ask prices
    let half_spread = mid_price * spread_bps / 20000;
    let bid_price = mid_price - half_spread;
    let ask_price = mid_price + half_spread;
    
    // Off-by-One Pumper: add 1 micro to bid
    bid_price += 1;
    
    // Place limit orders
    if bid_price > 0 && account.cash >= bid_price * order_amount / 1000000 {
        orders.submit_limit_buy(bid_price, order_amount);
    }
    
    if ask_price > 0 && account.stock >= order_amount {
        orders.submit_limit_sell(ask_price, order_amount);
    }
}