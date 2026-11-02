const { callMcpTool } = require('./aseprite_mcp.js');

async function makeCrop(name, x, y, w, h) {
  const luaCode = `
    local img = Image(sprite.spec)
    img:drawSprite(sprite, 1)
    local cropSpr = Sprite(${w}, ${h}, sprite.colorMode)
    cropSpr.palettes[1]:resize(#sprite.palettes[1])
    for i = 0, #sprite.palettes[1] - 1 do
      cropSpr.palettes[1]:setColor(i, sprite.palettes[1]:getColor(i))
    end
    local cropImg = Image(${w}, ${h}, sprite.colorMode)
    cropImg:drawImage(img, Point(-${x}, -${y}))
    cropSpr.cels[1].image = cropImg
    cropSpr:resize(${w * 3}, ${h * 3})
    cropSpr:saveCopyAs('assets/level_ui/${name}.png')
    cropSpr:close()
    return { ok = true }
  `;

  await callMcpTool('run_lua', {
    sprite: 'assets/level_ui/main_menu_n_bg.png',
    code: luaCode
  });
}

async function run() {
  await makeCrop('crop_sky', 650, 100, 200, 150);
  await makeCrop('crop_mountain', 450, 150, 200, 150);
  await makeCrop('crop_village', 400, 320, 200, 150);
  console.log('Crops generated');
}

run().catch(console.error);
