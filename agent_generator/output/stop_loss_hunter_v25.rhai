let initialized = false;
let state = 0;
let trigger_price = 0;
let target_price = 0;
let sell_amount = 0;
let timeout_counter = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        state = 0;
    }

    if !market.trading_enabled {
        return;
    }

    let current_price = market.price;
    let cost = account.avg_cost;
    let available_stock = account.stock;

    let pct_1 = 10000;
    let pct_0_5 = 5000;
    let pct_0_2 = 2000;

    if state == 0 {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }

        let near_support = false;
        let support_level = market.low_20;
        let diff_to_support = current_price - support_level;
        if diff_to_support <= current_price * 2 / 100 && diff_to_support > 0 {
            near_support = true;
        }

        let sell_pressure = false;
        let bid_vol_sum = market.bid_vol_0 + market.bid_vol_1 + market.bid_vol_2;
        let ask_vol_sum = market.ask_vol_0 + market.ask_vol_1 + market.ask_vol_2;
        if ask_vol_sum > bid_vol_sum * 120 / 100 && market.order_imbalance < 0 {
            sell_pressure = true;
        }

        let can_sell = false;
        if current_price > cost && available_stock > 0 {
            can_sell = true;
        }

        if near_support && sell_pressure && can_sell && market.rsi_14 > 4000 {
            sell_amount = available_stock * 10 / 100;
            if sell_amount < 100 {
                sell_amount = 100;
            }
            if sell_amount > available_stock {
                sell_amount = available_stock;
            }

            orders.submit_market_sell(sell_amount);
            trigger_price = current_price;
            target_price = trigger_price * 995 / 1000;
            timeout_counter = 0;
            state = 1;
        }
    } else if state == 1 {
        timeout_counter += 1;

        if current_price <= target_price {
            let buy_amount = sell_amount * 105 / 100;
            if account.cash >= buy_amount * current_price / 1_000_000 {
                orders.submit_market_buy(buy_amount);
            } else {
                let max_buy = account.cash * 1_000_000 / current_price;
                if max_buy > 0 {
                    orders.submit_market_buy(max_buy);
                }
            }
            state = 0;
        }

        if timeout_counter > 20 {
            state = 0;
        }
    }
}