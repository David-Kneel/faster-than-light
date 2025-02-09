// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./abdk-libraries-solidity/ABDKMathQuad.sol";
import "./YieldFarmingToken.sol";

contract YieldFarming is Ownable {
    using SafeERC20 for YieldFarmingToken;
    using ABDKMathQuad for bytes16;

    YieldFarmingToken immutable private token;
    bytes16 private immutable oneDay;
    bytes16 private interestRate;
    bytes16 private multiplier;
    uint private lockTime;
    uint private tokenomicsTimestamp;

    mapping(address => TokenTimelock) private tokenTimeLocks;

    constructor(string memory _tokenName, string memory _tokenSymbol, bytes16 _interestRate, bytes16 _multiplier, uint _lockTime){
        oneDay = ABDKMathQuad.fromUInt(1 days);
        updateTokenomics(_interestRate, _multiplier, _lockTime);
        token = new YieldFarmingToken(_tokenName, _tokenSymbol);
    }

    function updateTokenomics(bytes16 _newInterestRate, bytes16 _newMultiplier, uint _newLockTime) public onlyOwner{
        interestRate = _newInterestRate;
        multiplier = _newMultiplier;
        lockTime = _newLockTime;
        // solhint-disable-next-line not-rely-on-time
        tokenomicsTimestamp = block.timestamp;
    }

    function deposit() public payable {
        // solhint-disable-next-line not-rely-on-time
        TokenTimelock tokenTimeLock = new TokenTimelock(token, _msgSender(), block.timestamp + lockTime);
        tokenTimeLocks[_msgSender()] = tokenTimeLock;
        token.mint(address(tokenTimeLock),
            multiplier.mul(ABDKMathQuad.fromUInt(msg.value))
            .div(
                ABDKMathQuad.fromUInt(1)
                .add(interestRate)
                .pow(
                    // solhint-disable-next-line not-rely-on-time
                    ABDKMathQuad.fromUInt(block.timestamp - tokenomicsTimestamp)
                    .div(oneDay)
                )
            )
            .toUInt()
        );
    }

    function getMyTokenTimelock() public view returns (TokenTimelock) {
        address msgSender = _msgSender();
        require(address(tokenTimeLocks[msgSender]) != address(0), "TokenTimelock not found!");
        return tokenTimeLocks[msgSender];
    }

    function releaseTokens() public {
        getMyTokenTimelock().release();
    }
}