// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ACalculator} from "./ACalculator.sol";

contract CalculatorCaller {
    error NotOwner();
    error ZeroAddress();
    error CallFailed(string what);
    error NotRegistered();
    error AlreadyRegistered();

    event NewLatestVersion(address indexed calculator, string version);
    event VersionSelected(address indexed user, string version);
    event CalculatorRegistered(address indexed calculator, string version);

    mapping(string => address) private calculators;
    mapping(address => string) private userSelectedVersion;
    ACalculator.Version private lastVersion;
    address public immutable owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address firstCalculator) {
        if (firstCalculator == address(0)) revert ZeroAddress();
        owner = msg.sender;

        ACalculator.Version memory v = _fetchVersion(firstCalculator);
        lastVersion = v;
        calculators[v.version] = firstCalculator;

        emit CalculatorRegistered(firstCalculator, v.version);
        emit NewLatestVersion(firstCalculator, v.version);
    }

    function fund(address payable to) external payable {
        if (to == address(0)) revert ZeroAddress();
        (bool ok, ) = to.call{value: msg.value}("");
        if (!ok) revert CallFailed("fund");
    }

    function take() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool ok, ) = payable(owner).call{value: balance}("");
        if (!ok) revert CallFailed("take");
    }

    function supportCalculatorCreator(address calculator) external payable {
        if (calculator == address(0)) revert ZeroAddress();

        ACalculator.Version memory v = _fetchVersion(calculator);
        if (calculators[v.version] == address(0)) revert NotRegistered();

        (bool success, bytes memory data) = calculator.call(abi.encodeWithSelector(ACalculator.getCreator.selector));
        if (!success || data.length < 32) revert CallFailed("getCreator");
        address creator = abi.decode(data, (address));

        (bool ok, ) = payable(creator).call{value: msg.value}("");
        if (!ok) revert CallFailed("payout");
    }

    function _getUserSelectedVersion(address user) internal view returns (address) {
        string memory uv = userSelectedVersion[user];
        if (bytes(uv).length > 0 && calculators[uv] != address(0)) {
            return calculators[uv];
        }
        return calculators[lastVersion.version];
    }

    function changeSelectedVersion(string calldata _version) external returns (address currentAddress) {
        bool isFound = calculators[_version] != address(0);
        userSelectedVersion[msg.sender] = isFound ? _version : "";
        currentAddress = isFound ? calculators[_version] : calculators[lastVersion.version];
        emit VersionSelected(msg.sender, isFound ? _version : "");
    }

    function addNewCalculator(address newCalculator) external onlyOwner {
        if (newCalculator == address(0)) revert ZeroAddress();

        ACalculator.Version memory v = _fetchVersion(newCalculator);
        if (calculators[v.version] != address(0)) revert AlreadyRegistered();

        calculators[v.version] = newCalculator;
        emit CalculatorRegistered(newCalculator, v.version);

        uint8 m = lastVersion.mainVersion;
        uint8 s = lastVersion.subVersion;
        uint8 t = lastVersion.tempVersion;

        bool newer =
            v.mainVersion > m ||
            (v.mainVersion == m && v.subVersion > s) ||
            (v.mainVersion == m && v.subVersion == s && v.tempVersion > t);

        if (newer) {
            lastVersion = v;
            emit NewLatestVersion(newCalculator, v.version);
        }
    }

    function getCalculator(string calldata _version) external view returns (address) {
        return calculators[_version];
    }

    function getLastVersion() external view returns (ACalculator.Version memory) {
        return lastVersion;
    }

    function getUserVersion(address user) external view returns (string memory) {
        return userSelectedVersion[user];
    }

    function callAdd(uint a, uint b) external returns (uint) {
        return _proxy(ACalculator.add.selector, a, b, "callAdd");
    }

    function callMinus(uint a, uint b) external returns (uint) {
        return _proxy(ACalculator.minus.selector, a, b, "callMinus");
    }

    function callMultiple(uint a, uint b) external returns (uint) {
        return _proxy(ACalculator.multiple.selector, a, b, "callMultiple");
    }

    function callDivision(uint a, uint b) external returns (uint) {
        return _proxy(ACalculator.division.selector, a, b, "callDivision");
    }

    function _proxy(bytes4 selector, uint a, uint b, string memory what) internal returns (uint) {
        address target = _getUserSelectedVersion(msg.sender);
        (bool success, bytes memory data) = target.call(abi.encodeWithSelector(selector, a, b));
        if (!success) {
            if (data.length > 0) {
                assembly {
                    let len := mload(data)
                    revert(add(data, 32), len)
                }
            }
            revert CallFailed(what);
        }
        return abi.decode(data, (uint));
    }

    function _fetchVersion(address target) internal view returns (ACalculator.Version memory) {
        (bool success, bytes memory data) = target.staticcall(abi.encodeWithSelector(ACalculator.getVersion.selector));
        if (!success || data.length == 0) revert CallFailed("getVersion");
        return abi.decode(data, (ACalculator.Version));
    }
}
