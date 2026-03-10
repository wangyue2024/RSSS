let initialized = false;
let risk_percent = 0;
let stop_loss_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_percent = rng.rand_int(25, 50);
        stop_loss_ticks = rng.rand_int(3, 8);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let position = account.stock;
    let avg_cost = account.avg_cost;
    let cash = account.cash;
    let price = market.price;
    let high_20 = market.high_20;
    
    if position > 0 && avg_cost > 0 {
        let stop_price = avg_cost - stop_loss_ticks * 10000;
        if price < stop_price {
            orders.submit_market_sell(position);
            return;
        }
    }
    
    if price > high_20 && high_20 > 0 && cash > 0 {
        let max_trade_cash = cash * risk_percent / 100;
        let shares_to_buy = max_trade_cash / price;
        if shares_to_buy > 0 {
            orders.submit_market_buy(shares_to_buy);
        }
    }
}