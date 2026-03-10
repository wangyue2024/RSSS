let initialized = false;
let risk_mode = 0;
let lot_size_pct = 0;
let last_price = 0;
let avoid_trading = false;
let std_dev_threshold = 20000;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_mode = rng.rand_int(0, 1);
        
        if risk_mode == 0 {
            lot_size_pct = rng.rand_int(40, 50);
        } else {
            lot_size_pct = rng.rand_int(1, 4);
        }
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if risk_mode == 1 {
        if market.std_dev > std_dev_threshold {
            avoid_trading = true;
            return;
        } else {
            avoid_trading = false;
        }
    }
    
    if market.tick == 0 {
        last_price = market.price;
        return;
    }
    
    if last_price == 0 {
        last_price = market.price;
        return;
    }
    
    let price_change = market.price - last_price;
    last_price = market.price;
    
    if price_change == 0 {
        return;
    }
    
    let cash_available = account.cash;
    let stock_available = account.stock;
    
    if price_change < 0 {
        let buy_price = market.bid_price_0 - 1;
        if buy_price <= 0 {
            buy_price = 1;
        }
        
        let max_shares_by_cash = cash_available / buy_price;
        let target_shares = (max_shares_by_cash * lot_size_pct) / 100;
        
        if target_shares > 0 {
            orders.submit_limit_buy(buy_price, target_shares);
        }
    } else {
        let sell_price = market.ask_price_0 + 1;
        
        let max_shares_by_stock = stock_available;
        let target_shares = (max_shares_by_stock * lot_size_pct) / 100;
        
        if target_shares > 0 && stock_available > 0 {
            orders.submit_limit_sell(sell_price, target_shares);
        }
    }
}