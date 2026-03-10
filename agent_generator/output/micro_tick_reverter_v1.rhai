let initialized = false;
let stop_loss_threshold = 0;
let order_size = 0;
let prev_price = 0;
let price_offset = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(500_000, 2_000_000);
        order_size = rng.rand_int(5, 15);
        price_offset = rng.rand_int(10, 50);
    }

    if !market.trading_enabled { return; }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let price_change = 0;
    if prev_price != 0 {
        price_change = market.price - prev_price;
    }
    prev_price = market.price;

    if price_change < 0 && account.cash > market.price {
        let buy_price = market.price - price_offset + 1;
        if buy_price > 0 {
            let max_shares = account.cash / buy_price;
            if max_shares > 0 {
                let shares = if order_size > max_shares { max_shares } else { order_size };
                orders.submit_limit_buy(buy_price, shares);
            }
        }
    } else if price_change > 0 && account.stock > 0 {
        let sell_price = market.price + price_offset - 1;
        if sell_price > 0 {
            let shares = if order_size > account.stock { account.stock } else { order_size };
            orders.submit_limit_sell(sell_price, shares);
        }
    }
}