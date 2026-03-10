let initialized = false;
let base_lot = 1000;
let current_lot = base_lot;
let threshold_bps = 100;
let position_avg_cost = 0;
let last_trade_was_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        threshold_bps = rng.rand_int(50, 150);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let vwap = market.vwap;
    let current_price = market.price;
    let price_diff = vwap - current_price;
    let threshold_value = vwap * threshold_bps / 10000;
    
    if account.stock == 0 {
        if price_diff > threshold_value && price_diff > 0 {
            let max_affordable = account.cash / current_price;
            let buy_amount = if current_lot > max_affordable { max_affordable } else { current_lot };
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
                position_avg_cost = account.avg_cost;
            }
        }
    } else {
        if current_price >= position_avg_cost {
            orders.submit_market_sell(account.stock);
            
            let profit = (current_price - position_avg_cost) * account.stock;
            last_trade_was_loss = profit < 0;
            
            if last_trade_was_loss {
                current_lot = current_lot * 2;
            } else {
                current_lot = base_lot;
            }
            position_avg_cost = 0;
        }
    }
}