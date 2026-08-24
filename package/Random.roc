## Pure pseudo-random number generation.
##
## There is no true randomness here: values come from a deterministic
## generator (SplitMix64) whose entire state is a [Seed] you keep and thread
## through every call. Each function returns the value you asked for together
## with the seed for the next call:
##
## ```roc
## seed = Random.seed(42)
## (die, seed2) = Random.int(seed, 1, 6)
## (colour, seed3) = Random.uniform(seed2, "red", ["green", "blue"])
## ```
##
## The same seed always produces the same sequence, which makes tests
## reproducible. When you want runs to differ, build the first seed from
## something that varies, like the current time.
##
## SplitMix64 is not cryptographically secure. Do not use it for secrets,
## tokens, or anything else security-sensitive.
Random := [].{

	## Generator state. Create one with [Random.seed] and thread it through
	## every call: use each returned seed exactly once, since drawing from the
	## same seed twice repeats its value. The type is opaque so a seed can only
	## come from this module, never from a stray number.
	Seed := { state : U64 }.{
		is_eq : _
	}

	## Build the starting [Seed]. Any number works, and similar numbers do not
	## produce similar sequences, since the first step already mixes them far
	## apart.
	seed : U64 -> Seed
	seed = |n| Seed.{ state: n }

	## A uniform [U64] over the whole range, and the seed for the next call.
	## The other functions are built on this one.
	step : Seed -> (U64, Seed)
	step = |Seed.{ state }| {
		s = state.plus_wrap(0x9E3779B97F4A7C15)
		z1 = s.bitwise_xor(s.shr_wrap(30)).times_wrap(0xBF58476D1CE4E5B9)
		z2 = z1.bitwise_xor(z1.shr_wrap(27)).times_wrap(0x94D049BB133111EB)
		(z2.bitwise_xor(z2.shr_wrap(31)), Seed.{ state: s })
	}

	## A uniform [Bool].
	bool : Seed -> (Bool, Seed)
	bool = |s0| {
		(value, s1) = step(s0)
		(value.bitwise_and(1) == 1, s1)
	}

	## A uniform value in `0 ..< n`, or 0 when `n` is 0. The raw [U64] range
	## rarely divides evenly into `n` buckets, so a plain remainder would favour
	## the low values. Draws past the last full multiple of `n` are redrawn
	## instead (fewer than one extra draw on average).
	u64_below : Seed, U64 -> (U64, Seed)
	u64_below = |s0, n| {
		if n == 0 {
			(0, s0)
		} else {
			# (2^64 - n) mod n, computed without leaving U64: the count of
			# values that fit before the last full multiple of n.
			threshold = (U64.highest - (n - 1)).rem_by(n)
			(value, s1) = step(s0)
			if value >= threshold {
				(value.rem_by(n), s1)
			} else {
				u64_below(s1, n)
			}
		}
	}

	## A uniform integer between the two bounds, inclusive, given in either
	## order: `Random.int(seed, 1, 6)` rolls a die.
	int : Seed, I64, I64 -> (I64, Seed)
	int = |s0, a, b| {
		(lo, hi) = if a <= b { (a, b) } else { (b, a) }
		# The span minus one fits a U64 for every pair of bounds. The span
		# itself overflows exactly when the bounds cover all of I64, in which
		# case the raw step already is a uniform draw.
		span_m1 = hi.minus_wrap(lo).to_u64_wrap()
		if span_m1 == U64.highest {
			(value, s1) = step(s0)
			(value.to_i64_wrap(), s1)
		} else {
			(value, s1) = u64_below(s0, span_m1 + 1)
			# Wrapping is intentional: the offset can exceed I64.highest as a
			# plain integer, but lo + value lands back in [lo, hi] modulo 2^64.
			(lo.plus_wrap(value.to_i64_wrap()), s1)
		}
	}

	## One of the given values, uniformly. The value to pick from is the first
	## argument plus a list of alternatives, so there is always something to
	## pick: `Random.uniform(seed, "red", ["green", "blue"])`.
	uniform : Seed, a, List(a) -> (a, Seed)
	uniform = |s0, first, rest| {
		(index, s1) = u64_below(s0, 1 + rest.len())
		if index == 0 {
			(first, s1)
		} else {
			match rest.get(index - 1) {
				Ok(value) => (value, s1)
				Err(_) => (first, s1)
			}
		}
	}
}

# --- roc test (run via `roc test package/main.roc`) ---

# Known-answer vectors for SplitMix64 (seed 0 and seed 42, first three
# outputs), so the sequence is pinned to the reference algorithm and cannot
# drift silently.
expect {
	(v0, s1) = Random.step(Random.seed(0))
	(v1, s2) = Random.step(s1)
	(v2, _) = Random.step(s2)
	v0 == 16294208416658607535 and v1 == 7960286522194355700 and v2 == 487617019471545679
}
expect {
	(v0, s1) = Random.step(Random.seed(42))
	(v1, s2) = Random.step(s1)
	(v2, _) = Random.step(s2)
	v0 == 13679457532755275413 and v1 == 2949826092126892291 and v2 == 5139283748462763858
}

# Same seed, same value, and the returned seed differs from the one given.
expect {
	(a, _) = Random.step(Random.seed(7))
	(b, next) = Random.step(Random.seed(7))
	a == b and next != Random.seed(7)
}

# u64_below stays under its bound over a run of draws, and n == 0 is total.
expect {
	(misses, _) = (0..<200).iter().fold((0, Random.seed(1)), |(count, s), _| {
		(value, s2) = Random.u64_below(s, 10)
		miss = if value < 10 { 0 } else { 1 }
		(count + miss, s2)
	})
	misses == 0
}
expect {
	(value, s1) = Random.u64_below(Random.seed(3), 0)
	value == 0 and s1 == Random.seed(3)
}

# u64_below(_, 1) can only produce 0, and every draw under 3 hits all three
# residues over a modest run (a smoke test that low bounds are not stuck).
expect {
	(value, _) = Random.u64_below(Random.seed(11), 1)
	value == 0
}
expect {
	zero_counts : List(U64)
	zero_counts = [0, 0, 0]
	(seen, _) = (0..<100).iter().fold((zero_counts, Random.seed(5)), |(counts, s), _| {
		(value, s2) = Random.u64_below(s, 3)
		bumped = match counts.get(value) {
			Ok(count) => counts.set(value, count + 1) ?? counts
			Err(_) => counts
		}
		(bumped, s2)
	})
	seen.all(|count| count > 0)
}

# int respects inclusive bounds in either order, and a collapsed range is
# constant.
expect {
	(misses, _) = (0..<200).iter().fold((0, Random.seed(9)), |(count, s), _| {
		(value, s2) = Random.int(s, -3, 3)
		miss = if value >= -3 and value <= 3 { 0 } else { 1 }
		(count + miss, s2)
	})
	misses == 0
}
expect {
	(a, s1) = Random.int(Random.seed(13), 5, -5)
	(b, _) = Random.int(Random.seed(13), -5, 5)
	a == b and a >= -5 and a <= 5 and s1 != Random.seed(13)
}
expect {
	(value, _) = Random.int(Random.seed(17), 4, 4)
	value == 4
}

# int over all of I64 is the raw step reinterpreted, so extremes are reachable
# in principle. This only pins that it runs and stays in range.
expect {
	(value, _) = Random.int(Random.seed(19), I64.lowest, I64.highest)
	value >= I64.lowest and value <= I64.highest
}

# uniform picks each of three values at least once over a modest run, and a
# rest-less call returns the only value there is.
expect {
	(value, _) = Random.uniform(Random.seed(23), "only", [])
	value == "only"
}
expect {
	zero_counts : List(U64)
	zero_counts = [0, 0, 0]
	(seen, _) = (0..<100).iter().fold((zero_counts, Random.seed(29)), |(counts, s), _| {
		(value, s2) = Random.uniform(s, 0, [1, 2])
		bumped = match counts.get(value.to_u64_wrap()) {
			Ok(count) => counts.set(value.to_u64_wrap(), count + 1) ?? counts
			Err(_) => counts
		}
		(bumped, s2)
	})
	seen.all(|count| count > 0)
}

# bool produces both values over a run of draws.
expect {
	(trues, _) = (0..<50).iter().fold((0, Random.seed(31)), |(count, s), _| {
		(value, s2) = Random.bool(s)
		bump = if value { 1 } else { 0 }
		(count + bump, s2)
	})
	trues > 0 and trues < 50
}
