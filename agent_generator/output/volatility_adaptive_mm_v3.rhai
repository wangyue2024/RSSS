let initialized = false;
let base_spread = 0;
let vol_multiplier = 0;
let min_spread = 0;
let max_spread = 0;
let order_size = 0;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(2_000, 10_000);
        vol_multiplier = rng.rand_int(2, 10);
        min_spread = rng.rand_int(1_000, 3_000);
        max_spread = rng.rand_int(50_000, 200_000);
        order_size = rng.rand_int(50, 200);
        panic_threshold = -rng.rand_int(10_000, 50_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl <= panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let volatility = market.std_dev;
    
    let raw_spread = base_spread + (volatility * vol_multiplier) / 100;
    let spread = clamp_val(raw_spread, min_spread, max_spread);
    
    let half_spread = spread / 2;
    let bid_price = mid_price - half_spread;
    let ask_price = mid_price + half_spread;
    
    if bid_price > 0 {
        let max_buy = account.cash / bid_price;
        let buy_amount = if order_size < max_buy { order_size } else { max_buy };
        if buy_amount > 0 {
            orders.submit_limit_buy(bid_price, buy_amount);
        }
    }
    
    if account.stock > 0 && ask_price > account.avg_cost {
        let sell_amount = if order_size < account.stock { order_size } else { account.stock };
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}