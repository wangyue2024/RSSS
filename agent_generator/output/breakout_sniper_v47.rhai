let initialized = false;
let risk_percent = 0;
let last_trade_loss = false;
let stop_offset = 0;
let lot_multiplier = 1;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_percent = rng.rand_int(30, 50);
        stop_offset = rng.rand_int(5, 20);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock > 0 {
        let stop_price = account.avg_cost - stop_offset;
        if market.price <= stop_price {
            orders.submit_market_sell(account.stock);
            if market.price < account.avg_cost {
                last_trade_loss = true;
                lot_multiplier = lot_multiplier * 2;
            } else {
                last_trade_loss = false;
                lot_multiplier = 1;
            }
            return;
        }
    }
    
    if account.stock == 0 && market.price > market.high_20 {
        let cash_to_risk = (account.cash * risk_percent) / 100;
        let base_shares = cash_to_risk / market.price;
        
        if base_shares > 0 {
            let buy_shares = base_shares * lot_multiplier;
            let bid_price = market.price + 1;
            orders.submit_limit_buy(bid_price, buy_shares);
        }
    }
}