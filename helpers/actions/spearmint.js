const { getOracleMintSignature } = require("../oracle/mint.js");
const { signSpearmint } = require("../signing/spearmint.js");
const { mintAndDeposit } = require("../utils.js");

const spearmint = async (
  alpha,
  omega,
  TFM,
  FundManager,
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
  const alphaWallet = await FundManager.wallets(alpha.address);
  const omegaWallet = await FundManager.wallets(omega.address);

  if (alphaWallet == ethers.constants.AddressZero) {
    await FundManager.connect(alpha).createWallet();
  }
  if (omegaWallet == ethers.constants.AddressZero) {
    await FundManager.connect(omega).createWallet();
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

  await mintAndDeposit(alpha, alphaDeposit, basis, FundManager);
  await mintAndDeposit(omega, omegaDeposit, basis, FundManager);

  const oracleSignature = await getOracleMintSignature(
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

  // Switch to two calls for each signer
  const alphaSignature = await signSpearmint(
    alpha,
    alpha,
    omega,
    TFM,
    oracleSignature,
    premium,
    transferable
  );

  const omegaSignature = await signSpearmint(
    omega,
    alpha,
    omega,
    TFM,
    oracleSignature,
    premium,
    transferable
  );

  const oracleNonce = await TFM.oracleNonce();

  const spearmintParameters = {
    expiry,
    bra: bra.address,
    ket: ket.address,
    basis: basis.address,
    amplitude,
    phase,
    oracleSignature,
    oracleNonce,
    alphaCollateralRequirement,
    omegaCollateralRequirement,
    alphaFee,
    omegaFee,
    alpha: alpha.address,
    omega: omega.address,
    premium,
    transferable,
    alphaSignature,
    omegaSignature,
  };

  const strategyId = await TFM.strategyCounter();

  const spearmintTransaction = await TFM.spearmint(spearmintParameters);

  return { strategyId, spearmintTransaction };
};

module.exports = {
  spearmint,
};
