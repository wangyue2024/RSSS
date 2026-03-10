let TRADE_AMOUNT = 1000;

fn on_tick() {
    if !market.trading_enabled {
        return;
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.tick >= market.total_ticks / 5 {
        return;
    }

    if market.history_len() >= 6 {
        let past_price = market.history_price(5);
        let current = market.price;
        let change = current - past_price;
        if change > 0 && change * 100 > past_price * 2 {
            let amount = TRADE_AMOUNT;
            let max_by_cash = account.cash / market.price;
            if amount > max_by_cash {
                amount = max_by_cash;
            }
            if amount > 0 {
                orders.submit_market_buy(amount);
            }
            return;
        }
    }

    let deviation = abs_val(market.price - market.ma_20);
    let atr_threshold = (3 * market.atr_14) / 2;

    if deviation > atr_threshold {
        if market.price > market.ma_20 {
            let amount = TRADE_AMOUNT;
            if amount > account.stock {
                amount = account.stock;
            }
            if amount > 0 {
                let base_price = if market.ask_price_0 > 0 { market.ask_price_0 } else { market.price };
                orders.submit_limit_sell(base_price, amount);
            }
        } else {
            let amount = TRADE_AMOUNT;
            let max_by_cash = account.cash / market.price;
            if amount > max_by_cash {
                amount = max_by_cash;
            }
            if amount > 0 {
                let base_price = if market.bid_price_0 > 0 { market.bid_price_0 } else { market.price };
                let price = base_price + 1;
                orders.submit_limit_buy(price, amount);
            }
        }
    }
}