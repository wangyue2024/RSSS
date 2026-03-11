let initialized = false;
let last_rebalance_tick = 0;
let panic_threshold = 0;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_rebalance_tick = market.tick;
        panic_threshold = -rng.rand_int(100_000, 1_000_000);
        lot_size = account.cash * rng.rand_int(25, 50) / 100;
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let ticks_since_rebalance = market.tick - last_rebalance_tick;
    if ticks_since_rebalance < 10 { return; }
    
    last_rebalance_tick = market.tick;
    let stock_value = account.stock * market.price;
    let equity = account.total_equity;
    if equity == 0 { return; }
    let stock_pct = stock_value * 100 / equity;
    
    if stock_pct > 55 && market.price > account.avg_cost && account.stock > 0 {
        let shares_to_sell = lot_size / market.price;
        if shares_to_sell > 0 {
            let sell_shares = clamp_val(shares_to_sell, 1, account.stock);
            let sell_price = market.bid_price_0 - 50_000;
            if sell_price > account.avg_cost && sell_price > 0 {
                orders.submit_limit_sell(sell_price, sell_shares);
            }
        }
    } else if stock_pct < 45 && account.cash > 0 {
        let shares_to_buy = lot_size / market.price;
        if shares_to_buy > 0 {
            let buy_shares = clamp_val(shares_to_buy, 1, account.cash / market.price);
            let buy_price = market.ask_price_0 + 50_000;
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, buy_shares);
            }
        }
    }
}