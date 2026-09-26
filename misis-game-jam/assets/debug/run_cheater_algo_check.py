# Mirrors CheaterDualResolve.evaluate + classic RPSLS for exhaustive check.
ITEMS = ["ROCK", "SCISSORS", "PAPER", "LIZARD", "SPOCK"]
# who beats whom (classic)
BEATS = {
    "ROCK": {"SCISSORS", "LIZARD"},
    "SCISSORS": {"PAPER", "LIZARD"},
    "PAPER": {"ROCK", "SPOCK"},
    "LIZARD": {"PAPER", "SPOCK"},
    "SPOCK": {"ROCK", "SCISSORS"},
}


def resolve(a: str, b: str) -> int:
    if a == b:
        return 0
    a_b = b in BEATS[a]
    b_a = a in BEATS[b]
    if a_b and b_a:
        return 0
    if a_b:
        return 1
    if b_a:
        return -1
    return 0


def evaluate(p1: str, p2_items: list[str]) -> int:
    wins_p1 = wins_p2 = 0
    any_tie = False
    for ai in p2_items:
        pair = resolve(p1, ai)
        if pair == 1:
            wins_p1 += 1
        elif pair == -1:
            wins_p2 += 1
        else:
            any_tie = True
    if any_tie:
        return 0
    if wins_p1 > wins_p2:
        return 1
    if wins_p2 > wins_p1:
        return -1
    return 0


def expected(p1: str, a: str, b: str) -> int:
    ra, rb = resolve(p1, a), resolve(p1, b)
    if ra == 0 or rb == 0:
        return 0
    w1 = (1 if ra == 1 else 0) + (1 if rb == 1 else 0)
    w2 = (1 if ra == -1 else 0) + (1 if rb == -1 else 0)
    if w1 > w2:
        return 1
    if w2 > w1:
        return -1
    return 0


fails = 0
checked = 0
examples = []
for p1 in ITEMS:
    for a in ITEMS:
        for b in ITEMS:
            got = evaluate(p1, [a, b])
            want = expected(p1, a, b)
            checked += 1
            if got != want:
                fails += 1
                examples.append(f"FAIL {p1} vs [{a},{b}] got={got} want={want}")

named = [
    ("ROCK", ["SCISSORS", "LIZARD"], 1),
    ("ROCK", ["PAPER", "SPOCK"], -1),
    ("ROCK", ["SCISSORS", "PAPER"], 0),  # win+lose
    ("ROCK", ["ROCK", "SCISSORS"], 0),  # tie dominates
    ("PAPER", ["PAPER", "PAPER"], 0),
    ("LIZARD", ["ROCK", "SCISSORS"], -1),
    ("SPOCK", ["ROCK", "SCISSORS"], 1),
]
named_fail = 0
for p1, p2, want in named:
    got = evaluate(p1, p2)
    status = "OK" if got == want else "FAIL"
    if got != want:
        named_fail += 1
    print(f"{status} {p1} vs {p2} -> {got} (want {want})")

print(f"exhaustive: {checked - fails}/{checked} ok")
if examples:
    print("\n".join(examples[:20]))
print("PASS" if fails == 0 and named_fail == 0 else f"FAIL fails={fails} named={named_fail}")
