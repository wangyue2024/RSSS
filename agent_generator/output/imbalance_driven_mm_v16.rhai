let initialized = false;
let base_spread = 0;
let imbalance_sensitivity = 0;
let max_position_size = 0;
let base_lot = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(2000, 10000);
        imbalance_sensitivity = rng.rand_int(500, 2500);
        max_position_size = rng.rand_int(500, 1000);
        base_lot = rng.rand_int(50, 200);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let imbalance = market.order_imbalance;
    let imbalance_factor = imbalance * imbalance_sensitivity / 10000;
    let mid_price = market.price;

    let adjusted_bid = mid_price + imbalance_factor - base_spread / 2;
    let adjusted_ask = mid_price + imbalance_factor + base_spread / 2;

    let cash_available = account.cash;
    let stock_available = account.stock;
    let price_for_buy = if adjusted_bid > 0 { adjusted_bid } else { 1 };
    let max_buy_shares = cash_available * max_position_size / (100 * price_for_buy);
    let max_sell_shares = stock_available * max_position_size / 100;

    let buy_amount = if max_buy_shares > base_lot { base_lot } else { max_buy_shares };
    let sell_amount = if max_sell_shares > base_lot { base_lot } else { max_sell_shares };

    if buy_amount > 0 && price_for_buy > 0 {
        orders.submit_limit_buy(price_for_buy, buy_amount);
    }

    if sell_amount > 0 && adjusted_ask > 0 {
        orders.submit_limit_sell(adjusted_ask, sell_amount);
    }
}