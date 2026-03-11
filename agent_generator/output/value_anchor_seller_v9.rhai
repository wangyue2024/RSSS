let initialized = false;
let fair_value_micros = 0;
let lot_size = 0;
let price_buffer = [];

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        fair_value_micros = rng.rand_int(99_500_000, 100_500_000);
        let cash_percent = rng.rand_int(25, 50);
        lot_size = account.cash * cash_percent / 100;
        if lot_size < 1000000 { lot_size = 1000000; }
    }

    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }

    if price_buffer.len() < 5 { return; }

    let delayed_price = price_buffer[0];

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if delayed_price <= account.avg_cost { return; }

    if delayed_price > fair_value_micros {
        let sell_price = delayed_price;
        let sell_amount = 0;

        if delayed_price > fair_value_micros * 110 / 100 {
            sell_amount = lot_size * 2;
        } else if delayed_price > fair_value_micros * 105 / 100 {
            sell_amount = lot_size;
        }

        if sell_amount > 0 {
            let max_sell = account.stock;
            if sell_amount > max_sell { sell_amount = max_sell; }
            if sell_amount > 0 && sell_price > account.avg_cost {
                orders.submit_limit_sell(sell_price, sell_amount);
            }
        }
    }
}