const fs = require('fs');
const path = require('path');

// Configuration
const OWNER = "CLMC2025";
const REPO = "Vignette";
const BRANCH = "main";
const BASE_PATH = "d:/DevEcoStudioProjects/Vignette";

// Read batch file
const batchFile = process.argv[2];
if (!batchFile) {
    console.error("Usage: node upload.js <batch_file>");
    process.exit(1);
}

const batchData = JSON.parse(fs.readFileSync(batchFile, 'utf8'));
console.log(`Loaded ${batchData.length} files from ${batchFile}`);

// Prepare files for API
const files = batchData.map(file => ({
    path: file.path,
    content: file.content
}));

// Output as JSON for MCP tool
const output = {
    owner: OWNER,
    repo: REPO,
    branch: BRANCH,
    message: `Upload batch: ${path.basename(batchFile)}`,
    files: files
};

console.log(JSON.stringify(output, null, 2));
