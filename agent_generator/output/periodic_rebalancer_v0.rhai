let price_history = [];
let last_action_tick = 0;
let delayed_price = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    let current_tick = market.tick;

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    let count_pending = my_orders.pending_count();
    let i = 0;
    while i < count_pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if price_history.len() == 5 {
        delayed_price = price_history[0];
    } else {
        delayed_price = market.price;
    }

    let rebalance_interval = 10;
    if current_tick - last_action_tick >= rebalance_interval {
        last_action_tick = current_tick;

        let stock_value = account.stock * delayed_price;
        let total_equity_val = account.cash + stock_value;

        if total_equity_val <= 0 { return; }

        let stock_percentage = (stock_value * 10000) / total_equity_val;

        let target_percentage = 5000;
        let upper_band = 5500;
        let lower_band = 4500;

        let order_price_offset = 1000;
        let buy_price = delayed_price + order_price_offset;
        let sell_price = delayed_price - order_price_offset;

        if stock_percentage > upper_band && sell_price > 0 {
            let target_stock_value = (total_equity_val * target_percentage) / 10000;
            let excess_value = stock_value - target_stock_value;
            let shares_to_sell = excess_value / delayed_price;
            if shares_to_sell > 0 && account.stock >= shares_to_sell {
                orders.submit_limit_sell(sell_price, shares_to_sell);
            }
        } else if stock_percentage < lower_band {
            let target_stock_value = (total_equity_val * target_percentage) / 10000;
            let deficit_value = target_stock_value - stock_value;
            let shares_to_buy = deficit_value / delayed_price;
            let max_affordable = account.cash / buy_price;
            let final_buy_amount = shares_to_buy;
            if final_buy_amount > max_affordable {
                final_buy_amount = max_affordable;
            }
            if final_buy_amount > 0 && buy_price > 0 {
                orders.submit_limit_buy(buy_price, final_buy_amount);
            }
        }
    }
}