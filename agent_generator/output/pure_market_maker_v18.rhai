let initialized = false;
let spread_micros = 0;
let lot_size = 0;
let std_dev_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(10_000, 50_000);
        std_dev_threshold = rng.rand_int(200_000, 500_000);
        
        let max_capital_for_trade = account.total_equity * 5 / 100;
        let max_shares_by_capital = max_capital_for_trade / market.price;
        if max_shares_by_capital > 100 {
            lot_size = rng.rand_int(50, 100);
        } else if max_shares_by_capital > 10 {
            lot_size = rng.rand_int(10, 50);
        } else {
            lot_size = 1;
        }
    }
    
    if !market.trading_enabled { return; }
    if market.price <= 0 { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > std_dev_threshold { return; }
    
    let max_capital_for_trade_current = account.total_equity * 5 / 100;
    let max_shares_by_capital_current = max_capital_for_trade_current / market.price;
    let adjusted_lot = lot_size;
    if adjusted_lot > max_shares_by_capital_current {
        adjusted_lot = max_shares_by_capital_current;
    }
    if adjusted_lot < 1 {
        adjusted_lot = 1;
    }
    
    let buy_price = market.price - spread_micros;
    let sell_price = market.price + spread_micros;
    
    if buy_price > 0 && account.cash >= buy_price * adjusted_lot {
        orders.submit_limit_buy(buy_price, adjusted_lot);
    }
    if account.stock >= adjusted_lot {
        orders.submit_limit_sell(sell_price, adjusted_lot);
    }
}