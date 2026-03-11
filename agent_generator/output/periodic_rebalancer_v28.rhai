let initialized = false;
let panic_threshold = 0;
let tick_counter = 0;
let price_buffer = [];
let action_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(5_000, 25_000);
    }

    if !market.trading_enabled { return; }

    // Panic condition (uses current data, not delayed)
    if account.unrealized_pnl < panic_threshold {
        // Cancel all pending orders
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        // Market sell all stock
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    // Delayed reaction: store current price
    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }

    // Only proceed if we have at least 5 ticks of history
    if price_buffer.len() < 5 {
        tick_counter += 1;
        return;
    }

    // Use price from 5 ticks ago
    action_price = price_buffer[0];

    tick_counter += 1;

    // Rebalance every 10 ticks
    if tick_counter % 10 != 0 {
        return;
    }

    // Cancel existing pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Calculate current allocation using delayed price
    let stock_value = account.stock * action_price;
    let total_equity_val = account.total_equity;
    if total_equity_val == 0 { return; }

    // Calculate stock percentage (in integer percent * 100 for precision)
    let stock_percentage = (stock_value * 10_000) / total_equity_val;

    // Target range: 45% to 55% (4500 to 5500 in our scaled units)
    if stock_percentage > 5500 {
        // Stock too high: sell some
        let target_stock_value = (total_equity_val * 5_000) / 10_000;
        let excess_value = stock_value - target_stock_value;
        if excess_value <= 0 { return; }
        
        let sell_amount = excess_value / action_price;
        if sell_amount > 0 {
            // Place limit sell near delayed price (slightly below)
            let sell_price = action_price * 99_500 / 100_000;
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    } else if stock_percentage < 4500 {
        // Stock too low: buy some
        let target_stock_value = (total_equity_val * 5_000) / 10_000;
        let deficit_value = target_stock_value - stock_value;
        if deficit_value <= 0 { return; }
        
        // Check cash available
        let max_buy_by_cash = account.cash / action_price;
        let buy_amount = deficit_value / action_price;
        if buy_amount > max_buy_by_cash {
            buy_amount = max_buy_by_cash;
        }
        
        if buy_amount > 0 {
            // Place limit buy near delayed price (slightly above)
            let buy_price = action_price * 100_500 / 100_000;
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
}