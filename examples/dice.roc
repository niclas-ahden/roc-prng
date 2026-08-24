app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.22.0/F1JVZPYfWP71s8vk6tHcV1Qx1Ef6CZkwswGoCn8VHZmL.tar.zst",
	random: "../package/main.roc",
}

import pf.Stdout
import random.Random

# Roll five dice and pick a colour. Run it with: roc examples/dice.roc
#
# The generator is deterministic: this fixed seed prints the same rolls every
# run. Seed from something that varies (like the current time) when you want
# runs to differ.

main! = |_| {
	seed = Random.seed(2026)

	(rolls, seed_after_rolls) = (0..<5).iter().fold(([], seed), |(dice, s), _| {
		(die, s2) = Random.int(s, 1, 6)
		(dice.append(die.to_str()), s2)
	})
	Stdout.line!("Five dice: ${Str.join_with(rolls, ", ")}")?

	(colour, _) = Random.uniform(seed_after_rolls, "red", ["green", "blue"])
	Stdout.line!("A colour: ${colour}")?

	Ok({})
}
