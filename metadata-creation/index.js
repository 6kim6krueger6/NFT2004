const fs = require("fs");
const axios = require("axios");
const FormData = require("form-data");
const { createCanvas, loadImage } = require("canvas");
const { layers, width, height } = require("./config.js");
const metadataFilePathTxt = "./output/metadata_links.txt"; 

const API_KEY = "62ad575ad3824bda9e8e";
const API_SECRET = "f5c9ba632943211ed4d4711965566a57b2aec38b3cb005ca2aa0ab1b2f8a4046";
const edition = 100; // Количество NFT
const canvas = createCanvas(width, height);
const ctx = canvas.getContext("2d");

// Функция загрузки файла в IPFS (используется только для изображений)
async function uploadToPinata(filePath) {
    try {
        const formData = new FormData();
        formData.append("file", fs.createReadStream(filePath));

        const url = "https://api.pinata.cloud/pinning/pinFileToIPFS";
        const response = await axios.post(url, formData, {
            headers: {
                "Content-Type": `multipart/form-data; boundary=${formData._boundary}`,
                pinata_api_key: API_KEY,
                pinata_secret_api_key: API_SECRET,
            },
        });

        return response.data.IpfsHash; // Возвращаем только CID
    } catch (error) {
        console.error("❌ Ошибка загрузки на Pinata:", error);
        return null;
    }
}

// Сохранение изображения и его загрузка в IPFS
async function saveLayer(_canvas, _edition, attributes) {
    const imgFilePath = `./output/img/${_edition}.png`;
    fs.writeFileSync(imgFilePath, _canvas.toBuffer("image/png"));
    console.log(`✅ PNG #${_edition} создан`);

    const ipfsImageCID = await uploadToPinata(imgFilePath);
    if (ipfsImageCID) {
        await saveMetadata(ipfsImageCID, _edition, attributes);
    }
}

// Генерация JSON-метаданных в локальную папку
async function saveMetadata(ipfsImageCID, _edition, attributes) {
    const metadata = {
        image: `ipfs://${ipfsImageCID}`,
        attributes,
        name: `NFT #${_edition}`,
    };

    const metadataFilePath = `./output/metadata/${_edition}.json`;
    fs.writeFileSync(metadataFilePath, JSON.stringify(metadata, null, 4));

    console.log(`✅ Метадата сохранена локально: ${metadataFilePath}`);
}

// Функция загрузки всей папки `metadata/` в Pinata
async function uploadMetadataFolderToPinata() {
    try {
        const formData = new FormData();
        const metadataFolderPath = "./output/metadata";

        fs.readdirSync(metadataFolderPath).forEach(file => {
            formData.append("file", fs.createReadStream(`${metadataFolderPath}/${file}`), {
                filepath: `metadata/${file}`
            });
        });

        const url = "https://api.pinata.cloud/pinning/pinFileToIPFS";
        const response = await axios.post(url, formData, {
            headers: {
                "Content-Type": `multipart/form-data; boundary=${formData._boundary}`,
                pinata_api_key: API_KEY,
                pinata_secret_api_key: API_SECRET,
            },
        });

        const baseCID = response.data.IpfsHash;
        const baseUri = `https://ipfs.io/ipfs/${baseCID}/`;
        
        console.log(`📌 Папка загружена! ✅ Base URI: ${baseUri}`);

        fs.writeFileSync("./output/baseUri.txt", baseUri);
        return baseUri;
    } catch (error) {
        console.error("❌ Ошибка загрузки папки:", error);
        return null;
    }
}

// Выбор случайного элемента с учетом редкости
function getRandomElementWeighted(elements) {
    const rarityWeights = {
        "original": 65,
        "rare": 25,
        "super rare": 7,
        "super super rare": 3
    };

    let weightedArray = [];
    elements.forEach(element => {
        let weight = rarityWeights[element.rarity] || 1;
        for (let i = 0; i < weight; i++) {
            weightedArray.push(element);
        }
    });

    return weightedArray[Math.floor(Math.random() * weightedArray.length)];
}

// Отрисовка слоев и сбор данных для метаданных
async function drawLayers(_edition) {
    let attributes = [];

    for (const layer of layers) {
        try {
            let element = getRandomElementWeighted(layer.elements);
            const image = await loadImage(`${layer.location}${element.fileName}`);

            ctx.drawImage(image, layer.position.x, layer.position.y, layer.size.width, layer.size.height);
            console.log(`🎨 Добавлен слой: ${layer.name}, элемент: ${element.name} (${element.rarity})`);

            attributes.push({
                trait_type: layer.name,
                value: element.name,
            });
        } catch (error) {
            console.error("❌ Ошибка загрузки или отрисовки слоя:", error);
        }
    }

    return attributes;
}

// Генерация всех NFT
async function generateNFTs() {
    if (!fs.existsSync("./output/img")) fs.mkdirSync("./output/img", { recursive: true });
    if (!fs.existsSync("./output/metadata")) fs.mkdirSync("./output/metadata", { recursive: true });

    for (let i = 1; i <= edition; i++) {
        ctx.clearRect(0, 0, width, height);
        const attributes = await drawLayers(i);
        await saveLayer(canvas, i, attributes);
    }

    // Загружаем всю папку метадаты и получаем Base URI
    const baseUri = await uploadMetadataFolderToPinata();
    if (baseUri) {
        console.log(`🌍 **Готово! Все NFT доступны по ссылке:** ${baseUri}{tokenId}.json`);
    }
}

generateNFTs();