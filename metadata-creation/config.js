const fs = require('fs');
const width = 1000;
const height = 1000;
const dir = __dirname;

const rarity = [
    {key: "", val: "original"},
    {key: "_r", val: "rare"},
    {key: "_sr", val: "super rare"},
    {key: "_ssr", val: "super super rare"},
]

const addRarity = (_str) => {
   let itemRarity;
   rarity.forEach((r)=>{
    if (_str.includes(r.key)) {
        itemRarity = r.val;
    }
   });
   return itemRarity;
}

const cleanName = (_str) =>{
    let name = _str.slice(0, -4);
    rarity.forEach((r)=>{
        name = name.replace(r.key, "");
    });
    return name;
}

const getElements = path => {
    return fs
      .readdirSync(path)
      .filter((item) => !/(^|\/)\.[^\/\.]/g.test(item))
      .map((i, index) => {
        return {
          id: index + 1,
          name: cleanName(i),
          fileName: i,
          rarity: addRarity(i),
        };
      });
  };

const layers = [
    {
        id: 1,
        name: 'background',
        location: `${dir}/layers/background/`,
        elements:getElements(`${dir}/layers/background/`),
        position : {
            x: 0,
            y: 0
        },
        size: {width: width, height: height},
    },
    {
        id: 2,
        name: 'spine',
        location: `${dir}/layers/spine/`,
        elements:getElements(`${dir}/layers/spine/`),
        position : {
            x: 0,
            y: 0
        },
        size: {width: width, height: height},
    },
    {
        id: 3,
        name: 'body',
        location: `${dir}/layers/body/`,
        elements:getElements(`${dir}/layers/body/`),
        position : {
            x: 0,
            y: 0
        },
        size: {width: width, height: height},
    },
    {
        id: 4,
        name: 'face',
        location: `${dir}/layers/face/`,
        elements:getElements(`${dir}/layers/face/`),
        position : {
            x: 0,
            y: 0
        },
        size: {width: width, height: height},
    },
    {
        id: 5,
        name: 'beard',
        location: `${dir}/layers/beard/`,
        elements:getElements(`${dir}/layers/beard/`),
        position : {
            x: 0,
            y: 0
        },
        size: {width: width, height: height},
    },
    {
        id: 6,
        name: 'hat',
        location: `${dir}/layers/hat/`,
        elements:getElements(`${dir}/layers/hat/`),
        position : {
            x: 0,
            y: 0
        },
        size: {width: width, height: height},
    },
    {
        id: 7,
        name: 'accessories',
        location: `${dir}/layers/accessories/`,
        elements:getElements(`${dir}/layers/accessories/`),
        position : {
            x: 0,
            y: 0
        },
        size: {width: width, height: height},
    },
    {
        id: 8,
        name: 'clothes',
        location: `${dir}/layers/clothes/`,
        elements:getElements(`${dir}/layers/clothes/`),
        position : {
            x: 0,
            y: 0
        },
        size: {width: width, height: height},
    }
]

console.log(layers);

module.exports = {
    layers,
    width,
    height
};