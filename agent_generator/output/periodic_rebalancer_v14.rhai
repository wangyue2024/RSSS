let tick_counter = 0;
let initialized = false;
let last_prices = [];
let fomo_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        last_prices.push(market.price);
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    last_prices.push(market.price);
    if last_prices.len() > 3 {
        last_prices.remove(0);
    }
    
    if last_prices.len() == 3 {
        let price_two_ago = last_prices[0];
        let price_now = last_prices[2];
        if price_two_ago != 0 && (price_now - price_two_ago) * 10000 / price_two_ago >= 200 {
            fomo_triggered = true;
            let buy_amount = account.cash * 10 / 100 / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            tick_counter = 0;
            return;
        }
    }
    
    fomo_triggered = false;
    
    tick_counter += 1;
    if tick_counter >= 10 {
        tick_counter = 0;
        
        let stock_value = market.price * account.stock;
        let total_eq = account.cash + stock_value;
        if total_eq == 0 { return; }
        
        let stock_pct = stock_value * 10000 / total_eq;
        
        if stock_pct > 5500 {
            let target_stock_value = total_eq / 2;
            let target_stock_amount = target_stock_value / market.price;
            let sell_amount = account.stock - target_stock_amount;
            if sell_amount > 0 {
                let sell_price = market.price * 1005 / 1000;
                orders.submit_limit_sell(sell_price, sell_amount);
            }
        } else if stock_pct < 4500 {
            let target_stock_value = total_eq / 2;
            let target_stock_amount = target_stock_value / market.price;
            let buy_amount = target_stock_amount - account.stock;
            if buy_amount > 0 && account.cash > market.price * buy_amount {
                let buy_price = market.price * 995 / 1000;
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    }
}