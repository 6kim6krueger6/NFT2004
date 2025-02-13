const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const fs = require("fs");

// Данные (адреса и их значения)
const inputs = [
    "0xF967234Ac7e2B2c309d5820c46c549891d509948",
    "0x91542654B8311F008723C7cb23cBd9DF22a8dD50",
    "0xd149B96b9CD54F9e961E9Ab585696B7898a5b1e1",
    "0x161D12c95c29356E751EB9E46603a5a1b29B6614"
];

const leafNodes = inputs.map((address) => keccak256(address));

// Создаем Merkle Tree
const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });
const merkleRoot = merkleTree.getHexRoot();

// Формируем JSON с данными для каждого адреса
const output = inputs.map((address, index) => {
    const leaf = leafNodes[index]; // Хеш текущего элемента
    const proof = merkleTree.getHexProof(leaf);

    return {
        input: address,
        proof: proof,
        root: merkleRoot,
        leaf: "0x" + leaf.toString("hex"),
    };
});

// Сохраняем JSON в файл
fs.writeFileSync("merkleTree.json", JSON.stringify(output, null, 4));

console.log("Merkle Tree успешно сохранен в merkleTree.json");
