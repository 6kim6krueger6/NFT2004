const fs = require("fs");
const axios = require("axios");
const FormData = require("form-data");
const { createCanvas, loadImage } = require("canvas");
const { layers, width, height } = require("./config.js");
const metadataFilePathTxt = "./output/metadata_links.txt"; // Файл для хранения ссылок

const API_KEY = "62ad575ad3824bda9e8e";
const API_SECRET = "f5c9ba632943211ed4d4711965566a57b2aec38b3cb005ca2aa0ab1b2f8a4046";
const edition = 10; // Количество NFT
const canvas = createCanvas(width, height);
const ctx = canvas.getContext("2d");

// Функция загрузки файла на Pinata
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

        return `ipfs://${response.data.IpfsHash}`;
    } catch (error) {
        console.error("Ошибка загрузки на Pinata:", error);
        return null;
    }
}

// Сохранение изображения и загрузка в IPFS
async function saveLayer(_canvas, _edition, attributes) {
    const imgFilePath = `./output/img/${_edition}.png`;
    fs.writeFileSync(imgFilePath, _canvas.toBuffer("image/png"));
    console.log(`PNG ${_edition} создан`);

    const ipfsImageUrl = await uploadToPinata(imgFilePath);
    if (ipfsImageUrl) {
        await saveMetadata(ipfsImageUrl, _edition, attributes);
    }
}

// Генерация JSON-метаданных
async function saveMetadata(ipfsImageUrl, _edition, attributes) {
    const metadata = {
        image: ipfsImageUrl,
        attributes,
        name: `NFT #${_edition}`,
    };

    const metadataFilePath = `./output/metadata/${_edition}.json`;
    fs.writeFileSync(metadataFilePath, JSON.stringify(metadata, null, 4));

    const ipfsMetadataUrl = await uploadToPinata(metadataFilePath);
    if (ipfsMetadataUrl) {
        console.log(`NFT #${_edition} Metadata URL:`, ipfsMetadataUrl);
        saveMetadataLink(ipfsMetadataUrl); // Сохранение в Solidity-файл
    }
}

function saveMetadataLink(ipfsMetadataUrl) {
    let data = "";

    // Проверяем, существует ли уже файл с ссылками
    if (fs.existsSync(metadataFilePathTxt)) {
        data = fs.readFileSync(metadataFilePathTxt, "utf-8").trim();
        // Убираем `];`, если он есть, чтобы добавить новую ссылку
        if (data.endsWith("];")) {
            data = data.slice(0, -2); 
        }
    } else {
        // Если файла нет, создаем начало массива
        data = "string[] public metadataLinks = [";
    }

    // Добавляем новую ссылку
    if (data.length > 30) { // Чтобы избежать начальной пустой строки
        data += ", ";
    }
    data += `"${ipfsMetadataUrl}"`;

    // Закрываем массив и записываем в файл
    fs.writeFileSync(metadataFilePathTxt, `${data}];`);
}

function getRandomElementWeighted(elements) {
    const rarityWeights = {
        "original": 65,
        "rare": 25,
        "super rare": 7,
        "super super rare": 3
    };

    // Создаем массив элементов с повторением в зависимости от веса
    let weightedArray = [];
    elements.forEach(element => {
        let weight = rarityWeights[element.rarity] || 1; // Если редкость не указана, ставим минимальный вес
        for (let i = 0; i < weight; i++) {
            weightedArray.push(element);
        }
    });

    // Выбираем случайный элемент из взвешенного массива
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
            console.log(`Добавлен слой: ${layer.name}, элемент: ${element.name} (${element.rarity})`);

            attributes.push({
                trait_type: layer.name,
                value: element.name,
            });
        } catch (error) {
            console.error("Ошибка загрузки или отрисовки слоя:", error);
        }
    }

    return attributes;
}

// Генерация NFT
async function generateNFTs() {
    if (!fs.existsSync("./output/img")) fs.mkdirSync("./output/img", { recursive: true });
    if (!fs.existsSync("./output/metadata")) fs.mkdirSync("./output/metadata", { recursive: true });

    for (let i = 1; i <= edition; i++) {
        ctx.clearRect(0, 0, width, height); // Очищаем холст перед каждым новым NFT
        const attributes = await drawLayers(i);
        await saveLayer(canvas, i, attributes);
    }
}

generateNFTs();
