const fs = require('fs');
const { callMcpTool } = require('./aseprite_mcp.js');

async function main() {
  console.log('1. Copying original into test_clean_final.aseprite...');
  await callMcpTool('run_lua', {
    sprite: 'assets/level_ui/main_menu_n_bg.png.bak',
    code: `
      local sprCopy = Sprite(sprite)
      sprCopy:saveCopyAs('assets/level_ui/test_clean_final.aseprite')
      sprCopy:close()
      return { ok = true }
    `
  });

  console.log('2. Running orphan-only clean...');
  const luaCode = fs.readFileSync('tools/clean_orphans_only.lua', 'utf8');
  const res = await callMcpTool('run_lua', {
    sprite: 'assets/level_ui/test_clean_final.aseprite',
    code: luaCode,
    save: true
  });
  console.log('Result:', JSON.stringify(res, null, 2));

  console.log('3. Exporting test crops and full image...');
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
    await callMcpTool('run_lua', { sprite: 'assets/level_ui/test_clean_final.aseprite', code: cropLua });
  }

  await makeCrop('crop_village_clean', 400, 320, 200, 150);
  await makeCrop('crop_mountain_clean', 450, 150, 200, 150);
  await makeCrop('crop_river_clean', 450, 520, 250, 150);
  await makeCrop('crop_sky_clean', 650, 100, 200, 150);

  await callMcpTool('export', {
    sprite: 'assets/level_ui/test_clean_final.aseprite',
    file: 'assets/level_ui/test_clean_full.png'
  });
  console.log('All crops and full image exported successfully!');
}

main().catch(console.error);
