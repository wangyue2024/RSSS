let price_buffer = [];
let last_trade_loss = false;
let last_trade_price = 0;
let current_lot = 100;
let base_lot = 100;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Cancel all existing orders each tick
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Store current price in buffer
    price_buffer.push(market.price);
    
    // Keep only last 5 prices
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }
    
    // Need 5 ticks of history before trading
    if price_buffer.len() < 5 {
        return;
    }
    
    // Use price from 5 ticks ago (oldest in buffer)
    let delayed_price = price_buffer[0];
    
    // Check for fills from last tick to update trade tracking
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        // Get the most recent fill
        let last_idx = fill_cnt - 1;
        let fill_price = my_orders.fill_price(last_idx);
        let fill_side = my_orders.fill_side(last_idx);
        
        // Update last trade price
        last_trade_price = fill_price;
        
        // Determine if last trade was a loss
        if fill_side == 0 { // Buy
            if delayed_price < last_trade_price {
                last_trade_loss = true;
            } else {
                last_trade_loss = false;
            }
        } else { // Sell
            if delayed_price > last_trade_price {
                last_trade_loss = true;
            } else {
                last_trade_loss = false;
            }
        }
        
        // Martingale sizing
        if last_trade_loss {
            current_lot = base_lot * 2;
        } else {
            current_lot = base_lot;
        }
    }
    
    // Calculate Bollinger Bands
    let upper_band = market.ma_20 + 2 * market.std_dev;
    let lower_band = market.ma_20 - 2 * market.std_dev;
    
    // Place limit buy at lower band + 1 micro (Off-by-One Pumper)
    let buy_price = lower_band + 1;
    let buy_amount = current_lot;
    
    // Check if we have enough cash
    let buy_cost = buy_price * buy_amount;
    if account.cash >= buy_cost && buy_amount > 0 {
        orders.submit_limit_buy(buy_price, buy_amount);
    }
    
    // Place limit sell at upper band
    let sell_price = upper_band;
    let sell_amount = current_lot;
    
    // Check if we have enough stock
    if account.stock >= sell_amount && sell_amount > 0 {
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}