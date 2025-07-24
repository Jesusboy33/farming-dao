import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types,
} from "https://deno.land/x/clarinet@v1.4.1/index.ts";

Clarinet.test({
  name: "Farming DAO: farmer can register, contribute, propose, vote, and execute proposal",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const farmer1 = accounts.get("wallet_1")!;
    const farmer2 = accounts.get("wallet_2")!;

    // ✅ Register Farmer 1
    let block = chain.mineBlock([
      Tx.contractCall("farming-dao", "register-farmer", [], farmer1.address),
    ]);
    block.receipts[0].result.expectOk().expectUint(1);

    // ✅ Farmer 1 contributes 5_000 ustx
    block = chain.mineBlock([
      Tx.contractCall(
        "farming-dao",
        "contribute",
        [types.uint(5000)],
        farmer1.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // ✅ Farmer 1 submits a proposal to spend 3_000 ustx
    block = chain.mineBlock([
      Tx.contractCall(
        "farming-dao",
        "propose",
        [types.ascii("Buy tractor"), types.uint(3000)],
        farmer1.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectUint(0); // Proposal ID should be 0

    // ✅ Register Farmer 2 and vote
    block = chain.mineBlock([
      Tx.contractCall("farming-dao", "register-farmer", [], farmer2.address),
      Tx.contractCall(
        "farming-dao",
        "vote",
        [types.uint(0), types.bool(true)],
        farmer2.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectUint(2);
    block.receipts[1].result.expectOk().expectBool(true);

    // ✅ Execute proposal after vote
    block = chain.mineBlock([
      Tx.contractCall("farming-dao", "execute-proposal", [types.uint(0)], farmer1.address),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
  },
});
