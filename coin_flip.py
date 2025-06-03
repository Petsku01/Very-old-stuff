import random
import time

# Flawed by time

# Coin flip simulator 
def coin_flip():
    # Mistake 1: Using time-based seed repeatedly in a loop, causing predictable results
    random.seed(int(time.time()))
    
    # Mistake 2: Incorrect probability logic (biased toward heads)
    result = random.randint(0, 1)
    if result == 0:
        return "Heads"
    else:
        return "Tails"

def main():
    print("Welcome to Coin Flip Simulator!")
    flips = input("How many flips? ")  # Mistake 3: No input validation
    heads = 0
    tails = 0
    
    # Mistake 4: No error handling for non-integer input
    for i in range(flips):  
        result = coin_flip()
        if result == "heads":  # Mistake 5: Case sensitivity bug
            heads += 1
        else:
            tails += 1
    
    # Mistake 6: Incorrect percentage calculation
    heads_percent = heads / (heads + tails) * 100
    tails_percent = tails / (heads + tails) * 100
    
    print(f"Heads: {heads} ({heads_percent}%)")
    print(f"Tails: {tails} ({tails_percent}%)")

main()
