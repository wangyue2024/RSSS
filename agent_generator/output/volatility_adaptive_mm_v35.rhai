let initialized = false;
let base_spread = 0;
let vol_adjustment = 0;
let panic_threshold = 0;
let last_prices = [];

fn on_tick() {
    if !initialized {
        base_spread = rng.rand_int(2000, 5000);
        vol_adjustment = rng.rand_int(500, 2000);
        panic_threshold = -rng.rand_int(50000, 200000);
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.history_len() >= 5 {
        let price_now = market.price;
        let price_5_ago = market.history_price(market.history_len() - 5);
        let change_percent = (price_now - price_5_ago) * 100 / price_5_ago;
        if change_percent > 2 && account.cash > 100000 {
            let buy_amt = account.cash / market.price / 10;
            if buy_amt > 0 {
                orders.submit_market_buy(buy_amt);
            }
            return;
        }
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let mid_price;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    } else {
        mid_price = market.price;
    }

    let vol_factor = market.std_dev * vol_adjustment / 1000000;
    let spread = base_spread + vol_factor;
    let max_spread = mid_price * 10 / 100;
    spread = clamp_val(spread, base_spread, max_spread);

    let bid_price = mid_price - spread / 2;
    let ask_price = mid_price + spread / 2;

    if bid_price < 1 { bid_price = 1; }

    let order_base = 100;
    let max_buy = account.cash / bid_price;
    let buy_amt = order_base;
    if buy_amt > max_buy { buy_amt = max_buy; }
    if buy_amt > 0 {
        orders.submit_limit_buy(bid_price, buy_amt);
    }

    let sell_amt = order_base;
    if sell_amt > account.stock { sell_amt = account.stock; }
    if sell_amt > 0 {
        orders.submit_limit_sell(ask_price, sell_amt);
    }
}