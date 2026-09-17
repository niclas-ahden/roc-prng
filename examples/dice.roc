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
#
# Every draw is a method on the seed and hands back the seed for the next
# draw. `var` lets each one reassign the same name, so there is only ever one
# seed to reach for.

main! = |_| {
	var $seed = Random.seed(2026)

	var $rolls = []
	for _ in 0..<5 {
		(die, $seed) = $seed.u8(1, 6)
		$rolls = $rolls.append(die.to_str())
	}
	Stdout.line!("Five dice: ${Str.join_with($rolls, ", ")}")?

	(colour, _) = $seed.uniform("red", ["green", "blue"])
	Stdout.line!("A colour: ${colour}")?

	Ok({})
}
