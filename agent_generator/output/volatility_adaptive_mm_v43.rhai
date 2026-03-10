let initialized = false;
let base_spread_bps = 50;
let vol_sensitivity = 8;
let order_amount = 100;
let max_age_ticks = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;

    for i in 0..my_orders.pending_count() {
        let placed_tick = my_orders.pending_placed_tick(i);
        let age = current_tick - placed_tick;
        if age >= max_age_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
    }

    let current_price = market.price;
    let volatility = market.std_dev;

    let vol_factor = (volatility * vol_sensitivity) / 1_000_000;
    let spread_bps = base_spread_bps + vol_factor;
    let half_spread_micros = (current_price * spread_bps) / 10000;

    let bid_price = current_price - half_spread_micros;
    let ask_price = current_price + half_spread_micros;

    if bid_price < 1 { bid_price = 1; }
    if ask_price < 1 { ask_price = 1; }

    let has_buy_pending = false;
    let has_sell_pending = false;

    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let side = my_orders.pending_side(j);
        if side == 0 {
            has_buy_pending = true;
        } else {
            has_sell_pending = true;
        }
        j += 1;
    }

    if !has_buy_pending && account.cash >= bid_price * order_amount {
        orders.submit_limit_buy(bid_price, order_amount);
    }

    if !has_sell_pending && account.stock >= order_amount && ask_price > account.avg_cost {
        orders.submit_limit_sell(ask_price, order_amount);
    }
}