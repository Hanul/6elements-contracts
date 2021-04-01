// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

contract Defantasy {
    uint256 public constant ENERGY_PRICE = 100000000000000;
    uint8 public constant BASE_SUMMON_ENERGY = 10;
    uint8 public constant BASE_MAP_W = 4;
    uint8 public constant BASE_MAP_H = 4;
    uint8 public constant MAX_MAP_W = 8;
    uint8 public constant MAX_MAP_H = 8;
    uint8 public constant MAX_UNIT_COUNT = 30;
    uint8 public constant MAX_ENTER_COUNT_PER_BLOCK = 8;

    address public developer;
    address public devSupporter;
    mapping(address => uint256) public energies;

    enum ArmyKind {Light, Fire, Water, Wind, Earth, Dark}
    struct Army {
        ArmyKind kind;
        uint8 count;
        address owner;
        uint256 blockNumber;
    }
    Army[MAX_MAP_H][MAX_MAP_W] public map;
    uint8 public mapWidth = BASE_MAP_W;
    uint8 public mapHeight = BASE_MAP_H;

    uint256 public season = 0;
    mapping(uint256 => address) public winners;
    mapping(uint256 => mapping(address => uint256)) public energyUsed;
    mapping(uint256 => mapping(address => mapping(address => uint256)))
        public energySupported;
    mapping(uint256 => mapping(address => uint8)) public occupyCounts;

    mapping(uint256 => uint8) public enterCountsPerBlock;
}
