let initialized = false;
let fomo_activated = false;
let stop_loss_price = 0;
let breakout_active = false;
let fomo_check_window = 5;
let stop_loss_pct = 98;
let order_amount = 1000;
let breakout_order_id = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fomo_check_window = 5;
        order_amount = 1000;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.stock > 0 && stop_loss_price == 0 {
        stop_loss_price = account.avg_cost * stop_loss_pct / 100;
    }

    if account.stock > 0 && market.price < stop_loss_price {
        orders.submit_market_sell(account.stock);
        stop_loss_price = 0;
        breakout_active = false;
        return;
    }

    if account.stock == 0 {
        stop_loss_price = 0;
        breakout_active = false;
    }

    let hist_len = market.history_len();
    if hist_len >= fomo_check_window && !fomo_activated && account.stock == 0 {
        let price_now = market.price;
        let price_past = market.history_price(hist_len - fomo_check_window);
        if price_past > 0 {
            let change_pct = (price_now - price_past) * 100 / price_past;
            if change_pct > 2 {
                fomo_activated = true;
                orders.submit_market_buy(order_amount);
                return;
            }
        }
    }

    if fomo_activated && account.stock == 0 {
        fomo_activated = false;
    }

    if !fomo_activated && account.stock == 0 {
        if market.price > market.high_20 {
            let bid_price = market.ask_price_0 + 1;
            if bid_price > 0 && account.cash >= bid_price * order_amount {
                orders.submit_limit_buy(bid_price, order_amount);
                breakout_active = true;
            }
        }
    }
}