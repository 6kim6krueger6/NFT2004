const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const fs = require("fs");

// Данные (адреса и их значения)
const inputs = [
    "0xd149B96b9CD54F9e961E9Ab585696B7898a5b1e1",
    "0x242a826be7c7acb51e3fdf4ea02ab46966d26217",
    "0xff49272d0ee8e1e1d4f1ffb846c042d85cb93c6e",
    "0xa1781b673058244a0455ea752b3354f8e703142b"
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
fs.writeFileSync("merkleTreeMock.json", JSON.stringify(output, null, 4));

console.log("Merkle Tree успешно сохранен в merkleTree.json");
