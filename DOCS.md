# Novation

- To reduce computation on chain when novations are executed, we assume that the positions of two input strategies can be expressed as `A ->- B` and `B ->- C`.
- This means we only need to check if `B` occupies the correct positions on both strategies.
- It may also mean we need to do less logic about position overwrites (e.g. changing alpha/omega) on the strategies

- To ensure that all novations satisfy `A ->- B` and `B ->- C` we need to enforce the following format/conventions on strategy wave functions (phase + amplitude).

# CollateralManager

- Has a method for each TFM action with the same name.
