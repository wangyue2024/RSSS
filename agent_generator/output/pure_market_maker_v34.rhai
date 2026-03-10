let initialized = false;
let delayed_price = 0;
let spread = 0;
let lot_size = 0;
let price_buffer = [];

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        spread = rng.rand_int(10000, 50000);
        let aggressive_base = rng.rand_int(100, 500);
        lot_size = aggressive_base;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }

    if price_buffer.len() < 5 {
        return;
    }

    delayed_price = price_buffer[0];

    let buy_price = delayed_price - spread;
    let sell_price = delayed_price + spread;

    let buy_amount = account.cash / (2 * buy_price);
    let risk_multiplier = rng.rand_int(3, 10);
    let adjusted_buy = buy_amount * risk_multiplier / 10;
    let final_buy = if adjusted_buy > 0 { adjusted_buy } else { 1 };

    let sell_amount = account.stock / 2;
    let adjusted_sell = sell_amount * risk_multiplier / 10;
    let final_sell = if adjusted_sell > 0 { adjusted_sell } else { 1 };

    if buy_price > 0 && final_buy > 0 {
        orders.submit_limit_buy(buy_price, final_buy);
    }
    if sell_price > 0 && final_sell > 0 {
        orders.submit_limit_sell(sell_price, final_sell);
    }
}