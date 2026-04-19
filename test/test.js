const assert = require("node:assert/strict");
const { ethers } = require("ethers");
const { compile } = require("./helpers/compile");

const RPC = process.env.RPC_URL || "http://127.0.0.1:8545";

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC);
  const [coinbase] = await provider.send("eth_accounts", []);
  const owner = await provider.getSigner(coinbase);
  const ownerAddr = await owner.getAddress();
  const art = compile();

  const CalcF = new ethers.ContractFactory(art.Calculator.abi, art.Calculator.bytecode, owner);
  const CallerF = new ethers.ContractFactory(art.CalculatorCaller.abi, art.CalculatorCaller.bytecode, owner);

  const deployCalc = async (a, b, c) => {
    const x = await CalcF.deploy(a, b, c);
    await x.waitForDeployment();
    return x;
  };

  // ----- Setup -----
  const v1 = await deployCalc(1, 0, 0);
  const caller = await CallerF.deploy(await v1.getAddress());
  await caller.waitForDeployment();

  // ----- Ф1: addNewCalculator -----
  const v2 = await deployCalc(2, 0, 0);
  await (await caller.addNewCalculator(await v2.getAddress())).wait();
  assert.equal(await caller.getCalculator("2.0.0"), await v2.getAddress());
  assert.equal((await caller.getLastVersion()).version, "2.0.0");

  await assert.rejects(caller.addNewCalculator(ethers.ZeroAddress), "zero address must revert");

  const dup = await deployCalc(1, 0, 0);
  await assert.rejects(caller.addNewCalculator(await dup.getAddress()), "duplicate version must revert");

  console.log("[ok] Ф1 addNewCalculator");

  // ----- Ф2: changeSelectedVersion -----
  await (await caller.changeSelectedVersion("1.0.0")).wait();
  assert.equal(await caller.getUserVersion(ownerAddr), "1.0.0");

  await (await caller.changeSelectedVersion("9.9.9")).wait();
  assert.equal(await caller.getUserVersion(ownerAddr), "");

  const ret = await caller.changeSelectedVersion.staticCall("2.0.0");
  assert.equal(ret, await v2.getAddress());

  console.log("[ok] Ф2 changeSelectedVersion");

  // ----- Ф3: callDivision -----
  assert.equal(await caller.callDivision.staticCall(10, 2), 5n);
  assert.equal(await caller.callDivision.staticCall(7, 2), 3n);
  await assert.rejects(caller.callDivision.staticCall(1, 0), "division by zero must revert");

  console.log("[ok] Ф3 callDivision");

  console.log("\nAll tests passed.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
