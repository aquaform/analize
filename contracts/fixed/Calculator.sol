// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ACalculator.sol";

contract Calculator is ACalculator {
    error DivisionByZero();

    Version private version;
    address private immutable creator;

    constructor(uint8 _first, uint8 _sub, uint8 _temp) {
        string memory s1 = uintToString(uint256(_first));
        string memory s2 = uintToString(uint256(_sub));
        string memory s3 = uintToString(uint256(_temp));
        version = Version(string.concat(s1, ".", s2, ".", s3), _first, _sub, _temp);
        creator = msg.sender;
    }

    function getCreator() external override view returns(address) {
        return creator;
    }

    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            unchecked { digits++; }
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            unchecked { digits--; }
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function add(uint a, uint b) external override pure returns(uint) { return a + b; }
    function multiple(uint a, uint b) external override pure returns(uint) { return a * b; }

    function division(uint a, uint b) external override pure returns(uint) {
        if (b == 0) revert DivisionByZero();
        return a / b;
    }

    function minus(uint a, uint b) external override pure returns(uint) { return a - b; }

    function getVersion() external override view returns(Version memory) { return version; }
}
