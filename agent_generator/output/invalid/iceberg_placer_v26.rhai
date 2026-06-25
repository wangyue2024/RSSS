let initialized = false;
let target_sell_amount = 0;
let lot_size = 0;
let remaining_to_sell = 0;
let last_best_ask = 0;
let last_remaining = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        let total_cap = account.total_equity;
        let stock_price = market.price;
        let max_lot_value = total_cap * 5 / 100;
        let max_shares = max_lot_value / stock_price;
        if max_shares < 1 {
            max_shares = 1;
        }
        lot_size = rng.rand_int(1, max_shares);
        target_sell_amount = account.stock * rng.rand_int(50, 90) / 100;
        if target_sell_amount < lot_size {
            target_sell_amount = lot_size;
        }
        remaining_to_sell = target_sell_amount;
    }

    if !market.trading_enabled { return; }

    let price_2pct = market.price * 2 / 100;
    if market.std_dev > price_2pct {
        let pcnt = my_orders.pending_count();
        let i = 0;
        while i < pcnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    if price_history.len() == 5 {
        let old_price = price_history[0];
        let new_price = price_history[price_history.len() - 1];
        let jump_pct = (new_price - old_price) * 10000 / old_price;
        if jump_pct > 200 {
            let pcnt = my_orders.pending_count();
            let i = 0;
            while i < pcnt {
                orders.submit_cancel(my_orders.pending_id(i));
                i += 1;
            }
            let max_buy = account.cash / market.price;
            let buy_amt = lot_size;
            if buy_amt > max_buy {
                buy_amt = max_buy;
            }
            if buy_amt > 0 {
                orders.submit_market_buy(buy_amt);
            }
            return;
        }
    }

    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        if my_orders.fill_side(i) == 1 {
            remaining_to_sell -= my_orders.fill_amount(i);
        }
        i += 1;
    }

    let current_ask = market.ask_price_0;
    if current_ask == 0 { return; }

    let need_update = false;
    if current_ask != last_best_ask || remaining_to_sell != last_remaining {
        need_update = true;
        last_best_ask = current_ask;
        last_remaining = remaining_to_sell;
    }

    if need_update && remaining_to_sell > 0 {
        let pcnt = my_orders.pending_count();
        let j = 0;
        while j < pcnt {
            if my_orders.pending_side(j) == 1 {
                orders.submit_cancel(my_orders.pending_id(j));
            }
            j += 1;
        }
        let order_amt = lot_size;
        if order_amt > remaining_to_sell {
            order_amt = remaining_to_sell;
        }
        if order_amt > 0 {
            orders.submit_limit_sell(current_ask, order_amt);
        }
    }
}