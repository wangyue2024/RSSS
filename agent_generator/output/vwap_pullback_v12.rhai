let initialized = false;
let threshold_percent = 0;
let trade_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        threshold_percent = rng.rand_int(5, 15);
        trade_amount = rng.rand_int(50, 200);
    }

    if !market.trading_enabled { return; }

    if market.tick % 50 != 0 {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let vwap = market.vwap;
    let price = market.price;
    let position = account.stock;

    if vwap <= 0 || price <= 0 {
        return;
    }

    let threshold_micros = vwap * threshold_percent / 100;

    if position == 0 && price < vwap && (vwap - price) > threshold_micros {
        let amount = trade_amount;
        let max_affordable = account.cash * 1_000_000 / price / 2;
        if max_affordable < amount {
            amount = max_affordable;
        }
        if amount > 0 {
            orders.submit_limit_buy(price, amount);
        }
    } else if position > 0 && price >= vwap {
        orders.submit_limit_sell(price, position);
    }
}