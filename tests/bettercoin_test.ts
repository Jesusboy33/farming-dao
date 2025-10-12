import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const alice = accounts.get("wallet_1")!;
const bob = accounts.get("wallet_2")!;
const charlie = accounts.get("wallet_3")!;

/*
  The test below is an example. To learn more, read the testing documentation here:
  https://docs.hiro.so/clarinet/feature-guides/test-contract-with-clarinet-sdk
*/

describe("BetterCoin Token Tests", () => {
  beforeEach(() => {
    // Reset state before each test
  });

  describe("Token Initialization", () => {
    it("should initialize with correct name, symbol, and decimals", () => {
      const getName = simnet.callReadOnlyFn(
        "bettercoin",
        "get-name",
        [],
        deployer
      );
      expect(getName.result).toBeOk(Cl.stringAscii("BetterCoin"));

      const getSymbol = simnet.callReadOnlyFn(
        "bettercoin",
        "get-symbol",
        [],
        deployer
      );
      expect(getSymbol.result).toBeOk(Cl.stringAscii("BETT"));

      const getDecimals = simnet.callReadOnlyFn(
        "bettercoin",
        "get-decimals",
        [],
        deployer
      );
      expect(getDecimals.result).toBeOk(Cl.uint(8));
    });

    it("should initialize with correct initial supply", () => {
      const totalSupply = simnet.callReadOnlyFn(
        "bettercoin",
        "get-total-supply",
        [],
        deployer
      );
      expect(totalSupply.result).toBeOk(Cl.uint(1000000000000000)); // 10M tokens with 8 decimals

      const deployerBalance = simnet.callReadOnlyFn(
        "bettercoin",
        "get-balance",
        [Cl.principal(deployer)],
        deployer
      );
      expect(deployerBalance.result).toBeOk(Cl.uint(1000000000000000));
    });

    it("should set deployer as initial contract owner", () => {
      const owner = simnet.callReadOnlyFn(
        "bettercoin",
        "get-contract-owner",
        [],
        deployer
      );
      expect(owner.result).toBePrincipal(deployer);
    });
  });

  describe("Token Transfers", () => {
    it("should transfer tokens successfully", () => {
      const transferAmount = 100000000; // 1 BETT

      const transfer = simnet.callPublicFn(
        "bettercoin",
        "transfer",
        [
          Cl.uint(transferAmount),
          Cl.principal(deployer),
          Cl.principal(alice),
          Cl.none(),
        ],
        deployer
      );
      expect(transfer.result).toBeOk(Cl.bool(true));

      // Check balances after transfer
      const deployerBalance = simnet.callReadOnlyFn(
        "bettercoin",
        "get-balance",
        [Cl.principal(deployer)],
        deployer
      );
      expect(deployerBalance.result).toBeOk(Cl.uint(1000000000000000 - transferAmount));

      const aliceBalance = simnet.callReadOnlyFn(
        "bettercoin",
        "get-balance",
        [Cl.principal(alice)],
        deployer
      );
      expect(aliceBalance.result).toBeOk(Cl.uint(transferAmount));
    });

    it("should fail transfer with insufficient balance", () => {
      const transfer = simnet.callPublicFn(
        "bettercoin",
        "transfer",
        [
          Cl.uint(100000000),
          Cl.principal(alice),
          Cl.principal(bob),
          Cl.none(),
        ],
        alice
      );
      expect(transfer.result).toBeErr(Cl.uint(102)); // ERR-INSUFFICIENT-BALANCE
    });

    it("should fail transfer when paused", () => {
      // Pause the contract
      const pause = simnet.callPublicFn(
        "bettercoin",
        "toggle-pause",
        [],
        deployer
      );
      expect(pause.result).toBeOk(Cl.bool(true));

      const transfer = simnet.callPublicFn(
        "bettercoin",
        "transfer",
        [
          Cl.uint(100000000),
          Cl.principal(deployer),
          Cl.principal(alice),
          Cl.none(),
        ],
        deployer
      );
      expect(transfer.result).toBeErr(Cl.uint(108)); // ERR-PAUSED
    });

    it("should fail transfer to/from blacklisted address", () => {
      // Blacklist alice
      const blacklist = simnet.callPublicFn(
        "bettercoin",
        "blacklist-address",
        [Cl.principal(alice)],
        deployer
      );
      expect(blacklist.result).toBeOk(Cl.bool(true));

      const transfer = simnet.callPublicFn(
        "bettercoin",
        "transfer",
        [
          Cl.uint(100000000),
          Cl.principal(deployer),
          Cl.principal(alice),
          Cl.none(),
        ],
        deployer
      );
      expect(transfer.result).toBeErr(Cl.uint(109)); // ERR-BLACKLISTED
    });

    it("should check daily transfer limits", () => {
      const dailyLimit = 200000000; // 2 BETT
      
      // Set daily limit for deployer
      const setLimit = simnet.callPublicFn(
        "bettercoin",
        "set-daily-transfer-limit",
        [Cl.principal(deployer), Cl.uint(dailyLimit)],
        deployer
      );
      expect(setLimit.result).toBeOk(Cl.bool(true));

      // First transfer within limit
      const transfer1 = simnet.callPublicFn(
        "bettercoin",
        "transfer",
        [
          Cl.uint(100000000),
          Cl.principal(deployer),
          Cl.principal(alice),
          Cl.none(),
        ],
        deployer
      );
      expect(transfer1.result).toBeOk(Cl.bool(true));

      // Second transfer within limit
      const transfer2 = simnet.callPublicFn(
        "bettercoin",
        "transfer",
        [
          Cl.uint(100000000),
          Cl.principal(deployer),
          Cl.principal(bob),
          Cl.none(),
        ],
        deployer
      );
      expect(transfer2.result).toBeOk(Cl.bool(true));

      // Third transfer exceeding limit
      const transfer3 = simnet.callPublicFn(
        "bettercoin",
        "transfer",
        [
          Cl.uint(100000000),
          Cl.principal(deployer),
          Cl.principal(charlie),
          Cl.none(),
        ],
        deployer
      );
      expect(transfer3.result).toBeErr(Cl.uint(110)); // ERR-DAILY-LIMIT-EXCEEDED
    });
  });

  describe("Minting Functions", () => {
    it("should allow authorized minter to mint tokens", () => {
      // Authorize alice as minter
      const authorize = simnet.callPublicFn(
        "bettercoin",
        "authorize-minter",
        [Cl.principal(alice)],
        deployer
      );
      expect(authorize.result).toBeOk(Cl.bool(true));

      const initialSupply = simnet.callReadOnlyFn(
        "bettercoin",
        "get-total-supply",
        [],
        deployer
      );

      const mintAmount = 500000000; // 5 BETT
      const mint = simnet.callPublicFn(
        "bettercoin",
        "mint",
        [Cl.uint(mintAmount), Cl.principal(bob)],
        alice
      );
      expect(mint.result).toBeOk(Cl.bool(true));

      const newSupply = simnet.callReadOnlyFn(
        "bettercoin",
        "get-total-supply",
        [],
        deployer
      );
      expect(Number(newSupply.result.value)).toBe(
        Number(initialSupply.result.value) + mintAmount
      );

      const bobBalance = simnet.callReadOnlyFn(
        "bettercoin",
        "get-balance",
        [Cl.principal(bob)],
        deployer
      );
      expect(bobBalance.result).toBeOk(Cl.uint(mintAmount));
    });

    it("should fail minting if not authorized", () => {
      const mint = simnet.callPublicFn(
        "bettercoin",
        "mint",
        [Cl.uint(500000000), Cl.principal(bob)],
        alice
      );
      expect(mint.result).toBeErr(Cl.uint(107)); // ERR-UNAUTHORIZED
    });

    it("should fail minting when minting disabled", () => {
      // This would require adding a function to disable minting
      // For now, we test the max supply constraint
      const mint = simnet.callPublicFn(
        "bettercoin",
        "mint",
        [Cl.uint(9500000000000001), Cl.principal(alice)], // Exceeds max supply
        deployer
      );
      expect(mint.result).toBeErr(Cl.uint(105)); // ERR-MINT-FAILED
    });

    it("should fail minting to blacklisted address", () => {
      // Blacklist alice
      const blacklist = simnet.callPublicFn(
        "bettercoin",
        "blacklist-address",
        [Cl.principal(alice)],
        deployer
      );
      expect(blacklist.result).toBeOk(Cl.bool(true));

      const mint = simnet.callPublicFn(
        "bettercoin",
        "mint",
        [Cl.uint(500000000), Cl.principal(alice)],
        deployer
      );
      expect(mint.result).toBeErr(Cl.uint(109)); // ERR-BLACKLISTED
    });
  });

  describe("Burning Functions", () => {
    beforeEach(() => {
      // Give alice some tokens to burn
      simnet.callPublicFn(
        "bettercoin",
        "transfer",
        [
          Cl.uint(1000000000),
          Cl.principal(deployer),
          Cl.principal(alice),
          Cl.none(),
        ],
        deployer
      );
    });

    it("should allow token burning", () => {
      const initialBalance = simnet.callReadOnlyFn(
        "bettercoin",
        "get-balance",
        [Cl.principal(alice)],
        deployer
      );
      
      const burnAmount = 500000000; // 5 BETT
      const burn = simnet.callPublicFn(
        "bettercoin",
        "burn",
        [Cl.uint(burnAmount)],
        alice
      );
      expect(burn.result).toBeOk(Cl.bool(true));

      const newBalance = simnet.callReadOnlyFn(
        "bettercoin",
        "get-balance",
        [Cl.principal(alice)],
        deployer
      );
      expect(Number(newBalance.result.value)).toBe(
        Number(initialBalance.result.value) - burnAmount
      );
    });

    it("should fail burning with insufficient balance", () => {
      const burn = simnet.callPublicFn(
        "bettercoin",
        "burn",
        [Cl.uint(2000000000)], // More than alice has
        alice
      );
      expect(burn.result).toBeErr(Cl.uint(102)); // ERR-INSUFFICIENT-BALANCE
    });
  });

  describe("Governance Functions", () => {
    beforeEach(() => {
      // Give alice enough tokens for governance
      simnet.callPublicFn(
        "bettercoin",
        "transfer",
        [
          Cl.uint(200000000), // 2 BETT (above threshold)
          Cl.principal(deployer),
          Cl.principal(alice),
          Cl.none(),
        ],
        deployer
      );
    });

    it("should create governance proposal", () => {
      const proposal = simnet.callPublicFn(
        "bettercoin",
        "create-proposal",
        [
          Cl.stringAscii("Test Proposal"),
          Cl.stringAscii("This is a test governance proposal for BetterCoin"),
        ],
        alice
      );
      expect(proposal.result).toBeOk(Cl.uint(1));
    });

    it("should fail proposal creation with insufficient tokens", () => {
      const proposal = simnet.callPublicFn(
        "bettercoin",
        "create-proposal",
        [
          Cl.stringAscii("Test Proposal"),
          Cl.stringAscii("This proposal should fail"),
        ],
        bob // Bob has no tokens
      );
      expect(proposal.result).toBeErr(Cl.uint(107)); // ERR-UNAUTHORIZED
    });

    it("should allow voting on proposals", () => {
      // Create proposal first
      const proposal = simnet.callPublicFn(
        "bettercoin",
        "create-proposal",
        [
          Cl.stringAscii("Test Proposal"),
          Cl.stringAscii("This is a test governance proposal"),
        ],
        alice
      );
      expect(proposal.result).toBeOk(Cl.uint(1));

      // Vote on proposal
      const vote = simnet.callPublicFn(
        "bettercoin",
        "vote-on-proposal",
        [Cl.uint(1), Cl.bool(true)], // Vote yes
        alice
      );
      expect(vote.result).toBeOk(Cl.bool(true));

      // Check proposal details
      const proposalDetails = simnet.callReadOnlyFn(
        "bettercoin",
        "get-proposal",
        [Cl.uint(1)],
        deployer
      );
      expect(proposalDetails.result).toBeSome();
    });
  });

  describe("Administrative Functions", () => {
    it("should allow owner to change ownership", () => {
      const setOwner = simnet.callPublicFn(
        "bettercoin",
        "set-contract-owner",
        [Cl.principal(alice)],
        deployer
      );
      expect(setOwner.result).toBeOk(Cl.bool(true));

      const newOwner = simnet.callReadOnlyFn(
        "bettercoin",
        "get-contract-owner",
        [],
        deployer
      );
      expect(newOwner.result).toBePrincipal(alice);
    });

    it("should fail ownership change from non-owner", () => {
      const setOwner = simnet.callPublicFn(
        "bettercoin",
        "set-contract-owner",
        [Cl.principal(alice)],
        bob
      );
      expect(setOwner.result).toBeErr(Cl.uint(100)); // ERR-OWNER-ONLY
    });

    it("should allow owner to toggle pause", () => {
      const pause = simnet.callPublicFn(
        "bettercoin",
        "toggle-pause",
        [],
        deployer
      );
      expect(pause.result).toBeOk(Cl.bool(true));

      const isPaused = simnet.callReadOnlyFn(
        "bettercoin",
        "is-token-paused",
        [],
        deployer
      );
      expect(isPaused.result).toBeBool(true);
    });

    it("should allow owner to manage blacklist", () => {
      const blacklist = simnet.callPublicFn(
        "bettercoin",
        "blacklist-address",
        [Cl.principal(alice)],
        deployer
      );
      expect(blacklist.result).toBeOk(Cl.bool(true));

      const isBlacklisted = simnet.callReadOnlyFn(
        "bettercoin",
        "get-blacklist-status",
        [Cl.principal(alice)],
        deployer
      );
      expect(isBlacklisted.result).toBeBool(true);

      const unblacklist = simnet.callPublicFn(
        "bettercoin",
        "unblacklist-address",
        [Cl.principal(alice)],
        deployer
      );
      expect(unblacklist.result).toBeOk(Cl.bool(true));

      const stillBlacklisted = simnet.callReadOnlyFn(
        "bettercoin",
        "get-blacklist-status",
        [Cl.principal(alice)],
        deployer
      );
      expect(stillBlacklisted.result).toBeBool(false);
    });

    it("should allow owner to manage minters", () => {
      const authorize = simnet.callPublicFn(
        "bettercoin",
        "authorize-minter",
        [Cl.principal(alice)],
        deployer
      );
      expect(authorize.result).toBeOk(Cl.bool(true));

      const isMinter = simnet.callReadOnlyFn(
        "bettercoin",
        "get-minter-status",
        [Cl.principal(alice)],
        deployer
      );
      expect(isMinter.result).toBeBool(true);

      const revoke = simnet.callPublicFn(
        "bettercoin",
        "revoke-minter",
        [Cl.principal(alice)],
        deployer
      );
      expect(revoke.result).toBeOk(Cl.bool(true));

      const stillMinter = simnet.callReadOnlyFn(
        "bettercoin",
        "get-minter-status",
        [Cl.principal(alice)],
        deployer
      );
      expect(stillMinter.result).toBeBool(false);
    });
  });

  describe("Read-only Functions", () => {
    it("should return correct token URI", () => {
      const uri = simnet.callReadOnlyFn(
        "bettercoin",
        "get-token-uri",
        [],
        deployer
      );
      expect(uri.result).toBeOk(
        Cl.some(Cl.stringAscii("https://bettercoin.org/token-metadata.json"))
      );
    });

    it("should return daily transfer limits and usage", () => {
      const limit = simnet.callReadOnlyFn(
        "bettercoin",
        "get-daily-transfer-limit",
        [Cl.principal(deployer)],
        deployer
      );
      expect(limit.result).toBeUint(1000000000000); // Default limit

      const usage = simnet.callReadOnlyFn(
        "bettercoin",
        "get-daily-usage",
        [Cl.principal(deployer)],
        deployer
      );
      expect(usage.result).toBeUint(0); // No usage yet
    });

    it("should return events log", () => {
      const events = simnet.callReadOnlyFn(
        "bettercoin",
        "get-events-log",
        [],
        deployer
      );
      expect(events.result).toBeSome();
    });
  });

  describe("Edge Cases and Security", () => {
    it("should handle zero amount transfers", () => {
      const transfer = simnet.callPublicFn(
        "bettercoin",
        "transfer",
        [
          Cl.uint(0),
          Cl.principal(deployer),
          Cl.principal(alice),
          Cl.none(),
        ],
        deployer
      );
      expect(transfer.result).toBeErr(Cl.uint(103)); // ERR-INVALID-AMOUNT
    });

    it("should handle self-transfers", () => {
      const transfer = simnet.callPublicFn(
        "bettercoin",
        "transfer",
        [
          Cl.uint(100000000),
          Cl.principal(deployer),
          Cl.principal(deployer),
          Cl.none(),
        ],
        deployer
      );
      expect(transfer.result).toBeOk(Cl.bool(true));
    });

    it("should prevent unauthorized transfers", () => {
      const transfer = simnet.callPublicFn(
        "bettercoin",
        "transfer",
        [
          Cl.uint(100000000),
          Cl.principal(deployer), // Alice trying to transfer from deployer
          Cl.principal(alice),
          Cl.none(),
        ],
        alice
      );
      expect(transfer.result).toBeErr(Cl.uint(101)); // ERR-NOT-TOKEN-OWNER
    });
  });
});