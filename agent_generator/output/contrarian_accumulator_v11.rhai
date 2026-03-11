let initialized = false;
let risk_percent = 0;
let lot_size = 0;
let last_rsi = 10000;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_percent = rng.rand_int(400000, 600000);
        lot_size = rng.rand_int(20, 100);
    }
    
    if !market.trading_enabled { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_rsi = market.rsi_14;
    if current_rsi < 3000 && current_rsi > 0 && market.bid_price_0 > 0 {
        let risk_cash = account.cash * risk_percent / 1_000_000;
        let max_shares = risk_cash / market.bid_price_0;
        let shares_to_buy = if max_shares < lot_size { max_shares } else { lot_size };
        if shares_to_buy > 0 {
            let bid_price = market.bid_price_0 - 10000 + 1;
            if bid_price > 0 {
                orders.submit_limit_buy(bid_price, shares_to_buy);
            }
        }
    }
    
    if current_rsi > 7000 && account.stock > 0 && account.avg_cost > 0 && market.ask_price_0 > account.avg_cost {
        let shares_to_sell = if lot_size > account.stock { account.stock } else { lot_size };
        if shares_to_sell > 0 {
            orders.submit_limit_sell(market.ask_price_0, shares_to_sell);
        }
    }
    
    last_rsi = current_rsi;
}