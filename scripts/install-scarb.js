const { execSync } = require('node:child_process');
const fs = require('fs');

const asdfVersion = 'v0.14.1';
const scarbVersion = '2.11.0';
const foundryVersion = '0.38.2';

const asdfTargetDir = `${process.env.HOME}/.asdf`;

try {
  execSync(
    `git clone https://github.com/asdf-vm/asdf.git ${asdfTargetDir} --branch ${asdfVersion}`
  );
} catch {
  console.log('asdf already exists');
  return;
}

process.env.PATH = `${process.env.PATH}:${asdfTargetDir}/bin:${asdfTargetDir}/shims`;

// add asdf to bashrc
if (process.env.CI) {
  fs.appendFileSync(process.env.GITHUB_ENV, `PATH=${process.env.PATH}\n`);
} else {
  try {
    // check if the asdf.sh exists in .bashrc,
    // if grep finds the line, it means it exists
    execSync(`grep -Fq asdf.sh ~/.bashrc`);
  } catch (err) {
    // if grep fails, it means the text doesn't exist, so we append it
    execSync(`printf "\\n. ~/.asdf/asdf.sh" >> ~/.bashrc`);
    execSync(`printf "\\n. ~/.asdf/completions/asdf.bash" >> ~/.bashrc`);
  }
}

try {
  // install scarb
  console.log(`installing scarb -v ${scarbVersion}...`);
  execSync(`asdf plugin add scarb`);
  execSync(`asdf install scarb ${scarbVersion}`);
  execSync(`asdf global scarb ${scarbVersion}`);
  console.log(`installed scarb -v ${execSync(`scarb --version`).toString()}`);
} catch {
  console.log('could not install scarb');
}

try {
  // install Foundry
  console.log(`installing Foundry -v ${foundryVersion}`);
  execSync(`asdf plugin add starknet-foundry`);
  execSync(`asdf install starknet-foundry ${foundryVersion}`);
  execSync(`asdf global starknet-foundry ${foundryVersion}`);
  console.log(`installed Foundry -v ${execSync(`snforge --version`).toString()}`);
} catch {
  console.log('could not install Foundry');
}
