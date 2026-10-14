// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title RWAIOFT
 * @notice RWAI LayerZero OFT
 *  - 총 발행량 1,000,000,000 RWAI (배포 시 owner 에게 전량 민팅)
 *  - 블랙리스트: owner 가 특정 주소의 송/수신을 차단
 *  - 긴급정지(Pausable): owner 가 모든 전송(브릿지 포함)을 중단
 *  - 오너 변경: OpenZeppelin Ownable 의 transferOwnership / renounceOwnership 사용
 *    (LayerZero delegate 변경은 setDelegate 로 별도 수행)
 */
contract RWAIOFT is Ownable, Pausable, OFT, ERC20Permit, ERC20Burnable {
    string private constant TOKEN_NAME = "RWAI";
    string private constant TOKEN_SYMBOL = "RWAI";
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000;

    mapping(address => bool) private _blacklisted;

    event Blacklisted(address indexed account);
    event UnBlacklisted(address indexed account);

    error AccountBlacklisted(address account);
    error ZeroAddress();

    modifier notBlacklisted(address account) {
        if (_blacklisted[account]) revert AccountBlacklisted(account);
        _;
    }

    /**
     * @param _lzEndpoint LayerZero EndpointV2 주소
     * @param _delegate   컨트랙트 owner 겸 LayerZero delegate. 초기 발행량 전량 수령
     */
    constructor(
        address _lzEndpoint,
        address _delegate
    )
        Ownable(_delegate)
        OFT(TOKEN_NAME, TOKEN_SYMBOL, _lzEndpoint, _delegate)
        ERC20Permit(TOKEN_NAME)
    {
        _mint(_delegate, TOTAL_SUPPLY * 10 ** decimals());
    }

    // ───────────────────────── Blacklist ─────────────────────────

    function blacklist(address account) external onlyOwner {
        if (account == address(0)) revert ZeroAddress();
        _blacklisted[account] = true;
        emit Blacklisted(account);
    }

    function unBlacklist(address account) external onlyOwner {
        _blacklisted[account] = false;
        emit UnBlacklisted(account);
    }

    function blacklistBatch(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] == address(0)) revert ZeroAddress();
            _blacklisted[accounts[i]] = true;
            emit Blacklisted(accounts[i]);
        }
    }

    function unBlacklistBatch(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _blacklisted[accounts[i]] = false;
            emit UnBlacklisted(accounts[i]);
        }
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklisted[account];
    }

    // ───────────────────────── Emergency Pause ─────────────────────────

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ───────────────────────── Overrides ─────────────────────────

    function nonces(address owner) public view override(ERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }

    /// @dev 모든 mint / burn / transfer 가 거치는 단일 훅.
    ///      브릿지 송신(_debit -> _burn), 수신(_credit -> _mint) 도 여기서 차단된다.
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused notBlacklisted(from) notBlacklisted(to) {
        super._update(from, to, amount);
    }
}
