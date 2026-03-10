let initialized = false;
let lot_size = 0;
let last_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_pct = rng.rand_int(40, 50);
        let max_shares = (account.cash * risk_pct / 100) / market.price;
        lot_size = clamp_val(max_shares, 1, 1000000);
        last_price = market.price;
        return;
    }

    if !market.trading_enabled { return; }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let price_change = market.price - last_price;
    last_price = market.price;

    if price_change < 0 {
        let base_price = market.price - 2;
        let buy_price = base_price + 1;
        let cash_available = account.cash;
        let max_buy = cash_available / buy_price;
        let buy_amount = clamp_val(lot_size, 1, max_buy);
        if buy_amount > 0 && buy_price > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    } else if price_change > 0 {
        let base_price = market.price + 2;
        let sell_price = base_price + 1;
        let sell_amount = clamp_val(lot_size, 1, account.stock);
        if sell_amount > 0 && sell_price > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}