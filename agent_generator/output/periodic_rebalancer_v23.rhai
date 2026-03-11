let initialized = false;
let rebalance_counter = 0;
let base_lot_size = 100;
let current_lot_size = 100;
let last_trade_profit = 1;
let panic_threshold = 0;
let last_trade_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -1 * rng.rand_int(10_000, 100_000);
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < panic_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    if market.price != 0 && account.avg_cost != 0 {
        if market.price < account.avg_cost {
            last_trade_profit = -1;
        } else if market.price > account.avg_cost {
            last_trade_profit = 1;
        }
    }
    
    if last_trade_profit < 0 {
        current_lot_size = base_lot_size * 2;
    } else {
        current_lot_size = base_lot_size;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    rebalance_counter += 1;
    if rebalance_counter < 10 { return; }
    rebalance_counter = 0;
    
    let equity = account.total_equity;
    if equity <= 0 { return; }
    let stock_value = account.stock * market.price;
    let stock_pct = stock_value * 100 / equity;
    
    if stock_pct > 55 && account.stock > 0 {
        let target_stock_value = equity / 2;
        let excess_value = stock_value - target_stock_value;
        let shares_to_sell = excess_value / market.price;
        if shares_to_sell < 1 { return; }
        
        let rounded_price = market.price - (market.price % 1_000_000);
        let order_amount = shares_to_sell / current_lot_size * current_lot_size;
        if order_amount < 1 { order_amount = current_lot_size; }
        if order_amount > account.stock { order_amount = account.stock; }
        
        orders.submit_limit_sell(rounded_price, order_amount);
        last_trade_price = rounded_price;
    } else if stock_pct < 45 && account.cash > 0 {
        let target_stock_value = equity / 2;
        let deficit_value = target_stock_value - stock_value;
        let max_buy_value = account.cash;
        if deficit_value > max_buy_value { deficit_value = max_buy_value; }
        let shares_to_buy = deficit_value / market.price;
        if shares_to_buy < 1 { return; }
        
        let rounded_price = market.price - (market.price % 1_000_000);
        let order_amount = shares_to_buy / current_lot_size * current_lot_size;
        if order_amount < 1 { order_amount = current_lot_size; }
        
        orders.submit_limit_buy(rounded_price, order_amount);
        last_trade_price = rounded_price;
    }
}