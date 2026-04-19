const fs = require("fs");
const path = require("path");
const solc = require("solc");

const SRC_DIR = path.join(__dirname, "..", "..", "fixed");

function loadSources() {
  const sources = {};
  for (const f of fs.readdirSync(SRC_DIR)) {
    if (f.endsWith(".sol")) {
      sources[f] = { content: fs.readFileSync(path.join(SRC_DIR, f), "utf8") };
    }
  }
  return sources;
}

function findImports(importPath) {
  const p = path.join(SRC_DIR, importPath);
  if (fs.existsSync(p)) return { contents: fs.readFileSync(p, "utf8") };
  return { error: "File not found: " + importPath };
}

let cache;

function compile() {
  if (cache) return cache;

  const input = {
    language: "Solidity",
    sources: loadSources(),
    settings: {
      optimizer: { enabled: true, runs: 200 },
      evmVersion: "paris",
      outputSelection: { "*": { "*": ["abi", "evm.bytecode.object"] } }
    }
  };

  const output = JSON.parse(solc.compile(JSON.stringify(input), { import: findImports }));

  if (output.errors) {
    const fatal = output.errors.filter((e) => e.severity === "error");
    if (fatal.length) {
      throw new Error("solc errors:\n" + fatal.map((e) => e.formattedMessage).join("\n"));
    }
  }

  const out = {};
  for (const file of Object.keys(output.contracts)) {
    for (const name of Object.keys(output.contracts[file])) {
      out[name] = {
        abi: output.contracts[file][name].abi,
        bytecode: "0x" + output.contracts[file][name].evm.bytecode.object
      };
    }
  }

  cache = out;
  return out;
}

module.exports = { compile };
