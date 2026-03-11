let price_history = [];
let last_action_tick = -50;
let stored_price = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    if market.tick % 50 != 0 || market.tick == last_action_tick { return; }
    last_action_tick = market.tick;

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if price_history.len() < 5 { return; }
    stored_price = price_history[0];

    let equity = account.total_equity;
    let stock_value = account.stock * stored_price;
    let stock_percent = stock_value * 100 / equity;

    if stock_percent > 55 {
        let target_stock_value = equity / 2;
        let excess_value = stock_value - target_stock_value;
        let shares_to_sell = excess_value / stored_price;
        if shares_to_sell > 0 && shares_to_sell <= account.stock {
            orders.submit_limit_sell(stored_price, shares_to_sell);
        }
    } else if stock_percent < 45 {
        let target_stock_value = equity / 2;
        let deficit_value = target_stock_value - stock_value;
        let shares_to_buy = deficit_value / stored_price;
        let max_affordable = account.cash / stored_price;
        if shares_to_buy > 0 && shares_to_buy <= max_affordable {
            orders.submit_limit_buy(stored_price, shares_to_buy);
        }
    }
}