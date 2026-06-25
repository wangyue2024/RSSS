let initialized = false;
let lot_size = 0;
let rebalance_interval = 10;
let last_rebalance = -10;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_lot_value = account.total_equity * 5 / 100;
        if market.price > 0 {
            let max_shares = max_lot_value / market.price;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
            }
        }
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;
    let tick_diff = current_tick - last_rebalance;

    if tick_diff >= rebalance_interval {
        last_rebalance = current_tick;

        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }

        let volatility_threshold = market.price * 5 / 100;
        if market.std_dev > volatility_threshold {
            return;
        }

        let stock_value = account.stock * market.price;
        let total = account.total_equity;
        if total == 0 { return; }

        let stock_pct = stock_value * 100 / total;

        if stock_pct > 55 {
            let target_value = total * 50 / 100;
            let excess_value = stock_value - target_value;
            let shares_to_sell = excess_value / market.price;
            let sell_amount = shares_to_sell;
            if sell_amount > lot_size && lot_size > 0 {
                sell_amount = lot_size;
            }
            if sell_amount > 0 && market.bid_price_0 > 0 {
                orders.submit_limit_sell(market.bid_price_0, sell_amount);
            }
        } else if stock_pct < 45 {
            let target_value = total * 50 / 100;
            let deficit_value = target_value - stock_value;
            let shares_to_buy = deficit_value / market.price;
            let buy_amount = shares_to_buy;
            if buy_amount > lot_size && lot_size > 0 {
                buy_amount = lot_size;
            }
            let max_affordable = account.cash / market.ask_price_0;
            if buy_amount > max_affordable {
                buy_amount = max_affordable;
            }
            if buy_amount > 0 && market.ask_price_0 > 0 {
                orders.submit_limit_buy(market.ask_price_0, buy_amount);
            }
        }
    }
}