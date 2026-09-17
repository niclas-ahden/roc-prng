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
    random: "https://github.com/niclas-ahden/roc-prng/releases/download/0.4.0/C3JpBYoPwC9SN5aweoh1Dux2K3iy4vfMTdAsWooE1HF5.tar.zst",
}

import pf.Stdout
import pf.Utc
import random.Random

main! = |_| {
    # Seed from the current time so every run differs. Seed from a fixed
    # number instead when you want a reproducible sequence.
    var $seed = Random.seed(Utc.now!().to_u64_wrap())

    # Each draw returns the value and the seed for the next draw
    (die, $seed) = $seed.u8(1, 6)
    (colour, _) = $seed.uniform("red", ["green", "blue"])

    Stdout.line!("Rolled a ${die.to_str()} and picked ${colour}")?
    Ok({})
}
```

- `Random.seed(n)` builds the starting `Seed` from any `U64`. Every draw is a
  method on that seed, and hands back the seed for the next draw.
- `seed.step()` draws a uniform `U64` over the whole range. Everything else is
  built on this.
- `seed.u8(lo, hi)` draws a uniform `U8` between the bounds, inclusive, given
  in either order. Every integer type has a draw named after it: `u8`, `u16`,
  `u32`, `u64`, `i8`, `i16`, `i32`, and `i64`.
- `seed.f64()` draws a uniform `F64` in `0 ..< 1`.
- `seed.u64_below(n)` draws a uniform `U64` in `0 ..< n`, without modulo bias.
- `seed.uniform(first, rest)` picks one of the given values uniformly. The
  first value stands alone so there is always something to pick.
- `seed.bool()` flips a coin.
- `seed.to_u64()` reads the state back out, so you can persist a generator and
  rebuild it later with `Random.seed`.

See `examples/` for a runnable program.
