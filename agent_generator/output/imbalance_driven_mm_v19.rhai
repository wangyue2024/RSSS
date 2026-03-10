let initialized = false;
let initial_lot_size = 0;
let current_lot_size = 0;
let delayed_imbalance = 0;
let delayed_price = 0;
let price_history = [];
let imbalance_history = [];
let last_trade_profitable = true;
let trade_direction = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        initial_lot_size = rng.rand_int(100, 500);
        current_lot_size = initial_lot_size;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_history.push(market.price);
    imbalance_history.push(market.order_imbalance);

    if price_history.len() > 5 {
        price_history.remove(0);
        imbalance_history.remove(0);
    }

    if price_history.len() == 5 {
        delayed_price = price_history[0];
        delayed_imbalance = imbalance_history[0];
    } else {
        delayed_price = market.price;
        delayed_imbalance = market.order_imbalance;
    }

    if account.stock > 0 {
        let avg = account.avg_cost;
        let current = market.price;
        last_trade_profitable = current > avg;
    }

    if !last_trade_profitable {
        current_lot_size = current_lot_size * 2;
        if current_lot_size > 10000 {
            current_lot_size = 10000;
        }
    } else {
        current_lot_size = initial_lot_size;
    }

    let max_shares_from_cash = (account.cash * 5) / (10 * delayed_price);
    if max_shares_from_cash < 1 {
        return;
    }
    let shares_to_trade = current_lot_size;
    if shares_to_trade > max_shares_from_cash {
        shares_to_trade = max_shares_from_cash;
    }
    if shares_to_trade < 1 {
        return;
    }

    let imbalance_factor = delayed_imbalance * 10;
    let base_spread = 500;

    let mid_price = delayed_price + imbalance_factor;
    let bid_price = mid_price - base_spread;
    let ask_price = mid_price + base_spread;

    if bid_price > 0 && shares_to_trade > 0 {
        orders.submit_limit_buy(bid_price, shares_to_trade);
    }

    if account.stock >= shares_to_trade && shares_to_trade > 0 {
        orders.submit_limit_sell(ask_price, shares_to_trade);
    }
}