let price_history = [];
let tick_counter = 0;

fn on_tick() {
    if !market.trading_enabled {
        return;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    tick_counter += 1;

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    if tick_counter % 10 != 0 || price_history.len() < 5 {
        return;
    }

    let delayed_price = price_history[0];
    let stock_value = account.stock * delayed_price;
    let total_equity_val = account.cash + stock_value;

    if total_equity_val == 0 {
        return;
    }

    let stock_percentage = stock_value * 100 / total_equity_val;

    if stock_percentage > 55 {
        if delayed_price > account.avg_cost {
            let target_stock_value = total_equity_val / 2;
            let stock_excess_value = stock_value - target_stock_value;
            if stock_excess_value <= 0 {
                return;
            }
            let sell_amount = stock_excess_value / delayed_price;
            if sell_amount <= 0 {
                return;
            }
            let rounded_price = ((delayed_price + 500_000) / 1_000_000) * 1_000_000;
            orders.submit_limit_sell(rounded_price, sell_amount);
        }
    } else if stock_percentage < 45 {
        let target_stock_value = total_equity_val / 2;
        let stock_deficit_value = target_stock_value - stock_value;
        if stock_deficit_value <= 0 {
            return;
        }
        let buy_amount = stock_deficit_value / delayed_price;
        let max_affordable = account.cash / delayed_price;
        if buy_amount > max_affordable {
            buy_amount = max_affordable;
        }
        if buy_amount <= 0 {
            return;
        }
        let rounded_price = ((delayed_price + 500_000) / 1_000_000) * 1_000_000;
        orders.submit_limit_buy(rounded_price, buy_amount);
    }
}