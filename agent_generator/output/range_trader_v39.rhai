let initialized = false;
let base_lot = 0;
let current_lot = 0;
let last_side = 0;
let loss_flag = false;
let prev_stock = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_capital = account.total_equity * 5 / 100;
        let max_shares = max_capital / market.price;
        if max_shares < 1 {
            max_shares = 1;
        }
        base_lot = rng.rand_int(1, max_shares);
        current_lot = base_lot;
        prev_stock = account.stock;
        return;
    }

    if !market.trading_enabled { return; }

    let max_std_dev = 5_000_000;
    if market.std_dev > max_std_dev {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if prev_stock != account.stock && prev_stock != 0 {
        let price_now = market.price;
        let avg = account.avg_cost;
        if (last_side == 1 && price_now < avg) || (last_side == -1 && price_now > avg) {
            loss_flag = true;
        } else {
            loss_flag = false;
        }
    }
    prev_stock = account.stock;

    if loss_flag {
        current_lot = current_lot * 2;
    } else {
        current_lot = base_lot;
    }

    let spread = market.high_20 - market.low_20;
    let min_spread = 100_000;
    let adjusted_lot = current_lot;
    if spread < min_spread {
        adjusted_lot = adjusted_lot * 2;
    }

    if adjusted_lot < 1 {
        adjusted_lot = 1;
    }

    let buy_price = market.low_20;
    let sell_price = market.high_20;

    if account.cash > buy_price {
        let max_buy = account.cash / buy_price;
        let buy_amount = adjusted_lot;
        if buy_amount > max_buy {
            buy_amount = max_buy;
        }
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
            last_side = 1;
        }
    }

    if account.stock > 0 {
        let sell_amount = adjusted_lot;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
            last_side = -1;
        }
    }
}