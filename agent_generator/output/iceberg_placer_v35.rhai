let initialized = false;
let total_to_sell = 0;
let tip_size = 0;
let remaining_to_sell = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        total_to_sell = account.stock * 800 / 1000;
        tip_size = total_to_sell * 10 / 10000;
        if tip_size < 1 { tip_size = 1; }
        if total_to_sell < 1 { total_to_sell = 1; }
        remaining_to_sell = total_to_sell;
    }

    if !market.trading_enabled { return; }

    price_history.push(market.price);
    if price_history.len() > 3 {
        price_history.remove(0);
    }

    if price_history.len() == 3 {
        let old_price = price_history[0];
        let price_change_pct = (market.price - old_price) * 100 / old_price;
        if price_change_pct > 2 {
            let count = my_orders.pending_count();
            let i = 0;
            while i < count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            let buy_amount = account.cash / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }

    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let side = my_orders.fill_side(i);
        if side == 1 {
            let filled_amount = my_orders.fill_amount(i);
            remaining_to_sell -= filled_amount;
        }
        i += 1;
    }

    let pending_cnt = my_orders.pending_count();
    if pending_cnt == 0 && remaining_to_sell > 0 {
        let order_price = market.ask_price_0;
        if order_price == 0 {
            order_price = market.price * 101 / 100;
        }
        let order_amount = tip_size;
        if order_amount > remaining_to_sell {
            order_amount = remaining_to_sell;
        }
        if order_amount > 0 {
            orders.submit_limit_sell(order_price, order_amount);
        }
    }
}