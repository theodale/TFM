const { getOracleMintSignature } = require("../oracle/mint.js");

const peppermint = async (
  alpha,
  omega,
  pepperminter,
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
  // DEPOSIT MINTER COLLATERALS

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

  const alphaDepositId = await FundManager.lockedDepositCounters(
    alpha.address,
    pepperminter.address,
    basis.address
  );
  const omegaDepositId = await FundManager.lockedDepositCounters(
    omega.address,
    pepperminter.address,
    basis.address
  );

  await basis.mint(alpha.address, alphaDeposit);
  await basis.mint(omega.address, omegaDeposit);
  await basis.connect(alpha).approve(FundManager.address, alphaDeposit);
  await basis.connect(omega).approve(FundManager.address, omegaDeposit);

  await FundManager.connect(alpha).depositForPeppermint(
    pepperminter.address,
    basis.address,
    alphaDeposit,
    360000000000
  );
  await FundManager.connect(omega).depositForPeppermint(
    pepperminter.address,
    basis.address,
    omegaDeposit,
    360000000000
  );

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

  const oracleNonce = await TFM.oracleNonce();

  const peppermintParameters = {
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
    alphaDepositId,
    omegaDepositId,
  };

  const strategyId = await TFM.strategyCounter();

  const peppermintTransaction = await TFM.connect(pepperminter).peppermint(
    peppermintParameters
  );

  return { strategyId, peppermintTransaction };
};

module.exports = {
  peppermint,
};
