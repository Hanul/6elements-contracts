// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

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

    uint256 public season = 0;
    uint8 public mapWidth = BASE_MAP_W;
    uint8 public mapHeight = BASE_MAP_H;
    mapping(uint256 => uint8) private enterCounts;

    struct Record {
        address winner;
        uint256 reward;
        address[] supporters;
        uint256[] supporterRewards;
    }
    mapping(uint256 => Record) private records;

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

    mapping(address => uint256) private energies;

    function buyEnergy() external payable {
        uint256 quantity = msg.value / ENERGY_PRICE;
        energies[msg.sender] += quantity;
        assert(energies[msg.sender] >= quantity);

        payable(developer).transfer((msg.value / 100) * 3); // 3% fee.
        payable(devSupporter).transfer((msg.value / 1000) * 3); // 0.3% fee.
    }

    address[] public participants;
    mapping(address => bool) public participated;
    mapping(address => uint256) private energyUsed;

    function participate() internal {
        if (participated[msg.sender] != true) {
            participated[msg.sender] = true;
            participants.push(msg.sender);
        }
    }

    struct Support {
        address to;
        uint256 quantity;
    }
    mapping(address => Support[]) private supported;

    function support(address to, uint256 quantity) external {
        require(quantity <= energies[msg.sender]);

        participate();
        energies[msg.sender] -= quantity;
        energyUsed[msg.sender] += quantity;

        energies[to] += quantity;
        assert(energies[to] >= quantity);

        supported[msg.sender].push(Support({to: to, quantity: quantity}));
    }

    enum ArmyKind {Light, Fire, Water, Wind, Earth, Dark}
    struct Army {
        ArmyKind kind;
        uint16 count;
        address owner;
        uint256 blockNumber;
    }
    Army[MAX_MAP_H][MAX_MAP_W] public map;
    mapping(address => uint16) private occupied;

    function enter(
        uint8 x,
        uint8 y,
        ArmyKind kind,
        uint16 count
    ) external {
        require(x < mapWidth);
        require(y < mapHeight);
        require(kind >= ArmyKind.Light && kind <= ArmyKind.Dark);
        require(map[y][x].owner == address(0));
        require(count <= MAX_UNIT_COUNT);
        require(enterCounts[block.number] <= MAX_ENTER_COUNT_PER_BLOCK);

        uint256 needEnergy = count * (BASE_SUMMON_ENERGY + season);
        require(energies[msg.sender] >= needEnergy);

        // must first time.
        for (uint8 mapY = 0; mapY < mapHeight; mapY += 1) {
            for (uint8 mapX = 0; mapX < mapWidth; mapX += 1) {
                if (map[mapY][mapX].owner == msg.sender) {
                    revert();
                }
            }
        }

        participate();

        energies[msg.sender] -= needEnergy;
        energyUsed[msg.sender] += needEnergy;
        map[y][x] = Army({
            kind: kind,
            count: count,
            owner: msg.sender,
            blockNumber: block.number
        });
        occupied[msg.sender] = 1;

        enterCounts[block.number] += 1;
    }

    function createArmy(
        uint8 x,
        uint8 y,
        ArmyKind kind,
        uint16 count
    ) external {
        require(x < mapWidth);
        require(y < mapHeight);
        require(kind >= ArmyKind.Light && kind <= ArmyKind.Dark);
        require(map[y][x].owner == address(0));
        require(map[y][x].blockNumber < block.number);
        require(count <= MAX_UNIT_COUNT);

        uint256 needEnergy = count * (BASE_SUMMON_ENERGY + season);
        require(energies[msg.sender] >= needEnergy);

        // check if there are allies nearby
        if (
            (x >= 1 && map[y][x - 1].owner == msg.sender) ||
            (y >= 1 && map[y - 1][x].owner == msg.sender) ||
            (x < mapWidth - 1 && map[y][x + 1].owner == msg.sender) ||
            (y < mapHeight - 1 && map[y + 1][x].owner == msg.sender)
        ) {
            energies[msg.sender] -= needEnergy;
            energyUsed[msg.sender] += needEnergy;
            map[y][x] = Army({
                kind: kind,
                count: count,
                owner: msg.sender,
                blockNumber: block.number
            });
            occupied[msg.sender] += 1;

            // win.
            if (occupied[msg.sender] == mapWidth * mapHeight) {
                reward(msg.sender);
                endSeason();
            }
        } else {
            revert();
        }
    }

    function appendUnit(
        uint8 x,
        uint8 y,
        uint16 count
    ) external {
        require(x < mapWidth);
        require(y < mapHeight);
        require(map[y][x].owner == msg.sender);

        uint16 unitCount = map[y][x].count + count;
        require(unitCount >= map[y][x].count);
        require(unitCount <= MAX_UNIT_COUNT);

        uint256 needEnergy = count * (BASE_SUMMON_ENERGY + season);
        require(energies[msg.sender] >= needEnergy);

        energies[msg.sender] -= needEnergy;
        energyUsed[msg.sender] += needEnergy;
        map[y][x].count = unitCount;
    }

    function calculateDamage(Army memory from, Army memory to)
        internal
        pure
        returns (uint16)
    {
        uint16 damage = from.count;

        // Light -> *2 -> Dark
        if (from.kind == ArmyKind.Light) {
            if (to.kind == ArmyKind.Dark) {
                damage *= 2;
                assert(damage / 2 == from.count);
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
                damage = damage * 125;
                assert(damage / 125 == from.count);
                damage /= 100;
            }
        }
        // Fire, Water, Wind, Earth -> *1.25 -> Light
        else if (to.kind == ArmyKind.Light) {
            damage = damage * 125;
            assert(damage / 125 == from.count);
            damage /= 100;
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
            damage = damage * 15;
            assert(damage / 15 == from.count);
            damage /= 10;
        }

        return damage;
    }

    function attack(
        uint8 fromX,
        uint8 fromY,
        uint8 toX,
        uint8 toY
    ) external {
        require(fromX < mapWidth);
        require(fromY < mapHeight);
        require(toX < mapWidth);
        require(toY < mapHeight);

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

            uint16 unitCount = to.count + from.count;
            require(unitCount >= to.count);
            require(unitCount <= MAX_UNIT_COUNT);

            to.count = unitCount;

            occupied[msg.sender] -= 1;
            delete map[fromY][fromX];
        }
        // attack.
        else {
            uint16 fromDamage = calculateDamage(from, to);
            uint16 toDamage = calculateDamage(to, from);

            if (fromDamage >= to.count) {
                occupied[to.owner] -= 1;
                delete map[toY][toX];
            } else {
                to.count -= fromDamage;
            }

            if (toDamage >= from.count) {
                occupied[msg.sender] -= 1;
                delete map[fromY][fromX];
            } else {
                from.count -= toDamage;
            }

            // occupy.
            if (from.owner == msg.sender && to.owner == address(0)) {
                map[toY][toX] = from;
                delete map[fromY][fromX];
            }
        }
    }

    function reward(address winner) internal {
        uint256[] memory supportEnergies = new uint256[](participants.length);
        uint256 supportedEnergy = 0;
        uint256 supporterCount = 0;

        for (uint256 i = 0; i < participants.length; i += 1) {
            for (uint256 j = 0; j < supported[participants[i]].length; j += 1) {
                Support memory s = supported[participants[i]][j];
                if (s.to == winner) {
                    supportEnergies[i] += s.quantity;
                    supportedEnergy += s.quantity;
                }
            }
            if (supportEnergies[i] > 0) {
                supporterCount += 1;
            }
        }

        uint256 winnerEnergy = energyUsed[winner];
        uint256 base =
            (address(this).balance * 90) /
                100 / // 10% is for next season.
                (winnerEnergy + supportedEnergy);

        uint256 winnerReward = base * winnerEnergy;

        address[] memory supporters = new address[](supporterCount);
        uint256[] memory supporterRewards = new uint256[](supporterCount);

        uint256 index;
        for (uint256 i = 0; i < participants.length; i += 1) {
            if (supportEnergies[i] > 0) {
                supporters[index] = participants[i];
                supporterRewards[index] = base * supportEnergies[i];
                index += 1;
            }
        }

        records[season] = Record({
            winner: winner,
            reward: winnerReward,
            supporters: supporters,
            supporterRewards: supporterRewards
        });

        payable(winner).transfer(winnerReward);
        for (uint256 i = 0; i < supporters.length; i += 1) {
            payable(supporters[i]).transfer(supporterRewards[i]);
        }
    }

    function endSeason() internal {
        for (uint256 i = 0; i < participants.length; i += 1) {
            delete participated[participants[i]];
            delete supported[participants[i]];
            delete occupied[participants[i]];
            delete energyUsed[participants[i]];
        }
        delete participants;
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
