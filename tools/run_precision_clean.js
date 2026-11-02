const fs = require('fs');
const { callMcpTool } = require('./aseprite_mcp.js');

async function main() {
  console.log('1. Loading original into test_precision.aseprite...');
  await callMcpTool('run_lua', {
    sprite: 'assets/level_ui/main_menu_n_bg.png.bak',
    code: `
      local sprCopy = Sprite(sprite)
      sprCopy:saveCopyAs('assets/level_ui/test_precision.aseprite')
      sprCopy:close()
      return { ok = true }
    `
  });

  console.log('2. Running precision cleanup...');
  const luaCode = fs.readFileSync('tools/precision_clean.lua', 'utf8');
  const res = await callMcpTool('run_lua', {
    sprite: 'assets/level_ui/test_precision.aseprite',
    code: luaCode,
    save: true
  });
  console.log('Clean result:', JSON.stringify(res, null, 2));

  console.log('3. Generating test crops...');
  async function makeCrop(name, x, y, w, h) {
    const cropLua = `
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
    await callMcpTool('run_lua', { sprite: 'assets/level_ui/test_precision.aseprite', code: cropLua });
  }

  await makeCrop('crop_village_prec', 400, 320, 200, 150);
  await makeCrop('crop_mountain_prec', 450, 150, 200, 150);
  await makeCrop('crop_sky_prec', 650, 100, 200, 150);
  console.log('Crops generated!');
}

main().catch(console.error);
