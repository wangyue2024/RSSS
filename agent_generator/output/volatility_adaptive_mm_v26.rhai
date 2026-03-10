let initialized = false;
let last_prices = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        return;
    }
    
    if !market.trading_enabled { return; }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if last_prices.len() >= 10 {
        let current_price = market.price;
        let old_price = last_prices[0];
        
        let price_change = (current_price - old_price) * 10000 / old_price;
        if price_change > 200 || price_change < -200 {
            fomo_triggered = true;
        }
        
        last_prices.remove(0);
    }
    
    last_prices.push(market.price);

    if fomo_triggered {
        let max_buy = account.cash / market.price;
        if max_buy > 0 {
            orders.submit_market_buy(max_buy);
        }
        fomo_triggered = false;
        return;
    }

    if last_prices.len() < 5 {
        return;
    }

    let delayed_price = last_prices[last_prices.len() - 5];
    let volatility = market.std_dev;
    let base_spread = 15;
    let volatility_adjustment = volatility * 100 / delayed_price;
    let total_spread = base_spread + volatility_adjustment;
    
    let min_spread = 5;
    let max_spread = 50;
    let clamped_spread = clamp_val(total_spread, min_spread, max_spread);
    
    let bid_offset = delayed_price * clamped_spread / 10000;
    let ask_offset = delayed_price * clamped_spread / 10000;
    
    let bid_price = delayed_price - bid_offset;
    let ask_price = delayed_price + ask_offset;
    
    let max_buy_shares = account.cash / bid_price;
    let max_sell_shares = account.stock;
    
    let order_size = 1000;
    let buy_amount = order_size;
    let sell_amount = order_size;
    
    if buy_amount > max_buy_shares {
        buy_amount = max_buy_shares;
    }
    if sell_amount > max_sell_shares {
        sell_amount = max_sell_shares;
    }
    
    if buy_amount > 0 && bid_price > 0 {
        orders.submit_limit_buy(bid_price, buy_amount);
    }
    if sell_amount > 0 {
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}