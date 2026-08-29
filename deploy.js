const fs = require("fs");
const path = require("path");

// Configuration
const DEPLOYMENT_TARGET = "Z:\\GOG\\Cyberpunk 2077";
const SOURCE_R6_FOLDER = "./r6";

// Helper function to recursively delete directory
function deleteDirectory(dirPath) {
	if (fs.existsSync(dirPath)) {
		console.log(`Deleting: ${dirPath}`);
		fs.rmSync(dirPath, { recursive: true, force: true });
	} else {
		console.log(`Directory does not exist: ${dirPath}`);
	}
}

// Helper function to recursively copy directory
function copyDirectory(src, dest) {
	if (!fs.existsSync(dest)) {
		fs.mkdirSync(dest, { recursive: true });
	}

	const entries = fs.readdirSync(src, { withFileTypes: true });

	for (const entry of entries) {
		const srcPath = path.join(src, entry.name);
		const destPath = path.join(dest, entry.name);

		if (entry.isDirectory()) {
			copyDirectory(srcPath, destPath);
		} else {
			fs.copyFileSync(srcPath, destPath);
		}
	}
}

async function deploy() {
	try {
		console.log("Starting deployment...");
		console.log(`Deployment target: ${DEPLOYMENT_TARGET}`);
		console.log(`Source folder: ${SOURCE_R6_FOLDER}`);

		// Delete target directories
		const scriptsTarget = path.join(DEPLOYMENT_TARGET, "r6", "scripts", "AdaptiveTrafficHeadlights");

		console.log("\n--- Deleting existing files ---");
		deleteDirectory(scriptsTarget);

		// Copy r6 folder to deployment target
		console.log("\n--- Copying files ---");
		const targetR6Path = path.join(DEPLOYMENT_TARGET, "r6");

		// Copy the entire r6 folder
		console.log(`Copying ${SOURCE_R6_FOLDER} to ${targetR6Path}`);
		copyDirectory(SOURCE_R6_FOLDER, targetR6Path);

		console.log("\n✅ Deployment completed successfully!");
	} catch (error) {
		console.error("\n❌ Deployment failed:", error.message);
		process.exit(1);
	}
}

// Run deployment
deploy();
