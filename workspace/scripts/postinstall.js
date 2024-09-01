const { execSync } = require('node:child_process');
const fs = require('fs');

const tragetDir = process.env.HOME + "/.asdf";
const asdfVersion = 'v0.14.0';
const scarbVersion = '2.8.1';
const foundryVersion = '0.27.0';

// Install asdf
if (!fs.existsSync(tragetDir)) {
    execSync(`git clone https://github.com/asdf-vm/asdf.git ${tragetDir} --branch ${asdfVersion}`);
}
process.env['PATH'] = `${process.env['PATH']}:${process.env['HOME']}/.asdf/bin:${process.env['HOME']}/.asdf/shims`;
if (process.env.CI) {
    fs.appendFileSync(process.env.GITHUB_ENV, `PATH=${process.env['PATH']}\n`);
} else {
    execSync(`echo -e "\\n. ~/.asdf/asdf.sh" >> ~/.bashrc`);
    execSync(`echo -e "\\n. ~/.asdf/completions/asdf.bash" >> ~/.bashrc`);
}

// Install scarb
execSync(`asdf plugin add scarb`);
execSync(`asdf install scarb ${scarbVersion}`);
execSync(`asdf global scarb ${scarbVersion}`);
console.log(execSync(`scarb --version`).toString());
console.log('Finished installing scarb');

// Install Foundry
execSync(`asdf plugin add starknet-foundry`);
execSync(`asdf install starknet-foundry ${foundryVersion}`);
execSync(`asdf global starknet-foundry ${foundryVersion}`);
console.log(execSync(`snforge --version`).toString());
console.log('Finished installing Foundry');
