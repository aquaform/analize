// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ACalculator {
    struct Version {
        string version;
        uint8 mainVersion;
        uint8 subVersion;
        uint8 tempVersion;
    }
  
    function getCreator() external virtual view returns(address);
    function getVersion() external virtual view returns(Version memory);
    function add(uint a, uint b) external virtual pure returns(uint);
    function minus(uint a, uint b) external virtual pure returns(uint);
    function multiple(uint a, uint b) external virtual pure returns(uint);
    function division(uint a, uint b) external virtual pure returns(uint);
}
