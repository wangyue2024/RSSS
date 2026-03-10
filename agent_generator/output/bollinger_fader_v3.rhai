let initialized = false;
let panic_threshold = 0;
let ORDER_AMOUNT = 10;

fn round_to_dollar(price) {
    let round_unit = 1_000_000;
    ((price + round_unit / 2) / round_unit) * round_unit
}

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(10_000, 50_000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < panic_threshold {
        let stock_to_sell = account.stock;
        if stock_to_sell > 0 {
            orders.submit_market_sell(stock_to_sell);
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.ma_20 == 0 || market.std_dev == 0 { return; }
    
    let lower_band = market.ma_20 - 2 * market.std_dev;
    let upper_band = market.ma_20 + 2 * market.std_dev;
    
    let buy_price = round_to_dollar(lower_band) + 1;
    let sell_price = round_to_dollar(upper_band);
    
    if account.cash >= buy_price * ORDER_AMOUNT {
        orders.submit_limit_buy(buy_price, ORDER_AMOUNT);
    }
    
    if account.stock >= ORDER_AMOUNT {
        orders.submit_limit_sell(sell_price, ORDER_AMOUNT);
    }
}