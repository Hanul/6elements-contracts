// SPDX-License-Identifier: MIT
pragma solidity ^0.7.5;

contract Defantasy {
    uint256 public constant ENERGY_PRICE = 100000000000000;
    uint256 public constant SUMMON_ENERGY = 10;
    uint256 public constant MOVE_ENERGY = 1;
    uint256 public constant MAP_W = 9;
    uint256 public constant MAP_H = 9;
    uint256 public constant TOTAL = MAP_W * MAP_H;

    address payable public author;

    constructor() {
        author = msg.sender;
    }

    address[] public participants;
    mapping(address => bool) public participated;
    mapping(address => uint256) private energies;

    function participate() internal {
        if (participated[msg.sender] != true) {
            participated[msg.sender] = true;
            participants.push(msg.sender);
        }
    }

    function buyEnergy() external payable {
        uint256 quantity = msg.value / ENERGY_PRICE;
        energies[msg.sender] += quantity;
        assert(energies[msg.sender] >= quantity);
        participate();

        // 3.75% fee.
        author.transfer((msg.value / 10000) * 375);
    }

    struct Support {
        address to;
        uint256 quantity;
    }
    mapping(address => Support[]) private supported;

    function support(address to, uint256 quantity) external {
        require(quantity <= energies[msg.sender]);
        energies[msg.sender] -= quantity;

        energies[to] += quantity;
        assert(energies[to] >= quantity);

        supported[msg.sender].push(Support({to: to, quantity: quantity}));
    }

    uint256 public season = 1;

    enum ArmyKind {Light, Fire, Water, Wind, Earth, Dark}
    struct Army {
        ArmyKind kind;
        uint256 count;
        address owner;
    }
    Army[MAP_H][MAP_W] public map;
    mapping(address => uint16) private occupied;

    function enter(
        uint8 x,
        uint8 y,
        ArmyKind kind,
        uint256 count
    ) external {
        require(x < MAP_W);
        require(y < MAP_H);
        require(kind >= ArmyKind.Light && kind <= ArmyKind.Dark);
        require(energies[msg.sender] >= count * SUMMON_ENERGY);
        require(map[y][x].owner == address(0));

        // must first time.
        for (uint8 mapY = 0; mapY < MAP_H; mapY += 1) {
            for (uint8 mapX = 0; mapX < MAP_W; mapX += 1) {
                if (map[mapY][mapX].owner == msg.sender) {
                    revert();
                }
            }
        }

        map[y][x] = Army({kind: kind, count: count, owner: msg.sender});
        occupied[msg.sender] = 1;
    }

    function calculateDamage(Army memory from, Army memory to) pure internal returns(uint256) {

        uint256 damage = from.count;

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
        require(fromX < MAP_W);
        require(fromY < MAP_H);
        require(toX < MAP_W);
        require(toY < MAP_H);

        require(
            (fromX < toX ? toX - fromX : fromX - toX) +
            (fromY < toY ? toY - fromY : fromY - toY) == 1
        );

        Army storage from = map[fromY][fromX];
        Army storage to = map[toY][toX];

        require(from.owner == msg.sender);

        // move.
        if (to.owner == address(0)) {
            map[toY][toX] = from;
            delete map[fromY][fromX];
        }

        // combine.
        else if (to.owner == msg.sender) {
            require(to.kind == from.kind);
            to.count += from.count;
            assert(to.count >= from.count);
            
            occupied[msg.sender] -= 1;
            delete map[fromY][fromX];
        }
        
        // attack.
        else {
            uint256 fromDamage = calculateDamage(from, to);
            uint256 toDamage = calculateDamage(to, from);

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

        // win.
        if (occupied[msg.sender] == TOTAL) {
            reward(msg.sender);
            clear();
        }
    }

    function reward(address winner) internal {
        // calculate reward rate.
    }

    function clear() internal {
        for (uint256 i = 0; i < participants.length; i += 1) {
            delete participated[participants[i]];
            delete energies[participants[i]];
            delete supported[participants[i]];
            delete occupied[participants[i]];
        }
        delete participants;
        delete map;
    }
}
