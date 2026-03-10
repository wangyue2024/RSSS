let initialized = false;
let lot_size = 0;
let decision_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(50000, 200000);
        decision_tick = rng.rand_int(0, 49);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick % 50 != decision_tick {
        return;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.history_len() < 2 {
        return;
    }
    
    let current_price = market.price;
    let prev_price = market.history_price(1);
    
    if current_price < prev_price {
        let bid_price = current_price - 1000;
        bid_price = bid_price + 1;
        
        let max_by_cash = account.cash * 50 / 100;
        let max_shares = max_by_cash / bid_price;
        if max_shares < 1 { return; }
        
        let shares_to_buy = lot_size;
        if shares_to_buy > max_shares {
            shares_to_buy = max_shares;
        }
        
        if shares_to_buy > 0 && bid_price > 0 {
            orders.submit_limit_buy(bid_price, shares_to_buy);
        }
    } else if current_price > prev_price {
        let ask_price = current_price + 1000;
        ask_price = ask_price - 1;
        
        let max_by_stock = account.stock * 50 / 100;
        let shares_to_sell = lot_size;
        if shares_to_sell > max_by_stock {
            shares_to_sell = max_by_stock;
        }
        
        if shares_to_sell > 0 && ask_price > 0 {
            orders.submit_limit_sell(ask_price, shares_to_sell);
        }
    }
}