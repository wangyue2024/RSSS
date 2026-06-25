let initialized = false;
let panic_threshold = 0;
let total_to_sell = 0;
let chunk_size = 0;
let remaining_to_sell = 0;
let last_order_filled = false;
let last_price_jump = 0;
let ticks_to_compare = 10;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(50_000, 200_000);
        total_to_sell = rng.rand_int(5_000, 20_000);
        chunk_size = rng.rand_int(10, 50);
        remaining_to_sell = total_to_sell;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    
    if market.history_len() >= ticks_to_compare {
        let price_10_ticks_ago = market.history_price(ticks_to_compare - 1);
        if price_10_ticks_ago > 0 {
            let price_change = current_price - price_10_ticks_ago;
            if price_change * 100 > price_10_ticks_ago * 2 {
                if account.cash > 100_000 {
                    let buy_amount = account.cash / current_price;
                    if buy_amount > 0 {
                        orders.submit_market_buy(buy_amount);
                    }
                }
                return;
            }
        }
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        remaining_to_sell = 0;
        return;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let i = 0;
        while i < fill_cnt {
            let fill_side = my_orders.fill_side(i);
            if fill_side == 1 {
                remaining_to_sell -= my_orders.fill_amount(i);
                last_order_filled = true;
            }
            i += 1;
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if remaining_to_sell <= 0 { return; }
    
    let best_ask = market.ask_price_0;
    if best_ask == 0 { return; }
    
    let order_amount = if chunk_size < remaining_to_sell { chunk_size } else { remaining_to_sell };
    
    if order_amount > 0 && best_ask > 0 {
        orders.submit_limit_sell(best_ask, order_amount);
    }
}