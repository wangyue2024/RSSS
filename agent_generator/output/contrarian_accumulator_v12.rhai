let initialized = false;
let my_lot_size = 0;
let pending_tracker = [];
let max_pending_age = 3;

fn on_tick() {
    if !initialized {
        my_lot_size = rng.rand_int(20, 100);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let i = 0;
    let pending_count = my_orders.pending_count();
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > max_pending_age {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let rsi = market.rsi_14;
    let cash_available = account.cash;
    let stock_available = account.stock;
    let price = market.price;
    
    if rsi < 3000 && cash_available > price {
        let buy_amount = my_lot_size;
        if buy_amount * price > cash_available {
            buy_amount = cash_available / price;
        }
        if buy_amount > 0 {
            let bid_price = market.bid_price_0;
            if bid_price == 0 {
                bid_price = price - 10000;
            }
            let my_bid = bid_price - 5000 + 1;
            if my_bid > 0 {
                orders.submit_limit_buy(my_bid, buy_amount);
            }
        }
    }
    
    if rsi > 7000 && stock_available > 0 {
        let sell_amount = my_lot_size;
        if sell_amount > stock_available {
            sell_amount = stock_available;
        }
        if sell_amount > 0 {
            let ask_price = market.ask_price_0;
            if ask_price == 0 {
                ask_price = price + 10000;
            }
            let my_ask = ask_price + 5000 - 1;
            orders.submit_limit_sell(my_ask, sell_amount);
        }
    }
}