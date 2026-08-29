const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// Configuration
const SOURCE_R6_FOLDER = "./r6";
const OUTPUT_ZIP = "./r6.zip";

// Helper function to check if file should be excluded
function shouldExcludeFile(filePath) {
	const fileName = path.basename(filePath).toLowerCase();
	return fileName.includes("cursorrules") || fileName.includes(".cursorrules");
}

// Helper function to recursively get all files, excluding cursorrules
function getAllFiles(dirPath, basePath = "") {
	const files = [];
	const entries = fs.readdirSync(dirPath, { withFileTypes: true });

	for (const entry of entries) {
		const fullPath = path.join(dirPath, entry.name);
		const relativePath = path.join(basePath, entry.name);

		if (entry.isDirectory()) {
			files.push(...getAllFiles(fullPath, relativePath));
		} else if (!shouldExcludeFile(fullPath)) {
			files.push(relativePath);
		}
	}

	return files;
}

async function pack() {
	try {
		console.log("Starting pack process...");
		console.log(`Source folder: ${SOURCE_R6_FOLDER}`);
		console.log(`Output file: ${OUTPUT_ZIP}`);

		// Remove existing zip if it exists
		if (fs.existsSync(OUTPUT_ZIP)) {
			console.log("Removing existing zip file...");
			fs.unlinkSync(OUTPUT_ZIP);
		}

		// Get all files to include
		console.log("Scanning files...");
		const files = getAllFiles(SOURCE_R6_FOLDER, "r6");
		console.log(`Found ${files.length} files to pack`);

		// Create zip using 7zip. Pass the file list via @listfile instead of on the
		// command line since Windows has an ~8191-char command length limit.
		console.log("Creating zip archive...");
		const listFile = path.resolve(".", "r6-pack-filelist.txt");
		fs.writeFileSync(listFile, files.join("\n"), "utf8");
		try {
			const command = `7z a "${path.resolve(OUTPUT_ZIP)}" "@${listFile}"`;
			execSync(command, { cwd: ".", stdio: "inherit" });
		} finally {
			fs.unlinkSync(listFile);
		}

		console.log("\n✅ Pack completed successfully!");
		console.log(`Created: ${OUTPUT_ZIP}`);
	} catch (error) {
		console.error("\n❌ Pack failed:", error.message);
		process.exit(1);
	}
}

// Run pack
pack();
