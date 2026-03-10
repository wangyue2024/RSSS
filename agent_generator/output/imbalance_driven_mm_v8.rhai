let initialized = false;
let active_ticks = 0;
let price_history = [];
let imbalance_history = [];
let base_spread = 20000;
let order_size = 100;
let max_position = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        active_ticks = market.total_ticks * 20 / 100;
    }

    if !market.trading_enabled { return; }

    price_history.push(market.price);
    imbalance_history.push(market.order_imbalance);

    if price_history.len() > 5 {
        price_history.remove(0);
    }
    if imbalance_history.len() > 5 {
        imbalance_history.remove(0);
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.tick >= active_ticks { return; }
    if price_history.len() < 5 { return; }

    let old_price = price_history[0];
    let old_imbalance = imbalance_history[0];

    let imbalance_shift = old_imbalance * 50;
    let mid_price = old_price + imbalance_shift;

    let bid_price = mid_price - base_spread / 2;
    let ask_price = mid_price + base_spread / 2;

    let current_position = account.stock;
    let max_buy = max_position - current_position;
    let max_sell = current_position + max_position;

    if max_buy > 0 && bid_price > 0 {
        let buy_amount = order_size;
        if buy_amount > max_buy {
            buy_amount = max_buy;
        }
        if buy_amount > 0 {
            orders.submit_limit_buy(bid_price, buy_amount);
        }
    }

    if max_sell > 0 {
        let sell_amount = order_size;
        if sell_amount > max_sell {
            sell_amount = max_sell;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(ask_price, sell_amount);
        }
    }
}