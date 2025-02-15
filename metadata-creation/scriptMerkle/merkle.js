const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const fs = require("fs");

// Данные (адреса и их значения)
const inputs = [
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
    "0x90F79bf6EB2c4f870365E785982E1f101E93b906"
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
