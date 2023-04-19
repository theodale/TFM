const { mintAndDeposit } = require("../collateral-management.js");
const { getMintTerms } = require("../terms/mint.js");
const { signSpearmint } = require("../signing/spearmint.js");

const spearmint = async (
  alpha,
  omega,
  TFM,
  CollateralManager,
  oracle,
  bra,
  ket,
  basis,
  premium,
  transferable,
  expiry,
  amplitude,
  phase,
  alphaCollateralRequirement,
  omegaCollateralRequirement,
  alphaFee,
  omegaFee
) => {
  // DEPOSIT MINTER COLLATERALS

  const alphaWallet = await CollateralManager.wallets(alpha.address);
  const omegaWallet = await CollateralManager.wallets(omega.address);

  if (alphaWallet == ethers.constants.AddressZero) {
    await CollateralManager.connect(alpha).createWallet();
  }
  if (omegaWallet == ethers.constants.AddressZero) {
    await CollateralManager.connect(omega).createWallet();
  }

  let alphaDeposit = alphaCollateralRequirement.add(alphaFee);
  let omegaDeposit = omegaCollateralRequirement.add(omegaFee);

  if (premium > 0) {
    alphaDeposit = alphaDeposit.add(premium);
    omegaDeposit = omegaDeposit.sub(premium);
  } else {
    omegaDeposit = omegaDeposit.add(premium);
    alphaDeposit = alphaDeposit.sub(premium);
  }

  // Post required collateral
  await mintAndDeposit(CollateralManager, basis, alpha, alphaDeposit);
  await mintAndDeposit(CollateralManager, basis, omega, omegaDeposit);

  // SPEARMINT

  const { oracleSignature, mintTerms } = await getMintTerms(
    TFM,
    oracle,
    expiry,
    alphaCollateralRequirement,
    omegaCollateralRequirement,
    alphaFee,
    omegaFee,
    bra,
    ket,
    basis,
    amplitude,
    phase
  );

  const { alphaSignature, omegaSignature } = await signSpearmint(
    alpha,
    omega,
    oracleSignature,
    premium,
    transferable,
    TFM
  );

  const spearmintParameters = {
    oracleSignature,
    alpha: alpha.address,
    omega: omega.address,
    premium,
    transferable,
    alphaSignature,
    omegaSignature,
  };

  const strategyId = await TFM.strategyCounter();

  const spearmintTransaction = await TFM.spearmint(
    mintTerms,
    spearmintParameters
  );

  return { strategyId, spearmintTransaction };
};

module.exports = {
  spearmint,
};
