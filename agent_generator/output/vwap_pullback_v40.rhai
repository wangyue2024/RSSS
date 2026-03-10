let initialized = false;
let price_history = [];
let fomo_triggered = false;
let hold_price = 0;
let buy_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        let i = 0;
        while i < 5 {
            price_history.push(market.price);
            i += 1;
        }
        if market.price > 0 {
            hold_price = market.price;
        }
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }

    if price_history.len() >= 5 {
        price_history.remove(0);
    }
    price_history.push(market.price);

    if price_history.len() == 5 {
        let old_price = price_history[0];
        if old_price > 0 && market.price > old_price {
            let jump_pct = (market.price - old_price) * 10000 / old_price;
            if jump_pct > 200 {
                fomo_triggered = true;
            }
        }
    }

    let vwap = market.vwap;
    let price = market.price;
    let cash = account.cash;
    let stock = account.stock;
    let avg_cost = account.avg_cost;

    if fomo_triggered {
        if cash > market.price * buy_amount {
            orders.submit_market_buy(buy_amount);
        }
        fomo_triggered = false;
        return;
    }

    if stock == 0 {
        if vwap > 0 && price > 0 && vwap > price {
            let threshold = vwap * 50 / 10000;
            if (vwap - price) > threshold {
                let bid_price = price + 1;
                if cash > bid_price * buy_amount {
                    orders.submit_limit_buy(bid_price, buy_amount);
                }
            }
        }
    } else {
        if price > avg_cost && price > 0 {
            let ask_price = vwap;
            if ask_price > 0 && stock >= buy_amount {
                orders.submit_limit_sell(ask_price, buy_amount);
            }
        }
    }
}