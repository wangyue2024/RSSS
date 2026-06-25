let initialized = false;
let last_rebalance_tick = -10;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_rebalance_tick = market.tick - 10;
    }

    if !market.trading_enabled { return; }

    let ticks_since_rebalance = market.tick - last_rebalance_tick;

    if ticks_since_rebalance >= 10 {
        last_rebalance_tick = market.tick;

        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }

        let current_price = market.price;
        let stock_value = account.stock * current_price;
        let total_eq = account.total_equity;

        let target_stock_value = total_eq * 50 / 100;
        let upper_threshold = total_eq * 55 / 100;
        let lower_threshold = total_eq * 45 / 100;

        let round_price = ((current_price + 500_000) / 1_000_000) * 1_000_000;

        if stock_value > upper_threshold && account.stock > 0 {
            let value_to_sell = stock_value - target_stock_value;
            let shares_to_sell = value_to_sell / current_price;
            if shares_to_sell < 1 {
                shares_to_sell = 1;
            }
            if shares_to_sell > account.stock {
                shares_to_sell = account.stock;
            }
            if shares_to_sell > 0 {
                orders.submit_limit_sell(round_price, shares_to_sell);
            }
        } else if stock_value < lower_threshold {
            let value_to_buy = target_stock_value - stock_value;
            let shares_to_buy = value_to_buy / current_price;
            if shares_to_buy < 1 {
                shares_to_buy = 1;
            }
            let max_affordable = account.cash / round_price;
            if shares_to_buy > max_affordable {
                shares_to_buy = max_affordable;
            }
            if shares_to_buy > 0 {
                orders.submit_limit_buy(round_price, shares_to_buy);
            }
        }
    }
}