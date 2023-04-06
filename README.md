# Trufin Protocol 🔥

The options layer of the future.

### Architecture

- The `TFM` central contract managers all option-related functionality.
- Collateral operations are performed for the `TFM` by a `CollateralManager` contract.

# Minting

- Peppermint vs spearmint

### Spearmint

- Mint nonce => why?
- Premium is exchanged before fees and collateral requirements are taken. This means receiver of premium can utilise for said reasons.

### Wallets

- Use minimal clones proxy

### Strategies

- Strategies are combinations of one or more options held between two users.

##### Actions

- Users holding positions may perform the following actions on their strategies:
  - Minting
  - Transferring
  - Combining
  - Novating
  - Exercising

### Novation

- Strategies have payouts
- If payouts are proportional, i.e. the scale the same with spot price changes, if a party occupies a position on one strategy that receives payout and one on another that requires making a proportional payout, we can alter the two strategies to reduce overall collateral requirements (for this middle party) whilst maintaining the same potential payouts for all parties involved.
- Strategies with opposite payout directions can be novated if alphaOne == alphaTwo or omegaOne == omegaTwo
- Strategies with same payout direction require the opposite

### Oracle

- The TF oracle signs a set of terms for a potential action.
- These are trusted as valid data on-chain.

### Web2

- Ensure only signing transfer/combinations/novations for non expired strategies
- Sigature replay across different strategies => e.g. mint two with same expiry, phase, bra, etc... => ensure have strategy IDs in the message hashes
- The combination strategies resulting form has to be signed so that it can be used in a strategy with the first strategy's (`strategyOne`) alpha and omega => i.e. in that direction.
