let initialized = false;
let threshold_pct = 0;
let max_std_dev_pct = 0;
let cash_for_trade = 0;

fn on_tick() {
    if !initialized {
        threshold_pct = rng.rand_int(80, 120);
        max_std_dev_pct = rng.rand_int(200, 300);
        let trade_pct = rng.rand_int(100, 500);
        cash_for_trade = account.total_equity * trade_pct / 10000;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev * 10000 > market.price * max_std_dev_pct {
        return;
    }
    
    if account.stock == 0 {
        let price = market.price;
        let vwap = market.vwap;
        if price * 10000 < vwap * (10000 - threshold_pct) {
            let amount = cash_for_trade / price;
            if amount > 0 {
                orders.submit_limit_buy(price, amount);
            }
        }
    } else {
        let price = market.price;
        let avg_cost = account.avg_cost;
        if price > avg_cost {
            orders.submit_limit_sell(price, account.stock);
        }
    }
}