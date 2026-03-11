let initialized = false;
let base_lot_size = 0;
let current_lot_size = 0;
let last_trade_was_loss = false;
let last_avg_cost = 0;
let last_equity = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(20, 100);
        current_lot_size = base_lot_size;
        last_avg_cost = account.avg_cost;
        last_equity = account.total_equity;
        return;
    }
    
    if !market.trading_enabled { return; }
    
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_side = my_orders.fill_side(i);
        if fill_side == 0 {
            last_avg_cost = account.avg_cost;
        }
        i += 1;
    }
    
    if last_equity != 0 && account.total_equity < last_equity {
        last_trade_was_loss = true;
    }
    last_equity = account.total_equity;
    
    let count = my_orders.pending_count();
    let j = 0;
    while j < count {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }
    
    if last_trade_was_loss {
        current_lot_size = current_lot_size * 2;
        if current_lot_size > 1000 {
            current_lot_size = 1000;
        }
        last_trade_was_loss = false;
    } else {
        current_lot_size = base_lot_size;
    }
    
    let rsi = market.rsi_14;
    let cash_available = account.cash;
    let stock_held = account.stock;
    
    if rsi < 3000 && cash_available > 0 {
        let bid_price = market.bid_price_0;
        if bid_price == 0 {
            bid_price = market.price - 1000;
        }
        let buy_price = bid_price + 1;
        let max_shares = cash_available / buy_price;
        let shares_to_buy = current_lot_size;
        if shares_to_buy > max_shares && max_shares > 0 {
            shares_to_buy = max_shares;
        }
        if shares_to_buy > 0 {
            orders.submit_limit_buy(buy_price, shares_to_buy);
        }
    } else if rsi > 7000 && stock_held > 0 {
        let ask_price = market.ask_price_0;
        if ask_price == 0 {
            ask_price = market.price + 1000;
        }
        let sell_price = ask_price - 1;
        let shares_to_sell = current_lot_size;
        if shares_to_sell > stock_held {
            shares_to_sell = stock_held;
        }
        if shares_to_sell > 0 {
            orders.submit_limit_sell(sell_price, shares_to_sell);
        }
    }
}