let initialized = false;
let last_buy_price = -1;
let last_sell_price = -1;
let martingale_multiplier = 1;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_factor = rng.rand_int(30, 50);
        martingale_multiplier = 1;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fill_cnt = my_orders.fill_count();
    let j = 0;
    while j < fill_cnt {
        let fill_side = my_orders.fill_side(j);
        let fill_price = my_orders.fill_price(j);
        if fill_side == 0 {
            last_buy_price = fill_price;
        } else {
            last_sell_price = fill_price;
        }
        j += 1;
    }
    
    if last_buy_price > 0 && last_sell_price > 0 && last_sell_price < last_buy_price {
        martingale_multiplier = martingale_multiplier * 2;
        last_buy_price = -1;
        last_sell_price = -1;
    } else if last_buy_price > 0 && last_sell_price > 0 {
        martingale_multiplier = 1;
        last_buy_price = -1;
        last_sell_price = -1;
    }
    
    let range_high = market.high_20;
    let range_low = market.low_20;
    let spread = range_high - range_low;
    
    let base_position_pct = rng.rand_int(40, 50);
    let cash_to_use = (account.cash * base_position_pct) / 100;
    let base_shares = cash_to_use / market.price;
    
    if spread < market.price * 1 / 100 {
        base_shares = base_shares * 2;
    }
    
    let shares_to_trade = base_shares * martingale_multiplier;
    if shares_to_trade < 1 { shares_to_trade = 1; }
    
    let buy_price = range_low + 5000;
    let sell_price = range_high - 5000;
    
    if buy_price < market.ask_price_0 && buy_price > 0 {
        let max_affordable = account.cash / buy_price;
        let buy_amount = shares_to_trade;
        if buy_amount > max_affordable { buy_amount = max_affordable; }
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    if sell_price > market.bid_price_0 && sell_price > 0 {
        let sell_amount = shares_to_trade;
        if sell_amount > account.stock { sell_amount = account.stock; }
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}