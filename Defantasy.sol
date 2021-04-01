// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

contract Defantasy {
    event EndSeason(uint256 season);
    //TODO: needs more events

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
        uint8 unitCount;
        address owner;
        uint256 blockNumber;
    }
    Army[MAX_MAP_H][MAX_MAP_W] public map;
    uint8 public mapWidth = BASE_MAP_W;
    uint8 public mapHeight = BASE_MAP_H;

    uint256 public season = 0;
    mapping(uint256 => uint256) public rewards;
    mapping(uint256 => address) public winners;
    mapping(uint256 => uint256) public rewardBases;
    mapping(uint256 => mapping(address => bool)) public withdrawns;

    mapping(uint256 => mapping(address => uint256)) public energyUsed;
    mapping(uint256 => mapping(address => uint256)) public energyTaken;
    mapping(uint256 => mapping(address => mapping(address => uint256)))
        public energySupported;
    mapping(uint256 => mapping(address => uint8)) public occupyCounts;

    mapping(uint256 => uint8) public enterCountsPerBlock;

    constructor(address _devSupporter) {
        developer = msg.sender;
        devSupporter = _devSupporter;
    }

    function changeDeveloper(address newDeveloper) external {
        require(developer == msg.sender);
        developer = newDeveloper;
    }

    function changeDevSupporter(address newDevSupporter) external {
        require(devSupporter == msg.sender);
        devSupporter = newDevSupporter;
    }

    function buyEnergy() external payable {
        energies[msg.sender] += msg.value / ENERGY_PRICE;
        rewards[season] += (msg.value / 10) * 9;
        payable(developer).transfer(msg.value / 25); // 4% fee.
        payable(devSupporter).transfer(msg.value / 100); // 1% fee.
    }

    function joinGame(
        uint8 x,
        uint8 y,
        ArmyKind kind,
        uint8 unitCount
    ) external {
        require(enterCountsPerBlock[block.number] <= MAX_ENTER_COUNT_PER_BLOCK);
        require(x < mapWidth && y < mapHeight && map[y][x].owner == address(0));
        require(kind >= ArmyKind.Light && kind <= ArmyKind.Dark);
        require(unitCount <= MAX_UNIT_COUNT);
        require(occupyCounts[season][msg.sender] == 0);

        uint256 energyNeed = unitCount * (BASE_SUMMON_ENERGY + season);
        require(energies[msg.sender] >= energyNeed);

        energies[msg.sender] -= energyNeed;
        energyUsed[season][msg.sender] += energyNeed;

        map[y][x] = Army({
            kind: kind,
            unitCount: unitCount,
            owner: msg.sender,
            blockNumber: block.number
        });
        occupyCounts[season][msg.sender] = 1;

        enterCountsPerBlock[block.number] += 1;
    }

    function createArmy(
        uint8 x,
        uint8 y,
        ArmyKind kind,
        uint8 unitCount
    ) external {
        require(x < mapWidth && y < mapHeight && map[y][x].owner == address(0));
        require(kind >= ArmyKind.Light && kind <= ArmyKind.Dark);
        require(unitCount <= MAX_UNIT_COUNT);

        // check if there are allies nearby.
        require(
            (x >= 1 &&
                map[y][x - 1].owner == msg.sender &&
                map[y][x - 1].blockNumber < block.number) ||
                (y >= 1 &&
                    map[y - 1][x].owner == msg.sender &&
                    map[y - 1][x].blockNumber < block.number) ||
                (x < mapWidth - 1 &&
                    map[y][x + 1].owner == msg.sender &&
                    map[y][x + 1].blockNumber < block.number) ||
                (y < mapHeight - 1 &&
                    map[y + 1][x].owner == msg.sender &&
                    map[y + 1][x].blockNumber < block.number)
        );

        uint256 energyNeed = unitCount * (BASE_SUMMON_ENERGY + season);
        require(energies[msg.sender] >= energyNeed);

        energies[msg.sender] -= energyNeed;
        energyUsed[season][msg.sender] += energyNeed;

        map[y][x] = Army({
            kind: kind,
            unitCount: unitCount,
            owner: msg.sender,
            blockNumber: block.number
        });
        occupyCounts[season][msg.sender] += 1;

        // win.
        if (occupyCounts[season][msg.sender] == mapWidth * mapHeight) {
            winners[season] = msg.sender;
            rewardBases[season] =
                rewards[season] /
                (energyUsed[season][msg.sender] +
                    energyTaken[season][msg.sender]);
            emit EndSeason(season);

            delete map;
            season += 1;

            // expand map every 5 seasons until maximum size.
            if (season % 5 == 0) {
                if (mapWidth < MAX_MAP_W) {
                    mapWidth += 1;
                }
                if (mapHeight < MAX_MAP_H) {
                    mapHeight += 1;
                }
            }
        }
    }

    function appendUnits(
        uint8 x,
        uint8 y,
        uint8 unitCount
    ) external {
        require(x < mapWidth && y < mapHeight && map[y][x].owner == msg.sender);

        uint16 newUnitCount = map[y][x].unitCount + unitCount;
        require(newUnitCount <= MAX_UNIT_COUNT);

        uint256 energyNeed = unitCount * (BASE_SUMMON_ENERGY + season);
        require(energies[msg.sender] >= energyNeed);

        energies[msg.sender] -= energyNeed;
        energyUsed[season][msg.sender] += energyNeed;
        map[y][x].unitCount = unitCount;
    }

    function calculateDamage(Army memory from, Army memory to)
        internal
        pure
        returns (uint8)
    {
        uint16 damage = from.unitCount;

        // Light -> *2 -> Dark
        if (from.kind == ArmyKind.Light) {
            if (to.kind == ArmyKind.Dark) {
                damage *= 2;
            }
        }
        // Dark -> *1.25 -> Fire, Water, Wind, Earth
        else if (from.kind == ArmyKind.Dark) {
            if (
                to.kind == ArmyKind.Fire ||
                to.kind == ArmyKind.Water ||
                to.kind == ArmyKind.Wind ||
                to.kind == ArmyKind.Earth
            ) {
                damage = (damage * 125) / 100;
            }
        }
        // Fire, Water, Wind, Earth -> *1.25 -> Light
        else if (to.kind == ArmyKind.Light) {
            damage = (damage * 125) / 100;
        }
        // Fire -> *1.5 -> Wind
        // Wind -> *1.5 -> Earth
        // Earth -> *1.5 -> Water
        // Water -> *1.5 -> Fire
        else if (
            (from.kind == ArmyKind.Fire && to.kind == ArmyKind.Wind) ||
            (from.kind == ArmyKind.Wind && to.kind == ArmyKind.Earth) ||
            (from.kind == ArmyKind.Earth && to.kind == ArmyKind.Water) ||
            (from.kind == ArmyKind.Water && to.kind == ArmyKind.Fire)
        ) {
            damage = (damage * 15) / 10;
        }

        return uint8(damage);
    }

    function attack(
        uint8 fromX,
        uint8 fromY,
        uint8 toX,
        uint8 toY
    ) external {
        require(fromX < mapWidth && fromY < mapHeight);
        require(toX < mapWidth && toY < mapHeight);
        require(
            (fromX < toX ? toX - fromX : fromX - toX) +
                (fromY < toY ? toY - fromY : fromY - toY) ==
                1
        );

        Army storage from = map[fromY][fromX];
        Army storage to = map[toY][toX];

        require(from.owner == msg.sender);
        require(from.blockNumber < block.number);

        // move.
        if (to.owner == address(0)) {
            map[toY][toX] = from;
            delete map[fromY][fromX];
        }
        // combine.
        else if (to.owner == msg.sender) {
            require(to.kind == from.kind);

            uint8 unitCount = to.unitCount + from.unitCount;
            require(unitCount <= MAX_UNIT_COUNT);

            to.unitCount = unitCount;

            occupyCounts[season][msg.sender] -= 1;
            delete map[fromY][fromX];
        }
        // attack.
        else {
            uint8 fromDamage = calculateDamage(from, to);
            uint8 toDamage = calculateDamage(to, from);

            if (fromDamage >= to.unitCount) {
                occupyCounts[season][to.owner] -= 1;
                delete map[toY][toX];
            } else {
                to.unitCount -= fromDamage;
            }

            if (toDamage >= from.unitCount) {
                occupyCounts[season][msg.sender] -= 1;
                delete map[fromY][fromX];
            } else {
                from.unitCount -= toDamage;
            }

            // occupy.
            if (from.owner == msg.sender && to.owner == address(0)) {
                map[toY][toX] = from;
                delete map[fromY][fromX];
            }
        }
    }

    function support(address to, uint256 quantity) external {
        require(energies[msg.sender] >= quantity);
        energies[msg.sender] -= quantity;
        energies[to] += quantity;
        energyTaken[season][to] += quantity;
        energySupported[season][msg.sender][to] += quantity;
    }

    function withdraw(uint256 targetSeason) external {
        require(withdrawns[targetSeason][msg.sender] != true);

        address winner = winners[targetSeason];
        if (msg.sender == winner) {
            payable(msg.sender).transfer(
                rewardBases[targetSeason] * energyUsed[targetSeason][msg.sender]
            );
        }

        payable(msg.sender).transfer(
            rewardBases[targetSeason] *
                energySupported[targetSeason][msg.sender][winner]
        );

        withdrawns[targetSeason][msg.sender] = true;
    }
}
