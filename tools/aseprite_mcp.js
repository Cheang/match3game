#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const ASEPRITE_PATH = process.env.ASEPRITE_PATH || 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Aseprite\\Aseprite.exe';

async function callMcpTool(toolName, args = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn('cmd.exe', ['/c', 'npx', '-y', 'aseprite-mcp'], {
      env: { ...process.env, ASEPRITE_PATH },
      cwd: process.cwd()
    });

    let buffer = '';
    let settled = false;

    child.stdout.on('data', chunk => {
      buffer += chunk.toString();
      const lines = buffer.split('\n');
      buffer = lines.pop();

      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const msg = JSON.parse(line.trim());
          if (msg.id === 1) {
            // Initialized; send tool call
            const toolCall = JSON.stringify({
              jsonrpc: '2.0',
              id: 2,
              method: 'tools/call',
              params: {
                name: toolName,
                arguments: args
              }
            }) + '\n';
            child.stdin.write(toolCall);
          } else if (msg.id === 2) {
            settled = true;
            child.kill();
            if (msg.error) {
              reject(new Error(msg.error.message || JSON.stringify(msg.error)));
            } else {
              resolve(msg.result);
            }
          }
        } catch (e) {
          // ignore parsing partial lines
        }
      }
    });

    child.stderr.on('data', chunk => {
      // debug stderr if needed
    });

    child.on('error', err => {
      if (!settled) {
        settled = true;
        reject(err);
      }
    });

    child.on('exit', code => {
      if (!settled) {
        settled = true;
        reject(new Error(`MCP server exited with code ${code}`));
      }
    });

    // Send initialize request
    const initReq = JSON.stringify({
      jsonrpc: '2.0',
      id: 1,
      method: 'initialize',
      params: {
        protocolVersion: '2024-11-05',
        capabilities: {},
        clientInfo: { name: 'cli-runner', version: '1.0' }
      }
    }) + '\n';
    child.stdin.write(initReq);
  });
}

// CLI handling
if (require.main === module) {
  const [,, cmd, toolName, ...rest] = process.argv;

  if (cmd === 'call' && toolName) {
    let args = {};
    if (rest.length > 0) {
      const raw = rest.join(' ');
      try {
        if (fs.existsSync(raw)) {
          args = JSON.parse(fs.readFileSync(raw, 'utf8'));
        } else {
          args = JSON.parse(raw);
        }
      } catch (e) {
        console.error('Failed to parse args JSON:', e.message);
        process.exit(1);
      }
    }

    callMcpTool(toolName, args)
      .then(res => {
        console.log(JSON.stringify(res, null, 2));
      })
      .catch(err => {
        console.error('Error calling tool:', err);
        process.exit(1);
      });
  } else {
    console.log('Usage: node tools/aseprite_mcp.js call <toolName> [jsonArgs|jsonFilePath]');
  }
}

module.exports = { callMcpTool };
