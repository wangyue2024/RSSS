let initialized = false;
let lot_size = 0;
let spread = 10;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(500, 1500);
    }

    if !market.trading_enabled { return; }

    if market.tick % 50 != 0 { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let imbalance = market.order_imbalance;
    let shift = imbalance * 100;
    let mid_price = market.price;
    let bid_price = mid_price - (spread * 500) + shift;
    let ask_price = mid_price + (spread * 500) + shift;

    if bid_price < 1 { bid_price = 1; }
    if ask_price < 1 { ask_price = 1; }
    if ask_price <= bid_price { ask_price = bid_price + 1; }

    let max_buy_shares = (account.cash * 50) / (100 * ask_price);
    let buy_amount = lot_size;
    if buy_amount > max_buy_shares { buy_amount = max_buy_shares; }
    if buy_amount > 0 {
        orders.submit_limit_buy(bid_price, buy_amount);
    }

    let sell_amount = lot_size;
    if sell_amount > account.stock { sell_amount = account.stock; }
    if sell_amount > 0 {
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}