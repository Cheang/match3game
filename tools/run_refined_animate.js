const fs = require('fs');
const { callMcpTool } = require('./aseprite_mcp.js');

async function main() {
  console.log('1. Cloning clean project to main_menu_bg_animated.aseprite...');
  await callMcpTool('run_lua', {
    sprite: 'assets/level_ui/main_menu_bg_clean.aseprite',
    code: `
      local sprCopy = Sprite(sprite)
      sprCopy:saveCopyAs('assets/aseprite/main_menu_bg_animated.aseprite')
      sprCopy:close()
      return { ok = true }
    `
  });

  console.log('2. Running refined animation...');
  const luaCode = fs.readFileSync('tools/refined_animate.lua', 'utf8');
  const res = await callMcpTool('run_lua', {
    sprite: 'assets/aseprite/main_menu_bg_animated.aseprite',
    code: luaCode,
    save: true
  });
  console.log('Animation created:', JSON.stringify(res, null, 2));

  console.log('3. Exporting full animated GIF and frames...');
  await callMcpTool('export', {
    sprite: 'assets/aseprite/main_menu_bg_animated.aseprite',
    file: 'assets/level_ui/main_menu_animated.gif'
  });

  await callMcpTool('export', {
    sprite: 'assets/aseprite/main_menu_bg_animated.aseprite',
    file: 'assets/level_ui/main_menu_bg_frame_{frame}.png'
  });

  console.log('4. Copying to level_ui as well...');
  fs.copyFileSync(
    'assets/aseprite/main_menu_bg_animated.aseprite',
    'assets/level_ui/main_menu_bg_animated.aseprite'
  );

  console.log('5. Generating animated crops for inspection...');
  async function makeAnimCrop(name, x, y, w, h) {
    const cropLua = `
      local cropSpr = Sprite(${w}, ${h}, sprite.colorMode)
      cropSpr.palettes[1]:resize(#sprite.palettes[1])
      for i = 0, #sprite.palettes[1] - 1 do
        cropSpr.palettes[1]:setColor(i, sprite.palettes[1]:getColor(i))
      end
      while #cropSpr.frames < #sprite.frames do
        cropSpr:newFrame()
      end
      for f = 1, #sprite.frames do
        cropSpr.frames[f].duration = sprite.frames[f].duration
        local srcCel = sprite.layers[1]:cel(f)
        local cropImg = Image(${w}, ${h}, sprite.colorMode)
        cropImg:drawImage(srcCel.image, Point(-${x}, -${y}))
        local cel = cropSpr.layers[1]:cel(f)
        if not cel then cel = cropSpr:newCel(cropSpr.layers[1], f) end
        cel.image = cropImg
      end
      cropSpr:resize(${w * 2}, ${h * 2})
      cropSpr:saveCopyAs('assets/level_ui/${name}.gif')
      cropSpr:close()
      return { ok = true }
    `;
    await callMcpTool('run_lua', {
      sprite: 'assets/aseprite/main_menu_bg_animated.aseprite',
      code: cropLua
    });
  }

  await makeAnimCrop('crop_river_anim', 480, 470, 240, 180);
  await makeAnimCrop('crop_tree_anim', 60, 0, 220, 180);

  console.log('All refined animations and crops exported successfully!');
}

main().catch(console.error);
