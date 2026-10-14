# RWAIOFT — Audit Package

## 1. Scope

| Item | Value |
|---|---|
| Contract | `RWAIOFT` (`contracts/RWAIOFT.sol`) |
| Token | RWAI / RWAI, 18 decimals, fixed supply 1,000,000,000 |
| Type | LayerZero V2 OFT (burn-and-mint cross-chain token) |
| Network | BNB Smart Chain mainnet (chainId 56) |
| Address | `0x6e13378eD76CB8b74c5EE11648a853FDCdfC9162` |
| Deploy tx | `0x23d432bf49c3aa20ae1d1ad776d13e7b425da9b9489d09632d0d2c1575d91255` |
| Deploy block | 127345507 |
| BscScan | https://bscscan.com/address/0x6e13378eD76CB8b74c5EE11648a853FDCdfC9162#code (source verified) |

In scope: `contracts/RWAIOFT.sol` only (about 110 lines). Inherited LayerZero and OpenZeppelin contracts are
unmodified upstream releases and are included for reference in `standard-input-json/` and `RWAIOFT.flattened.sol`.

## 2. Build

| Item | Value |
|---|---|
| Solidity | 0.8.22 (`v0.8.22+commit.4fc1097e`) |
| EVM target | paris |
| Optimizer | enabled, 200 runs |
| viaIR | true |
| Framework | Hardhat + hardhat-deploy |

Dependencies (exact installed versions):

| Package | Version |
|---|---|
| @layerzerolabs/oft-evm | 3.1.4 |
| @layerzerolabs/oapp-evm | 0.3.2 |
| @layerzerolabs/lz-evm-protocol-v2 | 3.0.110 |
| @openzeppelin/contracts | 5.3.0 |

Constructor arguments (ABI-encoded, as deployed):

| Param | Value |
|---|---|
| `_lzEndpoint` | `0x1a44076050125825900e736c501f859c50fE728c` (LayerZero EndpointV2, BSC) |
| `_delegate` | `0xcb6794b3eC2B5b5E14878FF26E6AD475AdCA5c65` (initial owner / delegate / supply recipient) |

The on-chain runtime bytecode matches the local build byte-for-byte (immutable slots and CBOR metadata included).

## 3. Inheritance

```
RWAIOFT
├── Ownable          (OZ 5.3.0)  owner-gated admin
├── Pausable         (OZ 5.3.0)  emergency stop
├── OFT              (LZ oft-evm 3.1.4) → OFTCore → OApp → OAppCore(Ownable), ERC20
├── ERC20Permit      (OZ 5.3.0)  EIP-2612
└── ERC20Burnable    (OZ 5.3.0)  burn / burnFrom
```

## 4. Privileged roles

| Role | Holder (at time of packaging) | Powers |
|---|---|---|
| `owner` (Ownable) | `0xada86579c17A4191ac8d62020B83a4c509983285` | `pause`, `unpause`, `blacklist*`, `unBlacklist*`, `transferOwnership`, `renounceOwnership`, `setDelegate`, `setPeer`, `setEnforcedOptions`, `setMsgInspector`, `setPreCrime` |
| LayerZero `delegate` | `0xcb6794b3eC2B5b5E14878FF26E6AD475AdCA5c65` (pending change to owner) | Endpoint-side config: send/receive libraries, DVN/executor config, `skip`, `clear`, `nilify`, `burn` of inbound messages |

Ownership was transferred from the deployer to `0xada8…3285` after deployment. The delegate update to the same
address is pending. There is no minter role: total supply is fixed at construction and can only decrease through
`burn` / `burnFrom` or increase only via cross-chain `_credit` mint, which is matched by a `_debit` burn on the
source chain.

## 5. Custom logic (what to review)

All custom behaviour lives in one hook:

```solidity
function _update(address from, address to, uint256 amount)
    internal override whenNotPaused notBlacklisted(from) notBlacklisted(to)
{
    super._update(from, to, amount);
}
```

Effects:

- **Pause** blocks every transfer, mint and burn. This includes LayerZero `send` (burn on `_debit`) and inbound
  `lzReceive` (mint on `_credit`). An inbound message that arrives while paused reverts in the executor and can be
  retried via the endpoint after `unpause`.
- **Blacklist** is checked on both `from` and `to`. `address(0)` is never blacklisted (guarded in `blacklist`
  and `blacklistBatch`), so mint/burn paths are not accidentally bricked.
- Batch functions are unbounded loops; they are owner-only and intended for small lists.

Standard OFT behaviour is unchanged: no transfer fee, no dust removal beyond the OFT default
(`sharedDecimals = 6`), `_debit` / `_credit` are the upstream implementations.

## 6. Files

| Path | Purpose |
|---|---|
| `contracts/RWAIOFT.sol` | The audited contract (source of truth) |
| `RWAIOFT.flattened.sol` | Same contract with all imports inlined, for single-file reading |
| `standard-input-json/standard-input-RWAIOFT.json` | Exact solc standard JSON input used for compilation and BscScan verification |
| `RWAIOFT.abi-artifact.json` | Hardhat artifact: ABI, creation and runtime bytecode |
| `deployments/RWAIOFT.bsc-mainnet.json` | hardhat-deploy record: address, tx hash, receipt, constructor args |
| `deploy/RWAIOFT.ts` | Deployment script |

## 7. Reproducing the build

```bash
git clone <repo>
yarn install            # pins the versions listed above
npx hardhat compile     # artifacts/contracts/RWAIOFT.sol/RWAIOFT.json
```

Or feed `standard-input-json/standard-input-RWAIOFT.json` directly to solc 0.8.22.
