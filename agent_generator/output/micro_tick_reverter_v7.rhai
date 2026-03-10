let initialized = false;
let prev_price = 0;
let base_lot = 100;
let current_lot = 100;
let position_avg_cost = 0;
let position_side = 0;
let tick_count = 0;

fn on_tick() {
    if !initialized {
        prev_price = market.price;
        initialized = true;
        return;
    }

    if !market.trading_enabled { return; }

    tick_count += 1;

    let cancel_count = my_orders.pending_count();
    let c = 0;
    while c < cancel_count {
        let oid = my_orders.pending_id(c);
        orders.submit_cancel(oid);
        c += 1;
    }

    let price_change = market.price - prev_price;
    let offset = 500;

    if price_change < 0 {
        let buy_price = market.price - offset;
        let buy_amount = current_lot;
        orders.submit_limit_buy(buy_price, buy_amount);
    } else if price_change > 0 {
        let sell_price = market.price + offset;
        let sell_amount = current_lot;
        orders.submit_limit_sell(sell_price, sell_amount);
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let latest_fill_side = my_orders.fill_side(fill_cnt - 1);
        let latest_fill_price = my_orders.fill_price(fill_cnt - 1);
        let latest_fill_amount = my_orders.fill_amount(fill_cnt - 1);

        if account.stock == 0 {
            position_avg_cost = 0;
            position_side = 0;
        } else if account.stock > 0 {
            position_side = 1;
            position_avg_cost = account.avg_cost;
        } else {
            position_side = -1;
        }
    }

    if (position_side == 1 && market.price < position_avg_cost) || (position_side == -1 && market.price > position_avg_cost) {
        current_lot = current_lot * 2;
        if current_lot > 10000 {
            current_lot = 10000;
        }
    } else {
        current_lot = base_lot;
    }

    prev_price = market.price;
}