// Install Scarb (Linux and macOS only)
const { exec } = require('node:child_process');

exec("curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh -s -- -v 2.6.5", (error, stdout, stderr)  => {
    console.log(stdout);
    console.log('Finished installing scarb')
    exec('scarb --version', (error, stdout, stderr)  => {
        console.log(stdout);
        exec("curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh", (error, stdout, stderr)  => {
            console.log(stdout);
            exec("snfoundryup", (error, stdout) => {
                console.log(stdout);
                console.log('Finished installing Foundry');
                exec('snforge --version', (error, stdout, stderr) => {
                    console.log(stdout);
                })
            });
        });
    })
});
