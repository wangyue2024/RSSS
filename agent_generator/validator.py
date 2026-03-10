import re

def sanitize_and_validate(code: str) -> tuple[bool, str, str]:
    """
    Validates and cleans the raw LLM output.
    Returns: (is_valid, cleaned_code, error_reason)
    """
    # 1. Strip markdown code blocks
    lines = code.split('\n')
    clean_lines = []
    in_code_block = False
    
    # Simple extraction (if the LLM wrapped it in ```rhai ... ```)
    for line in lines:
        if line.startswith('```'):
            in_code_block = not in_code_block
            continue
        clean_lines.append(line)
        
    cleaned_code = '\n'.join(clean_lines).strip()

    # 1.5 Auto-sanitize Rhai hallucinated Rust methods that are invalid
    # Some basic cleanup, but we will strongly reject bad patterns below
    cleaned_code = re.sub(r'let\s+mut\s+', 'let ', cleaned_code)

    # 2. Check for required structure
    if "fn on_tick()" not in cleaned_code:
        return False, cleaned_code, "Missing required function: `fn on_tick()`"
        
    # 3. Check for float prevention (THE MOST CRITICAL RULE)
    float_pattern = re.compile(r'\d+\.\d+')
    if float_pattern.search(cleaned_code):
        return False, cleaned_code, "Violated NO FLOATS rule. Found floating point numbers like 0.5 or 12.34."
        
    # 4. Blacklist checks for fatal LLM hallucinations
    blacklist = [
        ("custom_memory", "FATAL: Used `custom_memory` which does not exist in Rust `AccountView`. Use global `let` instead."),
        (".bids", "FATAL: Used `market.bids` array which does not exist. Use `market.bid_price_0` instead."),
        (".asks", "FATAL: Used `market.asks` array which does not exist. Use `market.ask_price_0` instead."),
        ("history_prices[", "FATAL: Used `history_prices` as array. Use `market.history_price(idx)` instead."),
        ("unwrap()", "FATAL: Used Rust `.unwrap()` which is invalid in Rhai here."),
        ("unwrap_or", "FATAL: Used Rust `.unwrap_or()` which is invalid in Rhai here."),
        ("orders[", "FATAL: Used `orders` as an array. It is an ActionMailbox object, not an array."),
        ("my_orders[", "FATAL: Used `my_orders` as an array. You MUST use indexing functions like `my_orders.pending_id(i)`."),
        ("remove_at(", "FATAL: `remove_at()` does not exist in Rhai. Use `remove(index)` instead."),
        (" and ", "FATAL: Used Python `and`. Use `&&` for logic in Rhai."),
        (" or ", "FATAL: Used Python `or`. Use `||` for logic in Rhai.")
    ]
    
    for bad_word, reason in blacklist:
        if bad_word in cleaned_code:
            return False, cleaned_code, reason
            
    # 5. Check for nested functions (indented `fn `)
    for line in clean_lines:
        if re.match(r'^\s+fn\s+', line):
            return False, cleaned_code, "FATAL: Function definitions must be at global level (no leading spaces). Do not nest `fn` inside blocks."
    
    return True, cleaned_code, "Valid"
