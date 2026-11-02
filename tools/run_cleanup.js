const fs = require('fs');
const { callMcpTool } = require('./aseprite_mcp.js');

async function main() {
  const targetFile = process.argv[2] || 'assets/level_ui/test_clean.aseprite';
  const luaCode = fs.readFileSync('tools/clean_pixel_art.lua', 'utf8');

  console.log('Running cleanup on', targetFile, '...');
  const res = await callMcpTool('run_lua', {
    sprite: targetFile,
    code: luaCode,
    save: true
  });

  console.log('Result:', JSON.stringify(res, null, 2));
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
