let initialized = false;
let morning_end_tick = 0;
let lot_size = 0;
let volatility_threshold = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        morning_end_tick = market.total_ticks * 20 / 100;
        volatility_threshold = market.price * 50 / 1000;
        let max_lot_value = account.total_equity * 5 / 100;
        let shares_affordable = max_lot_value / market.price;
        if shares_affordable > 0 {
            lot_size = rng.rand_int(1, shares_affordable);
        } else {
            lot_size = 1;
        }
        initialized = true;
    }
    
    if market.tick >= morning_end_tick { return; }
    
    if market.std_dev > volatility_threshold { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if market.bid_price_0 == 0 || market.ask_price_0 == 0 { return; }
    
    let spread = market.ask_price_0 - market.bid_price_0;
    let shift = spread * market.order_imbalance / 100;
    
    let base_bid = market.bid_price_0 + shift;
    let base_ask = market.ask_price_0 + shift;
    
    let bid_price = base_bid;
    let ask_price = base_ask;
    
    if bid_price <= 0 { bid_price = 1; }
    if ask_price <= bid_price { ask_price = bid_price + 1; }
    
    let max_buy_shares = account.cash / bid_price;
    let buy_shares = if lot_size < max_buy_shares { lot_size } else { max_buy_shares };
    if buy_shares > 0 {
        orders.submit_limit_buy(bid_price, buy_shares);
    }
    
    if ask_price > account.avg_cost && account.stock > 0 {
        let sell_shares = if lot_size < account.stock { lot_size } else { account.stock };
        if sell_shares > 0 {
            orders.submit_limit_sell(ask_price, sell_shares);
        }
    }
}