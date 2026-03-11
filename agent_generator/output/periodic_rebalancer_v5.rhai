let initialized = false;
let lot_size = 0;
let tick_counter = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        let five_percent_of_capital = account.cash * 5 / 100;
        if market.price > 0 {
            let max_shares = five_percent_of_capital / market.price;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
            } else {
                lot_size = 1;
            }
        } else {
            lot_size = 1;
        }
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    tick_counter += 1;
    if tick_counter < 10 { return; }
    tick_counter = 0;
    
    let std_dev_threshold = market.price * 5 / 100;
    if market.std_dev > std_dev_threshold { return; }
    
    let stock_value = account.stock * market.price;
    let total_equity = account.cash + stock_value;
    if total_equity == 0 { return; }
    
    let stock_percentage = stock_value * 100 / total_equity;
    
    let rounded_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
    
    if stock_percentage > 55 {
        let target_stock_value = total_equity * 50 / 100;
        let value_to_sell = stock_value - target_stock_value;
        let shares_to_sell = value_to_sell / market.price;
        let sell_amount = shares_to_sell;
        if sell_amount > lot_size { sell_amount = lot_size; }
        if sell_amount > account.stock { sell_amount = account.stock; }
        if sell_amount > 0 {
            orders.submit_limit_sell(rounded_price, sell_amount);
        }
    } else if stock_percentage < 45 {
        let target_stock_value = total_equity * 50 / 100;
        let value_to_buy = target_stock_value - stock_value;
        let shares_to_buy = value_to_buy / market.price;
        let buy_amount = shares_to_buy;
        if buy_amount > lot_size { buy_amount = lot_size; }
        let max_buy_by_cash = account.cash / rounded_price;
        if buy_amount > max_buy_by_cash { buy_amount = max_buy_by_cash; }
        if buy_amount > 0 {
            orders.submit_limit_buy(rounded_price, buy_amount);
        }
    }
}