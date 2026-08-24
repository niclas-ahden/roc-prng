# roc-prng

Pure pseudo-random number generation for Roc.

There is no true randomness here! Values come from a deterministic
generator (SplitMix64) whose entire state is a `Seed` you keep in your own
state and thread through every call. The same seed always produces the same
sequence, which makes tests reproducible. When you want runs to differ, build
the first seed from something that varies, like the current time.

SplitMix64 is not cryptographically secure. Do not use it for secrets, tokens,
or anything else security-sensitive.

API docs: https://niclas-ahden.github.io/roc-prng/

## Usage

```roc
app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.22.0/F1JVZPYfWP71s8vk6tHcV1Qx1Ef6CZkwswGoCn8VHZmL.tar.zst",
    random: "https://github.com/niclas-ahden/roc-prng/releases/download/0.1.0/DC2wat2ksGgjuWqXQKLfU7NdXRxUyT35GVwJcj4T973K.tar.zst",
}

import pf.Stdout
import pf.Utc
import random.Random

main! = |_| {
    # Seed from the current time so every run differs. Seed from a fixed
    # number instead when you want a reproducible sequence.
    seed = Random.seed(Utc.now!().to_u64_wrap())

    # Each call returns the value and the seed for the next call
    (die, seed2) = Random.int(seed, 1, 6)
    (colour, _) = Random.uniform(seed2, "red", ["green", "blue"])

    Stdout.line!("Rolled a ${die.to_str()} and picked ${colour}")?
    Ok({})
}
```

The `<hash>` is the bundle's content hash, shown on each GitHub release.

The API:

- `Random.seed(n)` builds the starting `Seed` from any `U64`.
- `Random.step(seed)` draws a uniform `U64` over the whole range. Everything
  else is built on this.
- `Random.int(seed, lo, hi)` draws a uniform `I64` between the bounds,
  inclusive, given in either order.
- `Random.u64_below(seed, n)` draws a uniform `U64` in `0 ..< n`, without
  modulo bias.
- `Random.uniform(seed, first, rest)` picks one of the given values uniformly.
  The first value stands alone so there is always something to pick.
- `Random.bool(seed)` flips a coin.

See `examples/` for a runnable program.
