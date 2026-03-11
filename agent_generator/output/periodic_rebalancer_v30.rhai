let initialized = false;
let panic_threshold = 0;
let last_action_tick = -100;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        panic_threshold = rng.rand_int(-10_000, -1_000);
    }
    
    let tick = market.tick;
    
    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    if tick % 50 != 0 {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let stock_value = account.stock * market.price;
    let total_eq = account.total_equity;
    
    if total_eq == 0 {
        return;
    }
    
    let stock_pct = stock_value * 100 / total_eq;
    let target_pct = 50;
    
    if stock_pct > 55 {
        let target_stock_value = total_eq * target_pct / 100;
        let excess_value = stock_value - target_stock_value;
        let sell_amount = excess_value / market.price;
        if sell_amount > 0 {
            let price = if market.bid_price_0 != 0 { market.bid_price_0 } else { market.price };
            orders.submit_limit_sell(price, sell_amount);
        }
    } else if stock_pct < 45 {
        let target_stock_value = total_eq * target_pct / 100;
        let deficit_value = target_stock_value - stock_value;
        let buy_amount = deficit_value / market.price;
        let max_affordable = account.cash / market.price;
        let trade_amount = if buy_amount > max_affordable { max_affordable } else { buy_amount };
        if trade_amount > 0 {
            let price = if market.ask_price_0 != 0 { market.ask_price_0 } else { market.price };
            orders.submit_limit_buy(price, trade_amount);
        }
    }
}