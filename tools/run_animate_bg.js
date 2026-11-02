const fs = require('fs');
const { callMcpTool } = require('./aseprite_mcp.js');

async function main() {
  console.log('1. Setting up main_menu_bg_animated.aseprite...');
  await callMcpTool('run_lua', {
    sprite: 'assets/level_ui/main_menu_bg_clean.aseprite',
    code: `
      local sprCopy = Sprite(sprite)
      sprCopy:saveCopyAs('assets/aseprite/main_menu_bg_animated.aseprite')
      sprCopy:close()
      return { ok = true }
    `
  });

  console.log('2. Running animate script...');
  const luaCode = fs.readFileSync('tools/animate_bg.lua', 'utf8');
  const res = await callMcpTool('run_lua', {
    sprite: 'assets/aseprite/main_menu_bg_animated.aseprite',
    code: luaCode,
    save: true
  });
  console.log('Animation created:', JSON.stringify(res, null, 2));

  console.log('3. Exporting preview GIF...');
  await callMcpTool('export', {
    sprite: 'assets/aseprite/main_menu_bg_animated.aseprite',
    file: 'assets/level_ui/main_menu_preview.gif'
  });

  console.log('4. Exporting frame PNGs...');
  await callMcpTool('export', {
    sprite: 'assets/aseprite/main_menu_bg_animated.aseprite',
    file: 'assets/level_ui/main_menu_bg_frame_{frame}.png'
  });

  console.log('All exports complete!');
}

main().catch(console.error);
